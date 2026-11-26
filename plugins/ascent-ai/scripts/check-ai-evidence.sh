#!/usr/bin/env bash
# Holds one AI application's result files to its targets: the golden set, the
# eval results, the retrieval results and sources, and the review. Part of the
# ascent-ai plugin (ai-evidence-check Step 1, ai-review Step 2), and made to run
# in a project's own CI at no token cost; ascent-governance's check-audit.sh runs
# it once for each application. Read-only: it reads files and git dates, and
# never runs a model, an eval or a network call. Evals run from a runbook the
# operator runs, which writes the result files this reads.
#
# Usage: check-ai-evidence.sh --app NAME --golden DIR [--results FILE] [--format promptfoo|ascent-evidence-v1] [--pass-rate N] [--attack-pass-rate N] [--max-age DAYS] [--prompts DIR] [--retrieval FILE] [--retrieval-target NAME=VALUE]... [--sources FILE] [--review-by DATE] [--review-notes FILE] [--tier-record FILE] [--threshold SEV] [--today YYYY-MM-DD] [--no-git] [REPO]
#
# REPO is the repository root (default "."); every path is relative to it.
# --golden is the golden set: Promptfoo test files whose cases carry
# metadata.slice, and a VERSION file. --results is the eval result file, in
# --format promptfoo (what promptfoo eval -o writes; the default) or
# ascent-evidence-v1 (self-reported; references/evidence-formats.md).
# --pass-rate is the share of rows that must pass (default 0.90), errors
# counting as failures; --attack-pass-rate the attack slice's own (default 1.0);
# --max-age the most days old the results may be (default 14). --prompts is the
# prompts folder: the results must be newer than the last commit to it or to the
# golden set (git dates; --no-git skips this). --retrieval is the retrieval result
# file (ascent-evidence-v1), held to each --retrieval-target; --sources the table
# of retrieval sources; --review-by the date a person looks at the evidence
# again; --review-notes the table of past reviews. --tier-record is the AI risk-tier
# record (ascent-governance), which scales every severity: the severities below
# are for tier 3, one level lighter at tier 2, two at tier 1, never below Low,
# except the rules marked fixed; with no record, tier 3.
#
# Checks (references/ai-rules.md):
#   AI-G1  High     the golden set has the four slices (typical, edge, attack,
#                   regression), each with a case, and a VERSION
#   AI-E1  High     the eval result file is given and exists
#   AI-E2  High     the results are no older than --max-age days, and newer than
#                   the last commit to a prompt or the golden set
#   AI-E3  High     the pass rate meets --pass-rate (errors count as failures);
#                   the attack slice meets --attack-pass-rate (Critical, fixed)
#   AI-E4  Medium   the results' golden-set version is the golden set's VERSION
#   AI-E5  Low      a self-reported (ascent-evidence-v1) result is reported as
#                   self-reported, on every run (fixed)
#   AI-R1  High     the retrieval results exist, are no older than --max-age
#                   days, and meet every --retrieval-target
#   AI-R2  Medium   every retrieval source has an owner and a review date that
#                   is not past
#   AI-L1  Medium   --review-by is not past
#   AI-L2  Low      since the last review, the regression slice grew, or that
#                   review flagged no new failures
#
# Output: FAIL lines (FAIL  AI-Xn  SEVERITY  [app] file[:line]  message), a PASS
# line per rule that passes, N/A lines, then "check-ai-evidence: [app] N finding(s)".
# Exit: 0 when no finding is at or above --threshold (default High); 1 when one
# is; 2 bad input, with "check-ai-evidence: <option>: <reason>" first (ADR-030),
# including a result file that is not in its format.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail
export LC_ALL=C

usage() { sed -n '10p' "$0" | sed 's/^# //'; }
bad() { echo "check-ai-evidence: $1" >&2; usage >&2; exit 2; }
APP=""; GOLDEN=""; RESULTS=""; FORMAT=promptfoo; RATE=0.90; ARATE=1.0; MAXAGE=14; PROMPTS=""; RETR=""; TARGETS=""
SOURCES=""; REVIEWBY=""; NOTES=""; TIER=""; THRESHOLD=High; TODAY=""; NOGIT=0; POS=()
need() { [ "$1" -ge 2 ] || bad "$2: needs a value"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --app) need $# "$1"; APP="$2"; shift 2 ;;
    --golden) need $# "$1"; GOLDEN="$2"; shift 2 ;;
    --results) need $# "$1"; RESULTS="$2"; shift 2 ;;
    --format) need $# "$1"; FORMAT="$2"; shift 2 ;;
    --pass-rate) need $# "$1"; RATE="$2"; shift 2 ;;
    --attack-pass-rate) need $# "$1"; ARATE="$2"; shift 2 ;;
    --max-age) need $# "$1"; MAXAGE="$2"; shift 2 ;;
    --prompts) need $# "$1"; PROMPTS="$2"; shift 2 ;;
    --retrieval) need $# "$1"; RETR="$2"; shift 2 ;;
    --retrieval-target) need $# "$1"
      case "$2" in [A-Za-z_]*=?*) ;; *) bad "--retrieval-target: expected NAME=VALUE, got $2" ;; esac
      printf '%s\n' "${2#*=}" | grep -Eq '^(0(\.[0-9]+)?|1(\.0+)?|\.[0-9]+)$' || bad "--retrieval-target: expected a number from 0 to 1 after =, got ${2#*=}"
      TARGETS="$TARGETS$2 "; shift 2 ;;
    --sources) need $# "$1"; SOURCES="$2"; shift 2 ;;
    --review-by) need $# "$1"; REVIEWBY="$2"; shift 2 ;;
    --review-notes) need $# "$1"; NOTES="$2"; shift 2 ;;
    --tier-record) need $# "$1"; TIER="$2"; shift 2 ;;
    --threshold) need $# "$1"; THRESHOLD="$2"; shift 2 ;;
    --today) need $# "$1"; TODAY="$2"; shift 2 ;;
    --no-git) NOGIT=1; shift ;;
    -h|--help) usage; awk 'NR > 10 && /^#/ { sub(/^# ?/, ""); print; next } NR > 10 { exit }' "$0"; exit 0 ;;
    --) shift; while [ $# -gt 0 ]; do POS+=("$1"); shift; done ;;
    -*) bad "$1: unknown option" ;;
    *) POS+=("$1"); shift ;;
  esac
done
[ -n "$APP" ] || bad "--app: required"
printf '%s\n' "$APP" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_-]*$' || bad "--app: the name '$APP' is not letters, digits, - and _"
[ -n "$GOLDEN" ] || bad "--golden: required"
case "$FORMAT" in promptfoo|ascent-evidence-v1) ;; *) bad "--format: expected promptfoo or ascent-evidence-v1, got $FORMAT" ;; esac
rate_ok() { printf '%s\n' "$1" | grep -Eq '^(0(\.[0-9]+)?|1(\.0+)?|\.[0-9]+)$'; }
rate_ok "$RATE" || bad "--pass-rate: expected a number from 0 to 1, got $RATE"
rate_ok "$ARATE" || bad "--attack-pass-rate: expected a number from 0 to 1, got $ARATE"
printf '%s\n' "$MAXAGE" | grep -Eq '^[1-9][0-9]*$' || bad "--max-age: expected a whole number of days, got $MAXAGE"
case "$THRESHOLD" in Critical|High|Medium|Low) ;; *) bad "--threshold: expected Critical, High, Medium or Low, got $THRESHOLD" ;; esac
realdate() { printf '%s\n' "$1" | awk '{ if ($0 !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) exit 1
  y = substr($0, 1, 4) + 0; m = substr($0, 6, 2) + 0; d = substr($0, 9, 2) + 0
  n = (m == 2) ? ((y % 4 == 0 && y % 100 != 0) || y % 400 == 0 ? 29 : 28) : ((m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31)
  exit !(m >= 1 && m <= 12 && d >= 1 && d <= n) }'; }
[ -z "$REVIEWBY" ] || realdate "$REVIEWBY" || bad "--review-by: $REVIEWBY is not a real date (YYYY-MM-DD)"
[ "${#POS[@]}" -le 1 ] || bad "${POS[1]}: one REPO only"
REPO="${POS[0]:-.}"
[ -d "$REPO" ] || bad "$REPO: not a directory"
HERE="$(cd "$(dirname "$0")" && pwd)"; LIB="$HERE/lib"
for f in common.awk json.awk evidence.awk; do [ -f "$LIB/$f" ] || bad "$LIB/$f: missing"; done
cd "$REPO"
[ -n "$TODAY" ] || TODAY=$(date +%Y-%m-%d)
realdate "$TODAY" || bad "--today: $TODAY is not a real date (YYYY-MM-DD)"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT INT TERM
# a result file flattened to path<TAB>value rows, or exit 2 when it is not in its format
flatten() {  # OPTION FILE FORMAT OUT
  awk -v RS='"' -f "$LIB/json.awk" "$2" > "$4" 2>/dev/null || bad "$1: $2 is not a $3 file"
  case "$3" in
    promptfoo) awk -F '\t' '$1 == "results.version" { v = 1 } $1 == "results.stats.successes" { s = 1 } END { exit !(v && s) }' "$4" ;;
    ascent-evidence-v1) awk -F '\t' '$1 == "format" && $2 == "ascent-evidence-v1" { f = 1 } END { exit !f }' "$4" ;;
  esac || bad "$1: $2 is not a $3 file"
}
: > "$T/res"; : > "$T/ret"; HAVERES=0; HAVERET=0
if [ -n "$RESULTS" ] && [ -f "$RESULTS" ]; then flatten --results "$RESULTS" "$FORMAT" "$T/res"; HAVERES=1; fi
if [ -n "$RETR" ] && [ -f "$RETR" ]; then flatten --retrieval "$RETR" ascent-evidence-v1 "$T/ret"; HAVERET=1; fi
: > "$T/golden"
if [ -d "$GOLDEN" ]; then find "$GOLDEN" -type f \( -name '*.yaml' -o -name '*.yml' -o -name '*.json' -o -name '*.jsonl' \) -print | sort > "$T/golden"; fi
# the last change to a prompt or the golden set that the results may not have seen, in seconds since 1970
# (UTC), when this is a git repository. Author dates, which a rebase keeps. When the repository tracks the
# results, only a change committed after the results' last commit counts, so a prompt committed together
# with its results is not newer than them; when it does not, the last change counts.
GITAT=""; GITDATE=""
if [ "$NOGIT" -eq 0 ] && command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  set -- "$GOLDEN"; [ -z "$PROMPTS" ] || set -- "$GOLDEN" "$PROMPTS"
  RC=""; [ -z "$RESULTS" ] || RC=$(git log -1 --format=%H -- "$RESULTS" 2>/dev/null || true)
  if [ -n "$RC" ]; then RANGE="$RC..HEAD"; else RANGE=HEAD; fi
  GITAT=$(git log --format=%at "$RANGE" -- "$@" 2>/dev/null | sort -n | tail -1 || true)
fi

awk -v app="$APP" -v goldendir="$GOLDEN" -v goldenlist="$T/golden" -v results="$RESULTS" -v format="$FORMAT" -v haveres="$HAVERES" \
  -v res="$T/res" -v rate="$RATE" -v arate="$ARATE" -v maxage="$MAXAGE" -v retr="$RETR" -v haveret="$HAVERET" -v ret="$T/ret" \
  -v targets="$TARGETS" -v sources="$SOURCES" -v reviewby="$REVIEWBY" -v notes="$NOTES" -v tierfile="$TIER" \
  -v threshold="$THRESHOLD" -v today="$TODAY" -v gitat="$GITAT" -v gitdate="$GITDATE" \
  -f "$LIB/common.awk" -f "$LIB/evidence.awk"
