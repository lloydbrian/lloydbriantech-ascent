#!/usr/bin/env bash
# Holds one AI application's running safeguards to what it declares: tracing of
# model calls, what the traces keep, a gateway with a policy, and a cost alert.
# Part of the ascent-ai plugin (ai-runtime-check Step 1, ai-review Step 2), and
# made to run in a project's own CI at no token cost; ascent-governance's
# check-audit.sh runs it once for each application. Read-only: it reads files
# and never runs a model or a network call. Provider keys and pinned gateway
# packages are ascent-security's, never checked here.
#
# Usage: check-ai-runtime.sh --app NAME --root DIR --design FILE [--capture-policy FILE] [--gateway-policy FILE] [--tier-record FILE] [--app-root NAME=ROOT]... [--threshold SEV] [REPO]
#
# REPO is the repository root (default "."); every path is relative to it.
# --app is the application's name and --root the folder of its code. --design is
# its AI design record (references/design-record-template.md), which names the
# gateway (litellm, portkey or none) and the cost-per-task alert.
# --capture-policy says what the traces keep (references/evidence-formats.md);
# --gateway-policy is the gateway's configuration. --tier-record is the AI
# risk-tier record (ascent-governance), which scales every severity: the
# severities below are for tier 3, one level lighter at tier 2, two at tier 1,
# never below Low. Each --app-root is another application of the repository:
# code under a root deeper than --root that belongs to another application is not
# this one's.
#
# Checks (references/ai-rules.md):
#   AI-O1  High     tracing for model calls is in the dependencies under the root
#                   (OpenTelemetry GenAI instrumentation, OpenInference, Langfuse,
#                   Phoenix, Traceloop)
#   AI-O2  High     the capture policy exists and says what is stored, what is
#                   redacted and what is dropped
#   AI-C1  Medium   with a gateway declared, every model client in the code goes
#                   through it (a base URL); gateway none is a finding at tier 3
#   AI-C2  High     the gateway policy names the allowed models, a budget, an
#                   alert threshold and rate limits
#   AI-C3  Medium   a cost-per-task alert is declared
#
# Output: FAIL lines (FAIL  AI-Xn  SEVERITY  [app] file[:line]  message), a PASS
# line per rule that passes, N/A lines, then "check-ai-runtime: [app] N finding(s)".
# Exit: 0 when no finding is at or above --threshold (default High); 1 when one
# is; 2 bad input, with "check-ai-runtime: <option>: <reason>" first (ADR-030).
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail
export LC_ALL=C

usage() { sed -n '10p' "$0" | sed 's/^# //'; }
bad() { echo "check-ai-runtime: $1" >&2; usage >&2; exit 2; }
APP=""; ROOT=""; DESIGN=""; TIER=""; CAPTURE=""; GWPOLICY=""
THRESHOLD=High; ROOTS=(); POS=()
need() { [ "$1" -ge 2 ] || bad "$2: needs a value"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --app) need $# "$1"; APP="$2"; shift 2 ;;
    --root) need $# "$1"; ROOT="$2"; shift 2 ;;
    --design) need $# "$1"; DESIGN="$2"; shift 2 ;;
    --tier-record) need $# "$1"; TIER="$2"; shift 2 ;;
    --capture-policy) need $# "$1"; CAPTURE="$2"; shift 2 ;;
    --gateway-policy) need $# "$1"; GWPOLICY="$2"; shift 2 ;;
    --app-root) need $# "$1"; ROOTS+=("$2"); shift 2 ;;
    --threshold) need $# "$1"; THRESHOLD="$2"; shift 2 ;;
    -h|--help) usage; awk 'NR > 10 && /^#/ { sub(/^# ?/, ""); print; next } NR > 10 { exit }' "$0"; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do POS+=("$1"); shift; done ;;
    -*) bad "$1: unknown option" ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ -n "$APP" ] || bad "--app: required"
printf '%s\n' "$APP" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_-]*$' || bad "--app: the name '$APP' is not letters, digits, - and _"
[ -n "$ROOT" ] || bad "--root: required"
[ -n "$DESIGN" ] || bad "--design: required"
case "$THRESHOLD" in Critical|High|Medium|Low) ;; *) bad "--threshold: expected Critical, High, Medium or Low, got $THRESHOLD" ;; esac
[ "${#POS[@]}" -le 1 ] || bad "${POS[1]}: one REPO only"
REPO="${POS[0]:-.}"
[ -d "$REPO" ] || bad "$REPO: not a directory"
HERE="$(cd "$(dirname "$0")" && pwd)"; LIB="$HERE/lib"
for f in common.awk record.awk runtime.awk; do [ -f "$LIB/$f" ] || bad "$LIB/$f: missing"; done
cd "$REPO"
norm() { local r="$1"; while case "$r" in ./*) true ;; *) false ;; esac; do r="${r#./}"; done; while [ "${r%/}" != "$r" ]; do r="${r%/}"; done; printf '%s' "${r:-.}"; }
inside() { case "/$1/" in */../*) return 1 ;; esac; case "$1" in /*) return 1 ;; esac; return 0; }
ROOT=$(norm "$ROOT"); inside "$ROOT" || bad "--root: $ROOT is not inside the repository"
[ -d "$ROOT" ] || bad "--root: $ROOT is not a directory"
OTHERS=""
for a in ${ROOTS[@]+"${ROOTS[@]}"}; do
  case "$a" in *=?*) ;; *) bad "--app-root: expected NAME=ROOT, got $a" ;; esac
  OTHERS="$OTHERS${a%%=*}=$(norm "${a#*=}");"
done

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT INT TERM
# test data is not the application (detect-ai skips it the same way)
PRUNE=( \( -name node_modules -o -name .venv -o -name venv -o -name .git -o -name dist -o -name build -o -name fixtures -o -name testdata -o -name __fixtures__ \) -prune )
# the code of the application: source files under its root, outside tests and docs
find "$ROOT" "${PRUNE[@]}" -o -type f \( -name '*.py' -o -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' -o -name '*.cjs' \) -print \
  | sed 's|^\./||' | awk '{ p = "/" $0 "/"; b = $0; sub(/^.*\//, "", b)
      if (p ~ /\/(tests?|__tests__|docs|spec)\//) next
      if (b ~ /^test_.*\.py$/ || b ~ /_test\.py$/ || b ~ /\.(test|spec)\.[a-z]+$/) next
      print }' | sort > "$T/code"
# the dependency manifests under the root
find "$ROOT" "${PRUNE[@]}" -o -type f \( -name pyproject.toml -o -name 'requirements*.txt' -o -name package.json \) -print | sed 's|^\./||' | sort > "$T/manifests"
# and the ones directly in each folder above it, up to the repository's: in a src layout the
# application's dependencies are declared at the top (a sibling folder's are not its)
: > "$T/upmanifests"; d="$ROOT"
while [ "$d" != "." ]; do
  case "$d" in */*) d="${d%/*}" ;; *) d=. ;; esac
  for f in "$d"/pyproject.toml "$d"/requirements*.txt "$d"/package.json; do if [ -f "$f" ]; then printf '%s\n' "${f#./}" >> "$T/upmanifests"; fi; done
done

awk -v app="$APP" -v root="$ROOT" -v others="$OTHERS" -v design="$DESIGN" -v tierfile="$TIER" \
  -v capture="$CAPTURE" -v gwpolicy="$GWPOLICY" -v threshold="$THRESHOLD" -v manifests="$T/manifests" -v upmanifests="$T/upmanifests" \
  -f "$LIB/common.awk" -f "$LIB/record.awk" -f "$LIB/runtime.awk" "$T/code"
