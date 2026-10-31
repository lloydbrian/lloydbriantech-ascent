#!/usr/bin/env bash
# Parallel-run test for make/test-mutants.sh (ADR-018).
#
# Runs the harness group (the harness's own controls) one control at a time and
# four at a time, and checks that both runs pass and print the same results in
# the same order, with the same totals: running in parallel must change how long
# the controls take, never what they report. A third run reports the group's
# expect_case controls as they are (ASCENT_MUTANT_RAW=1), so it holds every kind of
# result: the totals must count each one right, and the run must fail. In both
# runs the summary block must count what the totals line counts, and the raw run's
# summary must list every control that was not killed; the four-job run shows the
# progress bar, which must end at N/N on stderr. A control declared where the
# count before the run cannot see it must fail the run.
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

# summary FILE — "killed control survived modes-differ anchor-miss control-fail
# total-killed total-survived total-anchor result" from the summary block and the totals line
summary() {
  awk '/^ killed +[0-9]+ +control [0-9]+ +survived [0-9]+$/ { k = $2; c = $4; s = $6 }
    /^ modes differ [0-9]+ +anchor miss [0-9]+ +control fail [0-9]+$/ { d = $3; a = $6; f = $9 }
    /^ result +(PASS|FAIL)$/ { r = $2 }
    /^test-mutants: [0-9]+ mutants/ { for (i = 1; i <= NF; i++) { if ($(i + 1) ~ /^killed,?$/) tk = $i; if ($(i + 1) ~ /^survived,?$/) ts = $i; if ($(i + 1) == "anchor") ta = $i } }
    END { print k + 0, c + 0, s + 0, d + 0, a + 0, f + 0, tk + 0, ts + 0, ta + 0, (r == "" ? "none" : r) }' "$1"
}
# check_summary FILE PASS|FAIL — the summary block counts what the totals line counts
check_summary() {
  set -- "$1" "$2" $(summary "$1")
  if [ "$(($3 + $4))" -eq "$9" ] && [ "$(($5 + $6 + $8))" -eq "${10}" ] && [ "$7" -eq "${11}" ] && [ "${12}" = "$2" ]; then ok
  else bad "the summary of $(basename "$1") does not match its totals (or is not $2): $(grep -E '^ (killed|modes|result) |^test-mutants: ' "$1" | tr '\n' ';')"; fi
}

for j in 1 4; do
  rc=0
  # Four jobs run with the progress bar forced on, on stderr apart: the bar must
  # end at N/N 100%, N the controls the totals line counts, and never reach stdout
  ASCENT_MUTANT_GROUP=harness ASCENT_MUTANT_JOBS=$j ASCENT_MUTANT_PROGRESS=$([ "$j" = 4 ] && echo 1 || echo 0) \
    bash "$ROOT/make/test-mutants.sh" </dev/null >"$WORK/run-$j" 2>"$WORK/err-$j" || rc=$?
  if [ "$rc" -eq 0 ]; then ok; else bad "the harness group failed with $j job(s) (rc $rc): $(grep -E '^  (SURVIVED|ANCHOR|MODES|CONTROL)' "$WORK/run-$j" | head -3 | tr '\n' ';')"; fi
done
results "$WORK/run-1" > "$WORK/a"; results "$WORK/run-4" > "$WORK/b"
if [ "$(wc -l < "$WORK/a")" -gt 5 ] && cmp -s "$WORK/a" "$WORK/b"; then ok
else bad "1 job and 4 jobs reported differently: $(diff "$WORK/a" "$WORK/b" | grep '^[<>]' | head -3 | tr '\n' ';')"; fi
n=$(sed -n 's/^test-mutants: \([0-9]*\) mutants .*/\1/p' "$WORK/run-4")
last=$(tr '\r' '\n' < "$WORK/err-4" | tr -d '\033' | sed 's/^\[K//' | sed -n 's/^\[[^]]*\] *\([0-9]*\/[0-9]*\) *100%.*/\1/p' | tail -1)
if [ -n "$n" ] && [ "$last" = "$n/$n" ]; then ok; else bad "the progress bar did not end at $n/$n 100% (last: '$last')"; fi
if ! grep -q "$(printf '\r')" "$WORK/run-4" && [ ! -s "$WORK/err-1" ]; then ok; else bad "the progress bar reached stdout, or showed with ASCENT_MUTANT_PROGRESS=0"; fi
check_summary "$WORK/run-4" PASS

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
check_summary "$WORK/raw" FAIL
missing=""
for id in $(awk '/^  [A-Za-z]/ && $1 != "killed" && $1 != "control" { print ($1 == "SURVIVED" ? $2 : $3) }' "$WORK/raw"); do
  awk '/^ not killed$/ { on = 1; next } on && /^          / { print (($2 == "MISS" || $2 == "DIFFER" || $2 == "FAIL") ? $3 : $2) }' "$WORK/raw" | grep -qx "$id" || missing="$missing $id"
done
if [ -z "$missing" ]; then ok; else bad "the summary does not list as not killed:$missing"; fi

# A control the count before the run misses (declared on an indented line) must
# fail the run: the core group of a copy with one such control added
mkdir "$WORK/repo"
(cd "$ROOT" && tar --exclude ./.git --exclude ./tmp -cf - .) | (cd "$WORK/repo" && tar -xf -)
awk '/^mutant_group ascent-security$/ { print "  plugin_case P999-uncounted T5 docs/framework/PHILOSOPHY.md '\''s/text that is not in the file/x/'\''" } { print }' \
  "$ROOT/make/test-mutants.sh" > "$WORK/repo/make/test-mutants.sh"
rc=0
ASCENT_MUTANT_GROUP=core bash "$WORK/repo/make/test-mutants.sh" </dev/null >"$WORK/uncounted" 2>&1 || rc=$?
if [ "$rc" -ne 0 ] && grep -q '^test-mutants: counted 0 controls before the run but launched 1 ' "$WORK/uncounted"; then ok
else bad "a control the count missed did not fail the run (rc $rc): $(tail -1 "$WORK/uncounted")"; fi

printf "test-mutants-harness: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
