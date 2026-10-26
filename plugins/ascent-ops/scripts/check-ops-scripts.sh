#!/usr/bin/env bash
# Zero-touch checks for operator scripts, make targets and pinned versions. Part of
# the ascent-ops plugin (ops-review Step 3, runbook-check Step 2). Read-only.
#
# Usage: check-ops-scripts.sh [--include-tests] PATH...
#
# PATH is a file or a directory. Directories are searched for shell scripts (*.sh,
# *.bash, and files with a sh or bash shebang), Makefiles and *.mk, Dockerfiles,
# Compose files, Terraform and GitHub Actions workflows. Skipped: node_modules,
# .git, .terraform, vendor, dist, build, virtualenvs, and test code (tests/, test/,
# fixtures/, test-*.sh, *_test.sh) unless --include-tests. A file named on the
# command line is always checked. A sourced library (under lib/, or named lib*.sh,
# *-lib.sh, _*.sh, common.sh) is checked for Z5 and Z6 only.
#
# Checks (severity from the ops-review severity table):
#   Z1  Medium  a script starts with a shebang
#   Z2  Medium  strict mode: set -euo pipefail (bash), set -eu (sh)
#   Z3  Low     the script answers --help (usage text), itself or through a shared
#               help function it hands "$@" to
#   Z4  Medium  a script that changes systems offers a dry run (--dry-run, DRY_RUN,
#               --check, --plan, --what-if, or preview unless --apply). Quoted text
#               is not a command, unless it goes to ssh, sh -c, eval or sudo
#   Z5  High    secrets never come from arguments (positional or --password, --token
#               options), are read with read -s, and are never printed to stdout
#   Z6  High    destructive commands (rm -rf, terraform destroy, delete-stack, aws s3 rm,
#               DROP TABLE, kubectl delete, prune, git reset --hard, ...) sit behind a
#               confirmation or an explicit flag (--yes, --force, --apply, CONFIRM, or
#               a read into confirm, answer, ok or yn); removing a mktemp directory is
#               exempt. A finding names the command, never the line
#   Z7  Low     every make target has "## help" text (make help lists it)
#   Z8  Medium  no floating versions: :latest, untagged or version-less (:alpine) images
#               (a Compose service with build: is exempt), @latest, actions on a
#               branch, curl | sh installs, providers, modules or required_version
#               without an upper bound
#   Z9  Low     a script that changes systems runs pre-flight and post-flight checks:
#               preflight/postflight names, or a gate, health, verify, check, require
#               or *_ok call before the last change and after the first
#
# Output: FAIL lines (FAIL  Zk  SEVERITY  file:line  message), a PASS line per check
# with no finding, N/A when a check found nothing to check, then
# "check-ops-scripts: ...". Secret values are never printed.
# Limits: static and line-based. Heredoc bodies and full-line comments are skipped.
# Binary files are never read as scripts.
# A command built at runtime, or run through a function or alias, is not seen.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail

usage() { sed -n '5p' "$0" | sed 's/^# //'; }
TESTS=0
PATHS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --include-tests) TESTS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "check-ops-scripts: unknown option $1" >&2; exit 2 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done
[ ${#PATHS[@]} -gt 0 ] || { usage >&2; exit 2; }

ARGS=()
add() { case "$2" in /*|./*) ARGS+=("K=$1" "$2") ;; *) ARGS+=("K=$1" "./$2") ;; esac; }
classify() {  # FILE EXPLICIT
  local f="$1" b lb first
  b=$(basename "$f"); lb=$(printf '%s' "$b" | tr 'A-Z' 'a-z')
  case "$lb" in
    *.sh|*.bash) add sh "$f"; return ;;
    makefile|gnumakefile|*.mk) add make "$f"; return ;;
    dockerfile|dockerfile.*|*.dockerfile|containerfile|containerfile.*) add docker "$f"; return ;;
    docker-compose*.yml|docker-compose*.yaml|compose*.yml|compose*.yaml|podman-compose*.yml|podman-compose*.yaml) add compose "$f"; return ;;
    *.tf) add tf "$f"; return ;;
    *.yml|*.yaml) case "$f" in */.github/workflows/*) add gha "$f"; return ;; esac ;;
  esac
  case "$lb" in *.*) ;; *)
    # A binary file (it contains a null byte) is never a script, whatever its first line.
    LC_ALL=C grep -Iq . "$f" 2>/dev/null || return 0
    first=$(head -n 1 "$f" 2>/dev/null | LC_ALL=C tr -d '\r' || true)
    case "$first" in '#!'*sh*) add sh "$f"; return ;; esac ;;
  esac
  if [ "$2" = 1 ]; then echo "check-ops-scripts: not a script, make, container, Terraform or workflow file: $f" >&2; exit 2; fi
}
for p in "${PATHS[@]}"; do
  if [ -d "$p" ]; then
    if [ "$TESTS" = 1 ]; then SKIP='( -name node_modules -o -name .git -o -name .terraform -o -name vendor -o -name dist -o -name build -o -name .venv -o -name venv )'
    else SKIP='( -name node_modules -o -name .git -o -name .terraform -o -name vendor -o -name dist -o -name build -o -name .venv -o -name venv -o -name tests -o -name test -o -name __tests__ -o -name fixtures -o -name spec )'; fi
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if [ "$TESTS" = 0 ]; then case "$(basename "$f")" in test-*.sh|*_test.sh|*.test.sh|*.bats) continue ;; esac; fi
      classify "$f" 0
    done <<EOF_FILES
$(# shellcheck disable=SC2086
  find "$p" $SKIP -prune -o -type f -print 2>/dev/null | LC_ALL=C sort || true)
EOF_FILES
  elif [ -f "$p" ]; then
    classify "$p" 1
  else
    echo "check-ops-scripts: no such file or directory: $p" >&2; exit 2
  fi
done
[ ${#ARGS[@]} -gt 0 ] || ARGS=("K=none" /dev/null)

PROG_FILE="$(cd "$(dirname "$0")" && pwd)/lib/check-ops-scripts.awk"
[ -f "$PROG_FILE" ] || { echo "check-ops-scripts: missing $PROG_FILE" >&2; exit 2; }

LC_ALL=C awk -f "$PROG_FILE" "${ARGS[@]}"
