#!/usr/bin/env bash
# Secure-by-design configuration checks for infrastructure as code:
# CloudFormation (YAML), Terraform/OpenTofu, Dockerfiles, Compose files and ECS
# task-definition JSON. Part of the ascent-ops plugin (ops-review Step 3,
# iac-config-check Step 2). Read-only.
#
# Usage: check-iac-config.sh [--manual FILE] PATH...
#
# PATH is a file or a directory (searched, skipping node_modules, .git, .terraform,
# vendor, dist, build and virtualenvs). --manual names the Maintenance and
# Operations Manual for S10. CI workflows, Makefiles and shell scripts found under
# PATH (outside tests/ and fixtures/) are read for drift detection (S9) only;
# comment lines do not count.
#
# Checks (severity from the ops-review severity table):
#   S1  High    no secret value written as a literal or a default (parameter Default,
#               variable default, attribute, tfvars, ENV/ARG, Compose environment)
#   S2  Medium  sensitive parameters are marked: NoEcho: true; sensitive = true on
#               variables and outputs
#   S3  High    secrets reach tasks and functions from Secrets Manager or SSM
#               SecureString, never as plain environment values; no secret in an SSM
#               String parameter. Medium for a Compose environment value (use
#               Compose secrets)
#   S4  High    Terraform state is remote, encrypted and locked; no state file in the
#               repository
#   S5  Medium  IAM policies grant no wildcard actions ("*", "service:*"); in a KMS key
#               policy, only the statement that names the account root is exempt
#   S6  Low     every Secrets Manager secret has a rotation schedule
#   S7  Medium  configuration is separated per environment (an environment parameter
#               or variable, per-environment tfvars or parameter files, workspaces, or
#               environment directories)
#   S8  High    no .env file is copied into an image; Medium for env_file in a
#               production Compose file
#   S9  Medium  drift is visible: a drift check runs (terraform plan
#               -detailed-exitcode, detect-stack-drift, driftctl), and no
#               lifecycle ignore_changes = all hides it
#   S10 Low     every parameter and variable is documented in the manual (--manual)
#
# Values are never printed: a finding names the key and its file:line only.
# Output: FAIL lines (FAIL  Sk  SEVERITY  file:line  message, or "absent" for a
# missing control), a PASS line per check with no finding, N/A when a check found
# nothing to check, NOTE lines (unrated) for IaC these checks do not cover, then
# "check-iac-config: ...".
# Limits: static and line-based. YAML must be block style; CloudFormation JSON, AWS
# CDK, Pulumi and Kubernetes manifests are detected and reported as not covered. A
# secret is recognised by its key name (password, secret, token, api key, private
# key, access key, credential, connection string); a name built at runtime is not
# seen. Statements are told apart by their Sid, Effect or statement block. This is a guard
# rail, not a replacement for cfn-lint, checkov or trivy.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail

usage() { sed -n '7p' "$0" | sed 's/^# //'; }
MANUAL=""
PATHS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --manual) [ $# -ge 2 ] || { usage >&2; exit 2; }; MANUAL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "check-iac-config: unknown option $1" >&2; exit 2 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done
[ ${#PATHS[@]} -gt 0 ] || { usage >&2; exit 2; }

PRUNE='( -name node_modules -o -name .git -o -name .terraform -o -name vendor -o -name dist -o -name build -o -name .venv -o -name venv -o -name __pycache__ -o -name .playwright-mcp )'
ALL=""
for p in "${PATHS[@]}"; do
  if [ -d "$p" ]; then
    # shellcheck disable=SC2086
    ALL="$ALL$(find "$p" $PRUNE -prune -o -type f -print 2>/dev/null | LC_ALL=C sort || true)
"
  elif [ -f "$p" ]; then
    ALL="$ALL$p
"
  else
    echo "check-iac-config: no such file or directory: $p" >&2; exit 2
  fi
done
if [ -n "$MANUAL" ] && [ -e "$MANUAL" ] && [ ! -f "$MANUAL" ]; then echo "check-iac-config: --manual is not a file: $MANUAL" >&2; exit 2; fi

# Classify. Each file goes to awk as "K=<kind> ./<path>" (the ./ stops awk from
# reading a path containing "=" as an assignment).
ARGS=()
STATES=""; ENVFILES=""; NOTES=""; NIAC=0
add() { case "$2" in /*|./*) ARGS+=("K=$1" "$2") ;; *) ARGS+=("K=$1" "./$2") ;; esac; }
# The path below the PATH argument it was found under, so a scanned tests/ is known.
rel() { local r; for r in "${PATHS[@]}"; do case "$1" in "${r%/}"/*) printf '/%s' "${1#"${r%/}"/}"; return ;; esac; done; printf '/%s' "$1"; }
while IFS= read -r f; do
  [ -n "$f" ] || continue
  b=$(basename "$f")
  lb=$(printf '%s' "$b" | tr 'A-Z' 'a-z')
  case "$lb" in
    *.tfstate|*.tfstate.backup) STATES="$STATES$f
" ;;
    *.tf) add tf "$f"; NIAC=$((NIAC + 1)) ;;
    *.tfvars)
      add tfvars "$f"
      case "$lb" in *dev*|*stag*|*prod*|*test*|*qa*|*uat*|*sandbox*) ENVFILES="$ENVFILES$f
" ;; esac ;;
    dockerfile|dockerfile.*|*.dockerfile|containerfile|containerfile.*) add docker "$f" ;;
    docker-compose*.yml|docker-compose*.yaml|compose*.yml|compose*.yaml|podman-compose*.yml|podman-compose*.yaml) add compose "$f" ;;
    cdk.json) NOTES="${NOTES}NOTE  --   -      $f:1  AWS CDK detected: not covered; check the synthesized template (cdk synth) instead
" ;;
    pulumi.yaml|pulumi.yml) NOTES="${NOTES}NOTE  --   -      $f:1  Pulumi detected: not covered; read the program and its stack configuration
" ;;
    samconfig.toml) ENVFILES="$ENVFILES$f
"; add ci "$f" ;;
    makefile|*.mk|*.sh|jenkinsfile|.gitlab-ci.yml|buildspec.yml|buildspec.yaml)
      # Drift evidence comes from what runs, not from test code.
      case "$(rel "$f")" in */tests/*|*/test/*|*/fixtures/*|*/spec/*) ;; *) add ci "$f" ;; esac ;;
    *.yml|*.yaml|*.template)
      case "$f" in */.github/workflows/*) add ci "$f"; continue ;; esac
      if grep -q '^Resources:' "$f" 2>/dev/null && grep -Eq '^AWSTemplateFormatVersion|Type:[ ]*["'"'"']?AWS::' "$f" 2>/dev/null; then
        add cfn "$f"; NIAC=$((NIAC + 1))
      elif grep -Eq '^apiVersion:' "$f" 2>/dev/null && grep -Eq '^kind:[ ]*(Deployment|StatefulSet|DaemonSet|Service|Ingress|CronJob|Pod)' "$f" 2>/dev/null; then
        NOTES="${NOTES}NOTE  --   -      $f:1  Kubernetes manifest detected: not covered by these checks
"
      fi ;;
    *.json)
      case "$lb" in *param*|*parameters*) ENVFILES="$ENVFILES$f
" ;; esac
      if grep -q '"AWSTemplateFormatVersion"' "$f" 2>/dev/null; then
        NOTES="${NOTES}NOTE  --   -      $f:1  CloudFormation JSON detected: not covered; convert with cfn-flip and check the YAML
"
      elif grep -q '"containerDefinitions"' "$f" 2>/dev/null; then
        add taskjson "$f"
      fi ;;
  esac
  case "$f" in */environments/*|*/envs/*|*/env/*|*/stages/*|*/live/*)
    case "$lb" in *.tf) ENVFILES="$ENVFILES$f
" ;; esac ;;
  esac
done <<EOF_FILES
$(printf '%s' "$ALL" | grep -v '^$' || true)
EOF_FILES

MANUAL_TEXT=""
if [ -n "$MANUAL" ] && [ -f "$MANUAL" ]; then MANUAL_TEXT="$MANUAL"; fi
[ ${#ARGS[@]} -gt 0 ] || ARGS=("K=none" /dev/null)

PROG_FILE="$(cd "$(dirname "$0")" && pwd)/lib/check-iac-config.awk"
[ -f "$PROG_FILE" ] || { echo "check-iac-config: missing $PROG_FILE" >&2; exit 2; }

CIC_STATES="$STATES" CIC_ENVFILES="$ENVFILES" CIC_NOTES="$NOTES" CIC_MANUAL="$MANUAL" CIC_MTEXT="$MANUAL_TEXT" \
  LC_ALL=C awk -f "$PROG_FILE" "${ARGS[@]}"
