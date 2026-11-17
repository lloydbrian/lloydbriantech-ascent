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
# count before the run cannot see it must fail the run. A copy that fails (tar's
# "Write error" on a full disk) must be reported as COPY FAIL, counted as neither
# a kill nor a survivor, and fail the run, with tar's message kept out of the
# result's status line. Naming controls (ASCENT_MUTANT_IDS) must run exactly those
# and a baseline of only their checks; an id the group does not have must stop
# the run; --list must list exactly the controls a run launches. The times file
# and the kill cache (ADR-025) are checked last: one row per control, and a cache
# that reuses only kills whose inputs have not changed.
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
# total-killed total-survived total-anchor result copy-fail" from the summary block and the totals line
summary() {
  awk '/^ killed +[0-9]+ +control [0-9]+ +survived [0-9]+$/ { k = $2; c = $4; s = $6 }
    /^ modes differ [0-9]+ +anchor miss [0-9]+ +control fail [0-9]+ +copy fail [0-9]+$/ { d = $3; a = $6; f = $9; x = $12 }
    /^ result +(PASS|FAIL)$/ { r = $2 }
    /^test-mutants: [0-9]+ mutants/ { for (i = 1; i <= NF; i++) { if ($(i + 1) ~ /^killed,?$/) tk = $i; if ($(i + 1) ~ /^survived,?$/) ts = $i; if ($(i + 1) == "anchor") ta = $i } }
    END { print k + 0, c + 0, s + 0, d + 0, a + 0, f + 0, tk + 0, ts + 0, ta + 0, (r == "" ? "none" : r), x + 0 }' "$1"
}
# check_summary FILE PASS|FAIL — the summary block counts what the totals line counts,
# and its copy failures are the COPY FAIL lines
check_summary() {
  set -- "$1" "$2" $(summary "$1")
  if [ "$(($3 + $4))" -eq "$9" ] && [ "$(($5 + $6 + $8))" -eq "${10}" ] && [ "$7" -eq "${11}" ] && [ "${12}" = "$2" ] \
    && [ "${13}" -eq "$(grep -c '^  COPY FAIL ' "$1")" ]; then ok
  else bad "the summary of $(basename "$1") does not match its totals (or is not $2): $(grep -E '^ (killed|modes|result) |^test-mutants: ' "$1" | tr '\n' ';')"; fi
}

for j in 1 4; do
  rc=0
  # Four jobs run with the progress bar forced on, on stderr apart: the bar must
  # end at N/N 100%, N the controls the totals line counts, and never reach stdout
  ASCENT_MUTANT_GROUP=harness ASCENT_MUTANT_JOBS=$j ASCENT_MUTANT_PROGRESS=$([ "$j" = 4 ] && echo 1 || echo 0) \
    ASCENT_MUTANT_TIMES=$([ "$j" = 4 ] && echo "$WORK/times-4" || true) bash "$ROOT/make/test-mutants.sh" </dev/null >"$WORK/run-$j" 2>"$WORK/err-$j" || rc=$?
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
# The times file (ADR-025): a header and one row per control the run launched,
# baselines included, slowest first; the summary's per-check totals add up to it
n=$(sed -n 's/^test-mutants: \([0-9]*\) mutants .*/\1/p' "$WORK/run-4")
if [ -f "$WORK/times-4" ] && [ "$(sed -n 1p "$WORK/times-4")" = "$(printf 'seconds\tstatus\tid\tgroup\tcheck\tcached')" ] \
  && [ "$(($(wc -l < "$WORK/times-4") - 1))" = "$n" ] \
  && sed 1d "$WORK/times-4" | awk -F'\t' 'NF != 6 || $1 !~ /^[0-9]+$/ || (NR > 1 && $1 > p) { e = 1 } { p = $1 } END { exit e }'; then ok
else bad "the times file is missing, not one row per control ($n), or not slowest first: $(head -3 "$WORK/times-4" 2>/dev/null | tr '\t\n' ' ;')"; fi
want=$(sed 1d "$WORK/times-4" 2>/dev/null | awk -F'\t' '{ t[$5] += $1; n[$5]++ } END { for (k in t) printf "%s %d:%02d (%d)\n", k, int(t[k] / 60), t[k] % 60, n[k] }' | LC_ALL=C sort)
got=$(sed -n 's/^ by check //p' "$WORK/run-4" | awk '{ n = split($0, a, / (·|\|) /); for (i = 1; i <= n; i++) print a[i] }' | LC_ALL=C sort)
if [ -n "$got" ] && printf '%s\n' "$got" | while IFS= read -r l; do printf '%s\n' "$want" | grep -qxF "$l" || exit 1; done; then ok
else bad "the summary's by-check line does not add up to the times file: '$got'"; fi
if grep -q '^ by group ' "$WORK/run-4" && grep -q 'controls written to ' "$WORK/err-4" && ! grep -q 'controls written to ' "$WORK/run-4"; then ok
else bad "no by-group line, or the times notice is not on stderr"; fi

rc=0
ASCENT_MUTANT_GROUP=harness ASCENT_MUTANT_JOBS=4 ASCENT_MUTANT_RAW=1 bash "$ROOT/make/test-mutants.sh" </dev/null >"$WORK/raw" 2>&1 || rc=$?
counts=$(awk '/^  [A-Za-z]/ { if ($1 == "killed" || $1 == "control") k++; else if ($1 == "ANCHOR") m++; else if ($1 == "COPY") x++; else s++ }
  END { printf "%d mutants — %d killed, %d survived, %d anchor misses", k + s + m + x, k, s, m }' "$WORK/raw")
for st in SURVIVED "ANCHOR MISS" "MODES DIFFER" "CONTROL FAIL" "COPY FAIL" killed; do
  if grep -q "^  $st " "$WORK/raw"; then ok; else bad "the raw run has no $st result"; fi
done
if grep -q "^test-mutants: $counts (group: harness, mode: fast)$" "$WORK/raw"; then ok
else bad "the totals do not count the results ($counts): $(grep '^test-mutants: ' "$WORK/raw")"; fi
if [ "$rc" -ne 0 ]; then ok; else bad "a run with survivors, a disagreement, a broken baseline, an anchor miss and a copy failure passed"; fi
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

# A copy that fails for real: a tar on PATH that fails to extract the way a full
# disk does. Every control of the harness group must be COPY FAIL, none killed or
# survived, except P611, which expects COPY FAIL and is confirmed; tar's message
# must stay out of the status lines, and the run must fail.
REAL_TAR=$(command -v tar)
mkdir "$WORK/bin"
printf '#!/bin/sh\ncase " $* " in *" -xf "*) cat >/dev/null; echo "tar: Write error" >&2; echo "tar: Error exit delayed from previous errors." >&2; exit 1 ;; esac\nexec "%s" "$@"\n' "$REAL_TAR" > "$WORK/bin/tar"
chmod +x "$WORK/bin/tar"
rc=0
PATH="$WORK/bin:$PATH" ASCENT_MUTANT_GROUP=harness ASCENT_MUTANT_JOBS=4 ASCENT_MUTANT_PROGRESS=0 \
  bash "$ROOT/make/test-mutants.sh" </dev/null >"$WORK/copyfail" 2>&1 || rc=$?
n=$(sed -n 's/^test-mutants: \([0-9]*\) mutants .*/\1/p' "$WORK/copyfail")
cf=$(grep -c '^  COPY FAIL ' "$WORK/copyfail")
if [ "$rc" -ne 0 ] && [ -n "$n" ] && [ "$n" -gt 1 ] && [ "$cf" -eq $((n - 1)) ] && grep -q '^  confirmed    P611-harness-copy-fail ' "$WORK/copyfail"; then ok
else bad "a failed copy was not COPY FAIL for every control (rc $rc, $cf of '$n'): $(grep -E '^  [A-Za-z]' "$WORK/copyfail" | grep -v '^  COPY FAIL ' | head -3 | tr '\n' ';')"; fi
if grep -q "^test-mutants: $n mutants — 1 killed, 0 survived, 0 anchor misses " "$WORK/copyfail" \
  && grep -q "^test-mutants: $cf control(s) could not copy the repository (COPY FAIL)" "$WORK/copyfail"; then ok
else bad "a failed copy was counted as a kill or a survivor: $(grep '^test-mutants: ' "$WORK/copyfail" | tr '\n' ';')"; fi
if ! grep -qE '^ {0,2}tar: |^          (r: |tar)' "$WORK/copyfail" && grep -q 'copying the repository failed: tar: Write error$' "$WORK/copyfail"; then ok
else bad "tar's message reached a status line or the not-killed list: $(grep -nE 'tar: ' "$WORK/copyfail" | head -3 | tr '\n' ';')"; fi
check_summary "$WORK/copyfail" FAIL

# --list names the controls the run launched, in order, and nothing else
ASCENT_MUTANT_GROUP=harness bash "$ROOT/make/test-mutants.sh" --list | cut -f2 > "$WORK/listed"
results "$WORK/run-1" | awk '/^  [A-Za-z]/ { print ($1 ~ /^(ANCHOR|MODES|CONTROL|COPY)$/ ? $3 : $2) }' | grep -v '^P00-' > "$WORK/ran"
if [ -s "$WORK/listed" ] && cmp -s "$WORK/listed" "$WORK/ran"; then ok
else bad "--list differs from the controls the run launched: $(diff "$WORK/listed" "$WORK/ran" | grep '^[<>]' | head -3 | tr '\n' ';')"; fi

# Two named controls: those two and one baseline, of only their checks (T5, T13; no
# T11 control, so no fast-mode T11 baseline)
rc=0
ASCENT_MUTANT_GROUP=harness ASCENT_MUTANT_IDS="P373-harness-other-subcheck P359-harness-survivor" ASCENT_MUTANT_JOBS=4 ASCENT_MUTANT_PROGRESS=0 \
  bash "$ROOT/make/test-mutants.sh" </dev/null >"$WORK/ids" 2>&1 || rc=$?
got=$(results "$WORK/ids" | awk '/^  [A-Za-z]/ { print $2 }' | tr '\n' ' ')
if [ "$rc" -eq 0 ] && [ "$got" = "P00-baseline P359-harness-survivor P373-harness-other-subcheck " ]; then ok
else bad "ASCENT_MUTANT_IDS did not run exactly the named controls (rc $rc): $got"; fi
if grep -q '^  control      P00-baseline .*(fast mode: T5 T13; T11: none)$' "$WORK/ids"; then ok
else bad "the baseline of two named controls did not run only their checks: $(grep 'P00-baseline' "$WORK/ids")"; fi
rc=0
ASCENT_MUTANT_GROUP=harness ASCENT_MUTANT_IDS="P359-harness-survivor P000-not-a-control" bash "$ROOT/make/test-mutants.sh" </dev/null >"$WORK/badid" 2>&1 || rc=$?
if [ "$rc" -eq 2 ] && grep -q "unknown control id 'P000-not-a-control'" "$WORK/badid" && ! grep -q '^  ' "$WORK/badid"; then ok
else bad "an unknown id did not stop the run before any control (rc $rc): $(head -2 "$WORK/badid" | tr '\n' ';')"; fi

# The kill cache (ADR-025), on a copy: a second run reuses both kills; an edit to
# another plugin keeps them; an edit to the controls' plugin, to its tests or to
# the gate reruns them; full mode says it ignores the cache.
mkdir "$WORK/crepo"
(cd "$ROOT" && tar --exclude ./.git --exclude ./tmp -cf - .) | (cd "$WORK/crepo" && tar -xf -)
CIDS="P32-estimate-ignores-free-tier P35-cfn-allows-http"
crun() {  # NAME — the two controls with the cache; prints "rc cached killed"
  local rc=0
  ASCENT_MUTANT_GROUP=ascent-architecture ASCENT_MUTANT_IDS="$CIDS" ASCENT_MUTANT_PROGRESS=0 \
    ASCENT_MUTANT_CACHE="$WORK/cache" bash "$WORK/crepo/make/test-mutants.sh" </dev/null >"$WORK/cache-$1" 2>&1 || rc=$?
  echo "$rc $(grep -c '^  killed .*(cached)$' "$WORK/cache-$1") $(grep -c '^  killed ' "$WORK/cache-$1")"
}
r=$(crun first);  if [ "$r" = "0 0 2" ] && [ "$(ls "$WORK/cache" | wc -l | tr -d ' ')" = 2 ]; then ok; else bad "the first cached run did not run and keep both kills: $r"; fi
r=$(crun second); if [ "$r" = "0 2 2" ] && grep -q '^ cached   2 kills reused' "$WORK/cache-second"; then ok; else bad "the second run did not reuse both kills: $r"; fi
echo '# not read by any architecture test' >> "$WORK/crepo/plugins/ascent-ux/README.md"
r=$(crun other);  if [ "$r" = "0 2 2" ]; then ok; else bad "an edit to another plugin dropped the cached kills: $r"; fi
for f in plugins/ascent-architecture/README.md tests/plugins/ascent-architecture/test-estimate-cost.sh make/test-plugins.sh; do
  echo '# edited' >> "$WORK/crepo/$f"
  r=$(crun "edit-$(basename "$f")"); if [ "$r" = "0 0 2" ]; then ok; else bad "an edit to $f did not rerun the cached controls: $r"; fi
done
if ASCENT_MUTANT_MODE=full ASCENT_MUTANT_CACHE="$WORK/cache" bash "$WORK/crepo/make/test-mutants.sh" --list 2>&1 >/dev/null | grep -q 'ASCENT_MUTANT_CACHE is ignored in full mode'; then ok
else bad "full mode did not say it ignores the cache"; fi

printf "test-mutants-harness: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
