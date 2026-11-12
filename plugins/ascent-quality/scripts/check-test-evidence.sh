#!/usr/bin/env bash
# Test evidence checks: load tests against the latency and throughput targets, and
# mutation evidence. Part of the ascent-quality plugin (quality-review Step 3,
# test-evidence Step 2). Read-only: nothing is run but a read-only git log.
#
# Usage: check-test-evidence.sh [--p95 MS] [--rps N] [--min-score N] [--max-age DAYS] [--report FILE]... [--maturity enterprise|standard|prototype] [--today YYYY-MM-DD] PATH...
#
# PATH is the repository (or part of it). --p95 and --rps are p95_latency_ms and
# peak_rps from architecture.quality_targets, read and never copied. --min-score
# (default 60) and --max-age (default 90) are quality.mutation.min_score and
# max_age_days; --report adds a quality.mutation.reports entry, a file path inside the
# repository, relative to the current directory. --maturity follows
# quality.maturity_target: prototype requires none of the checks, standard QA-L1,
# QA-L2 and QA-M1, enterprise (the default) all.
#
# Load tests are found by content: a k6 script imports k6, an Artillery file is YAML
# with top-level config: and scenarios:, a Locust file imports locust. Mutation tools:
# Stryker (stryker.conf.*, stryker.config.*, @stryker-mutator/core), mutmut ([mutmut] in setup.cfg or
# pyproject.toml), PIT (pom.xml, build.gradle), go-mutesting and gremlins.
#
# Checks (severity from the quality-review severity table):
#   QA-L1  Medium  a load-test script exists when --p95 or --rps is given
#   QA-L2  Medium  a load test's p95 threshold is no looser than --p95 (k6's untagged
#                  http_req_duration threshold, else its loosest tagged one; Artillery
#                  p95; Locust get_response_time_percentile(0.95))
#   QA-L3  Medium  a load test's request rate reaches --rps (k6 arrival-rate rate or
#                  target per timeUnit; Artillery arrivalRate or rampTo; Locust
#                  constant_throughput or constant_pacing times its users); a load
#                  set in virtual users is a NOTE, never a pass
#   QA-L4  Low     a load test sets an error-rate threshold (k6 http_req_failed or
#                  checks, Artillery maxErrorRate, Locust fail_ratio)
#   QA-L5  Low     a CI step, a make recipe, a package script or a runbook (Markdown)
#                  runs the load test
#   QA-M1  Medium  a mutation tool is configured
#   QA-M2  Medium  the tool's break threshold is at least --min-score (Stryker
#                  thresholds.break, PIT mutationThreshold, gremlins efficacy);
#                  mutmut and go-mutesting have none, which is a NOTE
#   QA-M3  Low     a CI step runs the mutation tool (make recipes and package scripts
#                  followed three levels deep)
#   QA-M4  Medium  the newest usable report (*mutation.json, *mutations.xml,
#                  *mutation-report.*, *mutation-score*, or --report) scores at least
#                  --min-score and is no older than --max-age days. A report is dated
#                  by a date in its path, else by the author date of its last commit
#                  (none in a shallow clone). A report that cannot be used beside a
#                  usable one is a NOTE
#
# Output: FAIL lines (FAIL  QA-xn  SEVERITY  file:line  message), a PASS line per
# check with no finding, N/A when a check found nothing to check or is not required,
# NOTE lines (unrated), then "check-test-evidence: ...".
# Limits: static. Thresholds and rates computed at runtime are not seen; at least
# one load script must meet each check, so the script that meets the latency
# threshold may not be the one at peak rate. Gatling and JMeter are not read.
# Exit: 0 no FAIL; 1 at least one FAIL; 2 bad input.
# Portable: GNU/Linux and BSD/macOS, bash 3.2+, POSIX awk, run with LC_ALL=C.

set -euo pipefail

usage() { sed -n '6p' "$0" | sed 's/^# //'; }
bad() { echo "check-test-evidence: $1" >&2; exit 2; }
P95=""; RPS=""; MINS=60; MAXAGE=90; MATURITY=enterprise; TODAY=""
PATHS=(); REPORTS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --p95|--rps|--min-score|--max-age|--report|--maturity|--today)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      case "$1" in
        --p95) P95="$2" ;; --rps) RPS="$2" ;; --min-score) MINS="$2" ;; --max-age) MAXAGE="$2" ;;
        --report) REPORTS+=("$2") ;; --maturity) MATURITY="$2" ;; --today) TODAY="$2" ;;
      esac
      shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) bad "unknown option $1" ;;
    *) PATHS+=("$1"); shift ;;
  esac
done
[ ${#PATHS[@]} -gt 0 ] || { usage >&2; exit 2; }

isnum() { printf '%s\n' "$1" | grep -Eq '^[0-9]+([.][0-9]+)?$'; }
[ -z "$P95" ] || isnum "$P95" || bad "--p95 is a number of milliseconds, got '$P95'"
[ -z "$RPS" ] || isnum "$RPS" || bad "--rps is a number of requests per second, got '$RPS'"
isnum "$MINS" && [ "${MINS%%.*}" -le 100 ] || bad "--min-score is a percentage from 0 to 100, got '$MINS'"
case "$MAXAGE" in ''|*[!0-9]*) bad "--max-age must be a number of days" ;; esac
case "$MATURITY" in enterprise|standard|prototype) ;; *) bad "--maturity must be enterprise, standard or prototype" ;; esac
[ -z "$TODAY" ] && TODAY=$(date +%Y-%m-%d)
case "$TODAY" in [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]) ;; *) bad "--today must be YYYY-MM-DD" ;; esac
y=$((10#${TODAY%%-*})); m=${TODAY#*-}; m=$((10#${m%-*})); d=$((10#${TODAY##*-})); ml=31
case $m in 4|6|9|11) ml=30 ;; 2) ml=28; { [ $((y % 4)) -eq 0 ] && [ $((y % 100)) -ne 0 ]; } || [ $((y % 400)) -eq 0 ] && ml=29 ;; esac
[ "$m" -ge 1 ] && [ "$m" -le 12 ] && [ "$d" -ge 1 ] && [ "$d" -le "$ml" ] || bad "--today is not a calendar date: $TODAY"

LIB="$(cd "$(dirname "$0")" && pwd)/lib"
for f in qa-files.sh qa-common.awk check-test-evidence.awk; do
  [ -f "$LIB/$f" ] || bad "missing $LIB/$f"
done
# shellcheck source=lib/qa-files.sh
. "$LIB/qa-files.sh"

qa_collect check-test-evidence "s t td yml mut mrep cfg pkg make ci doc" "" "${PATHS[@]}"
for r in ${REPORTS[@]+"${REPORTS[@]}"}; do
  case "$r" in /*|..|../*|*/..|*/../*) bad "--report must be a path inside the repository: $r" ;; esac
  [ ! -L "$r" ] || bad "--report must not be a symbolic link: $r"
  [ -f "$r" ] || bad "no such report: $r"
  qa_add mrep "$r"
done
[ ${#ARGS[@]} -gt 0 ] || ARGS=("K=none" /dev/null)

# Report dates: a report with no date in its path is dated by the author date of its
# last commit (git log, read-only; a rebase keeps it). git runs from the current
# directory only, never from a folder inside the scanned tree, with bare-repository
# discovery and signature checks switched off, so a crafted folder or config in the
# repository cannot make it run a program. A shallow clone has no history to date by.
TAB=$(printf '\t'); RDATES=""; GITOK=0; SHALLOW=0
GITC="-c safe.bareRepository=explicit -c log.showSignature=false -c core.fsmonitor=false"
# shellcheck disable=SC2086
if command -v git >/dev/null 2>&1 && [ "$(git $GITC rev-parse --is-inside-work-tree 2>/dev/null || true)" = true ]; then
  if [ "$(git $GITC rev-parse --is-shallow-repository 2>/dev/null || true)" = true ]; then SHALLOW=1; else GITOK=1; fi
fi
i=0
while [ "$i" -lt ${#ARGS[@]} ]; do
  if [ "${ARGS[$i]}" = K=mrep ]; then
    f=${ARGS[$((i + 1))]}; dt=""
    case "$f" in
      *[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*) ;;
      # shellcheck disable=SC2086
      *) if [ "$GITOK" = 1 ]; then dt=$(git $GITC --no-pager log -1 --format=%as -- "$f" 2>/dev/null || true); fi ;;
    esac
    RDATES="$RDATES${f#./}$TAB$dt
"
  fi
  i=$((i + 2))
done

QA_P95="$P95" QA_RPS="$RPS" QA_MIN="$MINS" QA_MAXAGE="$MAXAGE" QA_TODAY="$TODAY" \
QA_MATURITY="$MATURITY" QA_RDATES="$RDATES" QA_SHALLOW="$SHALLOW" QA_PATHS="${PATHS[*]}" \
  LC_ALL=C awk -f "$LIB/qa-common.awk" -f "$LIB/check-test-evidence.awk" "${ARGS[@]}"
