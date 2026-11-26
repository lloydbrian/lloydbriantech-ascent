#!/usr/bin/env bash
# Checks the project's threat model against its endpoints and its repository. Part
# of the ascent-security plugin (threat-model Step 4, security-test Step 1).
# Read-only.
#
# Usage: check-threat-model.sh [--repo DIR] [--adr-dir DIR] [--today YYYY-MM-DD] [--max-age DAYS] [--maturity LEVEL] [--endpoint 'METHODS PATH AUTH FLAGS']... [--ai] MODEL
#
# MODEL is the threat model (security.threat_model.path, default
# docs/security/THREAT-MODEL.md; references/live-rules.md has its format). --repo is
# the root that mitigation paths are relative to (default "."), --adr-dir where
# accepted threats' ADRs live (security.adr_dir, default docs/adr), --max-age the
# days a review stays current (security.threat_model.review_max_age_days, default
# 180), --endpoint each of security.endpoints, --maturity security.maturity_target.
# --ai says the repository has an AI application (ai.applications, or AI code
# ascent-ai finds); only then is SEC-T5 checked.
#
# Checks (severity from the live-severity table in security-test):
#   SEC-T1  Medium  the model exists, with its field table (method STRIDE), an
#                   Entry points table and a Threats table
#   SEC-T2  Medium  every endpoint is an entry point, and every entry point has a
#                   threat
#   SEC-T3  Medium  no threat is open; Low for a mitigated threat whose mitigation
#                   names no file that exists, an accepted threat whose ADR is
#                   missing, or a row with an unknown STRIDE letter or status
#   SEC-T4  Low     reviewed_on is a date within --max-age days, and reviewed_by
#                   names a person
#   SEC-T5  High    with --ai: an entry point for a model input (its trust
#                   boundary names a model, or it is written "model input: ..."),
#                   and a threat, mitigated or accepted, for each of prompt
#                   injection, sensitive information disclosure, excessive agency
#                   and unbounded consumption (named in the Threat cell)
# At prototype maturity every finding is a NOTE. A NOTE lists the STRIDE categories
# no threat covers.
#
# Output: FAIL lines (FAIL  SEC-Tk  SEVERITY  file:line  message), a PASS line per
# check with no finding, N/A, NOTE lines, then "check-threat-model: ...". Limits: it
# checks that threats are recorded and answered, not that the answers are right.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail

usage() { sed -n '6p' "$0" | sed 's/^# //'; }
REPO="."; ADR=docs/adr; TODAY=""; MAXAGE=180; MATURITY=enterprise; AI=0; EPS=(); POS=()
need() { [ "$1" -ge 2 ] || { usage >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) need $#; REPO="$2"; shift 2 ;;
    --adr-dir) need $#; ADR="$2"; shift 2 ;;
    --today) need $#; TODAY="$2"; shift 2 ;;
    --max-age) need $#; MAXAGE="$2"; shift 2 ;;
    --maturity) need $#; MATURITY="$2"; shift 2 ;;
    --endpoint) need $#; EPS+=("$2"); shift 2 ;;
    --ai) AI=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "check-threat-model: unknown option $1" >&2; exit 2 ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ ${#POS[@]} -eq 1 ] || { usage >&2; exit 2; }
bad() { echo "check-threat-model: $1" >&2; exit 2; }
MODEL="${POS[0]}"
[ -z "$TODAY" ] && TODAY=$(date +%Y-%m-%d)
case "$TODAY" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) bad "--today must be YYYY-MM-DD" ;; esac
case "$MAXAGE" in ''|*[!0-9]*) bad "--max-age must be a number of days" ;; esac
case "$MATURITY" in enterprise|standard|prototype) ;; *) bad "--maturity must be enterprise, standard or prototype" ;; esac
[ -d "$REPO" ] || bad "--repo is not a directory: $REPO"
[ ! -e "$MODEL" ] || [ -f "$MODEL" ] || bad "not a file: $MODEL"

TAB=$(printf '\t')
EPL=""
for e in ${EPS[@]+"${EPS[@]}"}; do
  set -f; set -- $e; set +f
  [ $# -eq 4 ] || bad "--endpoint must be 'METHODS PATH AUTH FLAGS', got '$e'"
  case "$2" in /*) ;; *) bad "--endpoint path must start with /, got '$2'" ;; esac
  EPL="$EPL$1 $2
"
done

# Files the model names: mitigations (backticked paths) and the ADRs, resolved here.
FOUND=""
if [ -f "$MODEL" ]; then
  for p in $(grep -o '`[^` ]*`' "$MODEL" 2>/dev/null | tr -d '`' | LC_ALL=C sort -u); do
    case "$p" in */*|*.*) ;; *) continue ;; esac
    case "$p" in /*|*..*) continue ;; esac
    [ -e "${REPO%/}/$p" ] && FOUND="$FOUND$p
"
  done
fi
ADRS=""
case "$ADR" in /*) AD="$ADR" ;; *) AD="${REPO%/}/$ADR" ;; esac
if [ -d "$AD" ]; then ADRS=$(cd "$AD" && ls 2>/dev/null | grep -Eo '^ADR-[0-9]+' | sed 's/^ADR-0*/ADR-/' | LC_ALL=C sort -u || true); fi

dot() { case "$1" in /*|./*) printf '%s' "$1" ;; *) printf './%s' "$1" ;; esac; }
if [ -f "$MODEL" ]; then IN=$(dot "$MODEL"); else IN=/dev/null; fi
PROG="$(cd "$(dirname "$0")" && pwd)/lib/check-threat-model.awk"
[ -f "$PROG" ] || bad "missing $PROG"
CTM_TODAY="$TODAY" CTM_MAXAGE="$MAXAGE" CTM_MATURITY="$MATURITY" CTM_EPS="$EPL" CTM_FOUND="$FOUND" CTM_ADRS="$ADRS" CTM_MODEL="$MODEL" CTM_ADR="$ADR" CTM_AI="$AI" \
  LC_ALL=C awk -f "$PROG" "$IN"
