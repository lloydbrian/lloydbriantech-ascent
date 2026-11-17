#!/usr/bin/env bash
# Rates the results of the live security checks and the scanner reports the operator
# recorded. Part of the ascent-security plugin (security-test Step 4). Read-only; it
# sends no request.
#
# Usage: check-live-results.sh --target NAME --url URL [--today YYYY-MM-DD] [--max-age DAYS] [--maturity LEVEL] [--threshold SEV] [--endpoint 'METHODS PATH AUTH FLAGS']... [--waived ID,...] [--zap FILE] [--nuclei FILE] [--dalfox FILE] RESULTS
#
# RESULTS is a results file run-live-checks.sh wrote, or the results directory
# (security.live.results_dir), where the newest YYYY-MM-DD-<target>.tsv is read.
# Values come from the contract (references/live-rules.md): --target and --url from
# security.live.targets, --endpoint from security.endpoints, --max-age from
# security.live.max_age_days (default 30), --maturity from security.maturity_target
# (default enterprise), --threshold from security.live.scan_threshold (Critical,
# High, Medium or Low; default High), --waived from every id of every waiver.
# --zap is ZAP's JSON report (-J), --nuclei nuclei's JSONL (-jsonl), --dalfox
# dalfox's JSONL (v3, -f jsonl). --today fixes the date for tests.
#
# Checks (severity from the live-severity table in security-test):
#   SEC-L1   Medium  CSP, nosniff, frame protection, HSTS on https; Low for
#                    Referrer-Policy and Permissions-Policy
#   SEC-L2   Medium  a TRACE that echoes the request; Low for TRACE or CONNECT 2xx
#   SEC-L3   High    a traversal payload returned a system file
#   SEC-L4   High    a write endpoint that requires sign-in answered 2xx without it
#   SEC-L5   Medium  an oversized body got 2xx, 5xx or no answer
#   SEC-L6   High    a secret, git or env file served; Medium for a stack trace;
#                    Low for a version banner
#   SEC-L7   High    an AI endpoint obeyed the canary
#   SEC-L8   Medium  an AI burst was neither gated nor rate-limited, or got a 5xx
#   SEC-L9   High    a scanner finding rated Critical or High; Medium and Low as
#                    rated; below --threshold a NOTE
#   SEC-L10  Low     no results for the target, older than --max-age, for another
#                    URL or target, or a probe the endpoints need was skipped (the
#                    oversized body for any write endpoint, with or without sign-in)
# A finding whose id (SEC-Lk:path, SEC-L1:<header>, a ZAP pluginid or a nuclei
# template-id, dalfox:<param>) is in --waived is INFO. At prototype maturity every finding is a NOTE.
#
# Output: FAIL lines (FAIL  SEC-Lk  SEVERITY  file:line  message), a PASS line per
# check with no finding, N/A when it found nothing to check, NOTE and INFO lines,
# then "check-live-results: ...". Limits: the results show what the target answered
# when the operator ran the checks, not that the target is unchanged since.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail

usage() { sed -n '6p' "$0" | sed 's/^# //'; }
TARGET=""; URL=""; TODAY=""; MAXAGE=30; MATURITY=enterprise; THRESHOLD=High; WAIVED=""; ZAP=""; NUCLEI=""; DALFOX=""
EPS=(); POS=()
need() { [ "$1" -ge 2 ] || { usage >&2; exit 2; }; }
while [ $# -gt 0 ]; do
  case "$1" in
    --target) need $#; TARGET="$2"; shift 2 ;;
    --url) need $#; URL="$2"; shift 2 ;;
    --today) need $#; TODAY="$2"; shift 2 ;;
    --max-age) need $#; MAXAGE="$2"; shift 2 ;;
    --maturity) need $#; MATURITY="$2"; shift 2 ;;
    --threshold) need $#; THRESHOLD="$2"; shift 2 ;;
    --endpoint) need $#; EPS+=("$2"); shift 2 ;;
    --waived) need $#; WAIVED="$WAIVED,$2"; shift 2 ;;
    --zap) need $#; ZAP="$2"; shift 2 ;;
    --nuclei) need $#; NUCLEI="$2"; shift 2 ;;
    --dalfox) need $#; DALFOX="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "check-live-results: unknown option $1" >&2; exit 2 ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ ${#POS[@]} -eq 1 ] || { usage >&2; exit 2; }
bad() { echo "check-live-results: $1" >&2; exit 2; }
[ -n "$TARGET" ] && [ -n "$URL" ] || { usage >&2; exit 2; }
case "$TARGET" in *[!A-Za-z0-9._-]*) bad "--target must be letters, digits, '.', '_' or '-', got '$TARGET'" ;; esac
[ -z "$TODAY" ] && TODAY=$(date +%Y-%m-%d)
case "$TODAY" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) bad "--today must be YYYY-MM-DD" ;; esac
case "$MAXAGE" in ''|*[!0-9]*) bad "--max-age must be a number of days" ;; esac
case "$MATURITY" in enterprise|standard|prototype) ;; *) bad "--maturity must be enterprise, standard or prototype" ;; esac
case "$THRESHOLD" in Critical|High|Medium|Low) ;; *) bad "--threshold must be Critical, High, Medium or Low" ;; esac
for f in "$ZAP" "$NUCLEI" "$DALFOX"; do [ -z "$f" ] || [ -f "$f" ] || bad "no such report: $f"; done

HASW=0; HASANYW=0; HASAI=0; NEP=0
for e in ${EPS[@]+"${EPS[@]}"}; do
  set -f; set -- $e; set +f
  [ $# -eq 4 ] || bad "--endpoint must be 'METHODS PATH AUTH FLAGS', got '$e'"
  case "$3" in required|none) ;; *) bad "--endpoint auth must be required or none, got '$3'" ;; esac
  NEP=$((NEP + 1))
  case ",$4," in *,write,*) HASANYW=1; [ "$3" = required ] && HASW=1 ;; esac
  case ",$4," in *,ai,*) HASAI=1 ;; esac
done

# The results file: the one given, or the newest for the target in the directory.
R="${POS[0]}"; RES=""
nodash() { case "$1" in -*) printf './%s' "$1" ;; *) printf '%s' "$1" ;; esac; }
if [ -d "$R" ]; then
  RES=$(find -H "$(nodash "$R")" -type f -name "[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-$TARGET.tsv" 2>/dev/null | LC_ALL=C sort | tail -n 1 || true)
elif [ -f "$R" ]; then RES="$R"
elif [ -e "$R" ]; then bad "not a file or directory: $R"
fi

dot() { case "$1" in /*|./*) printf '%s' "$1" ;; *) printf './%s' "$1" ;; esac; }
ARGS=()
[ -n "$RES" ] && ARGS+=("K=results" "$(dot "$RES")")
[ -n "$ZAP" ] && ARGS+=("K=zap" "$(dot "$ZAP")")
[ -n "$NUCLEI" ] && ARGS+=("K=nuclei" "$(dot "$NUCLEI")")
[ -n "$DALFOX" ] && ARGS+=("K=dalfox" "$(dot "$DALFOX")")
NREPORTS=0; for f in "$ZAP" "$NUCLEI" "$DALFOX"; do [ -z "$f" ] || NREPORTS=$((NREPORTS + 1)); done
[ ${#ARGS[@]} -gt 0 ] || ARGS=("K=none" /dev/null)

LIB="$(cd "$(dirname "$0")" && pwd)/lib"
for l in json.awk check-live-results.awk; do [ -f "$LIB/$l" ] || bad "missing $LIB/$l"; done
CLR_TARGET="$TARGET" CLR_URL="${URL%/}" CLR_TODAY="$TODAY" CLR_MAXAGE="$MAXAGE" CLR_MATURITY="$MATURITY" CLR_THRESHOLD="$THRESHOLD" \
CLR_NREPORTS="$NREPORTS" CLR_WAIVED="$WAIVED," CLR_HASW="$HASW" CLR_HASANYW="$HASANYW" CLR_HASAI="$HASAI" CLR_NEP="$NEP" CLR_DIR="$R" \
  LC_ALL=C awk -f "$LIB/json.awk" -f "$LIB/check-live-results.awk" "${ARGS[@]}"
