#!/usr/bin/env bash
# Parallel-run test for make/test-mutants.sh (ADR-018).
#
# Runs the harness group (the harness's own controls) one control at a time and
# four at a time, and checks that both runs pass and print the same results in
# the same order, with the same totals: running in parallel must change how long
# the controls take, never what they report. A third run reports the group's
# expect_case controls as they are (ASCENT_MUTANT_RAW=1), so it holds every kind of
# result: the totals must count each one right, and the run must fail.
#
# Uses set -u only: every case runs and reports, and the summary decides.
#
# Slow: the harness group twice. make test-harness and the CI harness job run it.
# Usage: test-mutants-harness.sh [ROOT]   (defaults to this repository)
# Prints "test-mutants-harness: N/N PASS" last.
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "${1:-$HERE/../..}" && pwd)"

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }

# results FILE — status lines and the totals line, without the indented reports
results() { grep -E '^  [A-Za-z]|^test-mutants: ' "$1" || true; }

for j in 1 4; do
  rc=0
  ASCENT_MUTANT_GROUP=harness ASCENT_MUTANT_JOBS=$j bash "$ROOT/make/test-mutants.sh" </dev/null >"$WORK/run-$j" 2>&1 || rc=$?
  if [ "$rc" -eq 0 ]; then ok; else bad "the harness group failed with $j job(s) (rc $rc): $(grep -E '^  (SURVIVED|ANCHOR|MODES|CONTROL)' "$WORK/run-$j" | head -3 | tr '\n' ';')"; fi
done
results "$WORK/run-1" > "$WORK/a"; results "$WORK/run-4" > "$WORK/b"
if [ "$(wc -l < "$WORK/a")" -gt 5 ] && cmp -s "$WORK/a" "$WORK/b"; then ok
else bad "1 job and 4 jobs reported differently: $(diff "$WORK/a" "$WORK/b" | grep '^[<>]' | head -3 | tr '\n' ';')"; fi

rc=0
ASCENT_MUTANT_GROUP=harness ASCENT_MUTANT_JOBS=4 ASCENT_MUTANT_RAW=1 bash "$ROOT/make/test-mutants.sh" </dev/null >"$WORK/raw" 2>&1 || rc=$?
counts=$(awk '/^  [A-Za-z]/ { if ($1 == "killed" || $1 == "control") k++; else if ($1 == "ANCHOR") m++; else s++ }
  END { printf "%d mutants — %d killed, %d survived, %d anchor misses", k + s + m, k, s, m }' "$WORK/raw")
for st in SURVIVED "ANCHOR MISS" "MODES DIFFER" "CONTROL FAIL" killed; do
  if grep -q "^  $st " "$WORK/raw"; then ok; else bad "the raw run has no $st result"; fi
done
if grep -q "^test-mutants: $counts (group: harness, mode: fast)$" "$WORK/raw"; then ok
else bad "the totals do not count the results ($counts): $(grep '^test-mutants: ' "$WORK/raw")"; fi
if [ "$rc" -ne 0 ]; then ok; else bad "a run with survivors, a disagreement, a broken baseline and an anchor miss passed"; fi

printf "test-mutants-harness: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
