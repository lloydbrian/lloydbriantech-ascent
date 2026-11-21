#!/usr/bin/env bash
# Behavior test for the fast mode of make/test-plugins.sh (gate check T14, ADR-018).
#
# Builds fixture repositories with one plugin, fx, whose behavior tests pass, fail,
# hang or misreport on purpose, and runs the gate's T11 on them in fast mode
# (ASCENT_T11_FAST=1) and in full mode. Checks that fast mode stops a test at its
# first FAIL line and stops its children, stops T11 at the first failing test,
# runs first the tests that name ASCENT_T11_FIRST, gives each test its own TMPDIR,
# and reaches the same verdict as full mode; that a test printing a FAIL line and
# exiting 0 fails in both modes; that ASCENT_ONLY runs one section, or the
# sections of a list of labels, and rejects an unknown label; that T7 names each
# failing file and its reason, or shows the checker's last lines when it gave
# none; that ASCENT_T11_ONLY runs the behavior tests of the plugins it lists; and
# that ASCENT_T11_LEAD runs the named test first in fast mode, ahead of the tests that
# name ASCENT_T11_FIRST, and changes nothing in full mode; and that
# make/mutant-order.sh finds the test that caught a control, merges a times file
# into the order file and counts its rows; and that make/test-mutants.sh
# --baselines launches one test-suite baseline: in fast mode the fast-mode
# baseline runs the behavior tests, and P00-baseline the other checks only; and
# that the harness refuses MUTANT_FULL outside its own group (ADR-029).
#
# Usage: test-gate-fast.sh [GATE]   (defaults to make/test-plugins.sh)
# Prints "test-gate-fast: N/N PASS" last (make/test-plugins.sh T14). A failing case
# prints "FAIL  G<n> …", which T14 reports as T14.G<n>. Uses set -u only: every
# case runs and reports, and the summary decides.
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
HERE="$(cd "$(dirname "$0")" && pwd)"
GATE="${1:-$HERE/../../make/test-plugins.sh}"
[ -f "$GATE" ] || { echo "test-gate-fast: missing $GATE"; echo "test-gate-fast: 0/1 PASS"; exit 1; }

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }

# fixture NAME [PLUGIN] — a repository with plugin PLUGIN (default fx; scripts x.sh
# and y.sh) and no tests; a second call with another PLUGIN adds that plugin
fixture() {
  local pl=${2:-fx}
  F="$WORK/$1"
  mkdir -p "$F/plugins/$pl/.claude-plugin" "$F/plugins/$pl/scripts" "$F/tests/plugins/$pl" "$F/.claude-plugin"
  printf '{\n  "name": "%s",\n  "version": "0.0.1"\n}\n' "$pl" > "$F/plugins/$pl/.claude-plugin/plugin.json"
  printf '{\n  "name": "fixture",\n  "plugins": []\n}\n' > "$F/.claude-plugin/marketplace.json"
  printf '#!/bin/sh\n' > "$F/plugins/$pl/scripts/x.sh"
  printf '#!/bin/sh\n' > "$F/plugins/$pl/scripts/y.sh"
}
# testfile NAME BODY [PLUGIN] — tests/plugins/PLUGIN/NAME.sh in the current fixture
testfile() { printf '#!/usr/bin/env bash\n%s\n' "$2" > "$F/tests/plugins/${3:-fx}/$1.sh"; }
# passing NAME SCRIPT — a test that names SCRIPT and passes with its summary
passing() { testfile "$1" "# exercises $2
echo '$1: 1/1 PASS'"; }
# gate fast|full [VAR=value...] — run T11 on the fixture; output in $OUT, status in $RC.
# The fast-mode switches are reset first: a negative control runs this test with its
# own ASCENT_T11_FIRST, ASCENT_T11_ONLY and ASCENT_T11_LEAD set, which must not reach
# the fixtures.
gate() {
  local mode=$1; shift
  OUT="$WORK/out"; RC=0
  env ASCENT_T11_FIRST= ASCENT_T11_ONLY= ASCENT_T11_LEAD= ASCENT_ONLY=T11 ASCENT_T11_FAST=$([ "$mode" = fast ] && echo 1 || echo 0) "$@" \
    bash "$GATE" "$F" </dev/null >"$OUT" 2>&1 || RC=$?
}
t11() { grep '^\(PASS\|FAIL\)  test-plugins: T11 ' "$OUT" || true; }

# --- G1  a passing plugin passes in both modes
fixture g1; passing test-a x.sh; passing test-b y.sh
for m in fast full; do
  gate $m
  if [ "$RC" -eq 0 ] && t11 | grep -q '^PASS  test-plugins: T11 fx: 2 behavior test file(s), 2 cases pass'; then ok; else bad "G1 $m: a passing plugin did not pass: $(t11)"; fi
done

# --- G2  fast mode stops a test at its first FAIL line, and stops its children
fixture g2; passing test-b y.sh
testfile test-a "# exercises x.sh
( sleep 4; touch '$WORK/g2-child' ) &
echo 'FAIL  case 1'
sleep 20
echo 'test-a: 0/1 PASS'; exit 1"
start=$(date +%s); gate fast; took=$(( $(date +%s) - start ))
if [ "$RC" -ne 0 ] && t11 | grep -q '^FAIL  test-plugins: T11 fx: test-a failed: FAIL  case 1;'; then ok; else bad "G2 fast mode did not fail T11 on the first FAIL line: $(t11)"; fi
if [ "$took" -lt 10 ]; then ok; else bad "G2 fast mode took ${took}s; it should stop the test at its first FAIL line"; fi
sleep 5
if [ ! -e "$WORK/g2-child" ]; then ok; else bad "G2 a child of the stopped test kept running"; fi

# --- G3  fast mode stops T11 at the first failing test; full mode runs them all
fixture g3
testfile test-a "# exercises x.sh
echo 'FAIL  case 1'; echo 'test-a: 0/1 PASS'; exit 1"
testfile test-b "# exercises y.sh
touch '$WORK/g3-b-ran'; echo 'test-b: 1/1 PASS'"
gate fast
if [ "$RC" -ne 0 ] && [ ! -e "$WORK/g3-b-ran" ]; then ok; else bad "G3 fast mode ran test-b after test-a failed (rc $RC)"; fi
gate full
if [ "$RC" -ne 0 ] && [ -e "$WORK/g3-b-ran" ]; then ok; else bad "G3 full mode did not run every test (rc $RC)"; fi

# --- G4  ASCENT_T11_FIRST puts the tests that name the edited file first
fixture g4
testfile test-a "# exercises x.sh
echo 'FAIL  from a'; echo 'test-a: 0/1 PASS'; exit 1"
testfile test-b "# exercises y.sh
echo 'FAIL  from b'; echo 'test-b: 0/1 PASS'; exit 1"
gate fast ASCENT_T11_FIRST=y.sh
if t11 | grep -q 'test-b failed: FAIL  from b;' && ! t11 | grep -q 'test-a'; then ok; else bad "G4 ASCENT_T11_FIRST=y.sh did not run test-b first: $(t11)"; fi
gate fast
if t11 | grep -q 'test-a failed: FAIL  from a;' && ! t11 | grep -q 'test-b'; then ok; else bad "G4 without ASCENT_T11_FIRST the tests did not run in name order: $(t11)"; fi
# A path: the tests that name the path run before those that name only its file name,
# and with no test naming the path, those that name the file name run first (ADR-025)
fixture g4p
testfile test-a "# reads skills/one/SKILL.md
echo 'FAIL  from a'; echo 'test-a: 0/1 PASS'; exit 1"
testfile test-b "# reads skills/two/SKILL.md and NOTES.md
echo 'FAIL  from b'; echo 'test-b: 0/1 PASS'; exit 1"
testfile test-c "# reads nothing named
echo 'FAIL  from c'; echo 'test-c: 0/1 PASS'; exit 1"
gate fast ASCENT_T11_FIRST=skills/two/SKILL.md
if t11 | grep -q 'test-b failed: FAIL  from b;' && ! t11 | grep -q 'test-a'; then ok; else bad "G4 ASCENT_T11_FIRST=skills/two/SKILL.md did not run test-b first: $(t11)"; fi
gate fast ASCENT_T11_FIRST=docs/NOTES.md
if t11 | grep -q 'test-b failed: FAIL  from b;' && ! t11 | grep -q 'test-a'; then ok; else bad "G4 a path no test names did not fall back to its file name: $(t11)"; fi

# --- G5  a FAIL line with exit status 0 fails T11 in both modes
fixture g5; passing test-b y.sh
testfile test-a "# exercises x.sh
echo 'FAIL  case 1'; echo 'test-a: 1/1 PASS'; exit 0"
gate full
if [ "$RC" -ne 0 ] && t11 | grep -q 'test-a printed FAIL lines but exited 0;'; then ok; else bad "G5 full mode passed a test that printed a FAIL line: $(t11)"; fi
gate fast
if [ "$RC" -ne 0 ] && t11 | grep -q '^FAIL  test-plugins: T11 fx:.*test-a'; then ok; else bad "G5 fast mode passed a test that printed a FAIL line: $(t11)"; fi

# --- G6  a test that fails without a FAIL line fails in both modes
fixture g6; passing test-b y.sh
testfile test-a "# exercises x.sh
echo 'test-a: 0/1 PASS'; exit 3"
for m in fast full; do
  gate $m
  if [ "$RC" -ne 0 ] && t11 | grep -q '^FAIL  test-plugins: T11 fx: test-a failed: *$'; then ok; else bad "G6 $m: a test that exited 3 did not fail T11: $(t11)"; fi
done

# --- G7  fast mode gives each test its own TMPDIR, removed with the gate
fixture g7
testfile test-a "# exercises x.sh
echo \"\$TMPDIR\" > '$WORK/g7-tmpdir-a'; touch \"\$TMPDIR/left-behind\"
echo 'test-a: 1/1 PASS'"
testfile test-b "# exercises y.sh
echo \"\$TMPDIR\" > '$WORK/g7-tmpdir-b'
echo 'test-b: 1/1 PASS'"
gate fast
d=$(cat "$WORK/g7-tmpdir-a" 2>/dev/null || true); e=$(cat "$WORK/g7-tmpdir-b" 2>/dev/null || true)
case "$d" in
  */tmp-1-fx) if [ ! -e "$d" ]; then ok; else bad "G7 the test's TMPDIR $d outlived the gate"; fi ;;
  *) bad "G7 fast mode did not give the test its own TMPDIR (got '$d')" ;;
esac
case "$e" in
  */tmp-2-fx) ok ;;
  *) bad "G7 the second test did not get a TMPDIR of its own (got '$e', first '$d')" ;;
esac

# --- G8  ASCENT_ONLY runs one section, maps T13.4 to T13, and rejects an unknown label
fixture g8; passing test-a x.sh; passing test-b y.sh
gate fast
others=$(grep '^\(PASS\|FAIL\|SKIP\)  test-plugins: ' "$OUT" | grep -v '^\(PASS\|FAIL\|SKIP\)  test-plugins: T11 ' || true)
if [ -z "$others" ]; then ok; else bad "G8 ASCENT_ONLY=T11 ran other checks: $others"; fi
RC=0; ASCENT_ONLY=T13.4 bash "$GATE" "$F" </dev/null >"$WORK/out" 2>&1 || RC=$?
others=$(grep '^\(PASS\|FAIL\|SKIP\)  test-plugins: ' "$WORK/out" | grep -v '^\(PASS\|FAIL\)  test-plugins: T13' || true)
if [ -z "$others" ] && grep -q '^\(PASS\|FAIL\)  test-plugins: T13' "$WORK/out"; then ok; else bad "G8 ASCENT_ONLY=T13.4 did not run T13 alone: $others"; fi
for label in T99 .4; do
  RC=0; ASCENT_ONLY=$label bash "$GATE" "$F" </dev/null >"$WORK/out" 2>&1 || RC=$?
  if [ "$RC" -eq 2 ] && grep -q "unknown ASCENT_ONLY label '$label'" "$WORK/out"; then ok; else bad "G8 the label '$label' was not rejected (rc $RC)"; fi
done

# --- G9  fast mode stops T11 at the first failing plugin; full mode runs them all
fixture g9 fa; fixture g9 fb
testfile test-a "# exercises x.sh y.sh
echo 'FAIL  case 1'; echo 'test-a: 0/1 PASS'; exit 1" fa
testfile test-b "# exercises x.sh y.sh
touch '$WORK/g9-fb-ran'; echo 'test-b: 1/1 PASS'" fb
gate fast
if [ "$RC" -ne 0 ] && [ ! -e "$WORK/g9-fb-ran" ]; then ok; else bad "G9 fast mode ran plugin fb after fa failed (rc $RC)"; fi
gate full
if [ "$RC" -ne 0 ] && [ -e "$WORK/g9-fb-ran" ]; then ok; else bad "G9 full mode did not run every plugin (rc $RC)"; fi

# --- G10 T7 names each failing file and its reason under its FAIL line, and only those
fixture g10; mkdir -p "$F/make" "$F/plugins/fx/skills/bad" "$F/plugins/fx/skills/good"
cp "$(dirname "$GATE")/qa-skill-frontmatter.sh" "$F/make/"
printf -- '---\nname: bad\ndescription: Use when testing.\nallowed-tools: Read\n---\n' > "$F/plugins/fx/skills/bad/SKILL.md"
printf -- '---\nname: good\ndescription: Use when testing.\nversion: 0.0.1\nallowed-tools: Read\n---\n' > "$F/plugins/fx/skills/good/SKILL.md"
RC=0; ASCENT_ONLY=T7 bash "$GATE" "$F" </dev/null >"$WORK/out" 2>&1 || RC=$?
under=$(awk '/^FAIL  test-plugins: T7 / { on = 1; next } on && /^      / { print; next } { on = 0 }' "$WORK/out")
if [ "$RC" -ne 0 ] && grep -q '^FAIL  test-plugins: T7 qa-skill-frontmatter failed on plugins/' "$WORK/out"; then ok; else bad "G10 T7 did not fail on a skill without a version (rc $RC)"; fi
if printf '%s\n' "$under" | grep -q 'Checking: .*/plugins/fx/skills/bad/SKILL.md' && printf '%s\n' "$under" | grep -q "missing required field 'version'"; then ok
else bad "G10 T7 did not name the file and the reason under its FAIL line: $(printf '%s' "$under" | tr '\n' ';')"; fi
if ! grep -q 'skills/good/' <<< "$under"; then ok; else bad "G10 T7 listed a file that passed: $(printf '%s' "$under" | tr '\n' ';')"; fi

# --- G11 when the checker fails without a reason, T7 shows its last three lines
printf '#!/usr/bin/env bash\nprintf "one\\ntwo\\nthree\\nfour\\n"; exit 3\n' > "$F/make/qa-skill-frontmatter.sh"
RC=0; ASCENT_ONLY=T7 bash "$GATE" "$F" </dev/null >"$WORK/out" 2>&1 || RC=$?
under=$(awk '/^FAIL  test-plugins: T7 / { on = 1; next } on && /^      / { print; next } { on = 0 }' "$WORK/out" | tr '\n' ';')
if [ "$RC" -ne 0 ] && grep -q '^FAIL  test-plugins: T7 .*(rc 3)$' "$WORK/out" && [ "$under" = "      two;      three;      four;" ]; then ok
else bad "G11 T7 did not show the checker's last lines and status (rc $RC): $under"; fi

# --- G12 T7 passes a valid skill whose frontmatter is larger than a pipe buffer: a
# reader that stops early (grep -q, awk exit) on a pipe from printf kills the writer
# with SIGPIPE, and pipefail turns that into a false "missing required field"
fixture g12; mkdir -p "$F/make" "$F/plugins/fx/skills/big"
cp "$(dirname "$GATE")/qa-skill-frontmatter.sh" "$F/make/"
{ printf -- '---\nname: big\ndescription: Use when testing.\nversion: 0.0.1\nallowed-tools: Read\n'
  awk 'BEGIN { for (i = 1; i <= 4000; i++) printf "x-filler-%04d: padding that pushes the frontmatter past a pipe buffer\n", i }'
  printf -- '---\n'; } > "$F/plugins/fx/skills/big/SKILL.md"
RC=0; ASCENT_ONLY=T7 bash "$GATE" "$F" </dev/null >"$WORK/out" 2>&1 || RC=$?
if [ "$RC" -eq 0 ] && grep -q '^PASS  test-plugins: T7 ' "$WORK/out"; then ok
else bad "G12 T7 failed a valid skill with a large frontmatter (rc $RC): $(grep -E '^ +(FAIL|Checking)' "$WORK/out" | head -2 | tr '\n' ';')"; fi

# --- G13 ASCENT_ONLY with a list runs each label's section and no other, and rejects
# a list with an unknown label
fixture g13; passing test-a "x.sh y.sh"
RC=0; ASCENT_ONLY="T11 T13.4" ASCENT_T11_ONLY= bash "$GATE" "$F" </dev/null >"$WORK/out" 2>&1 || RC=$?
others=$(grep '^\(PASS\|FAIL\|SKIP\)  test-plugins: ' "$WORK/out" | grep -v '^\(PASS\|FAIL\)  test-plugins: T1[13]' || true)
if [ -z "$others" ] && grep -q '^PASS  test-plugins: T11 ' "$WORK/out" && grep -q '^\(PASS\|FAIL\)  test-plugins: T13' "$WORK/out"; then ok
else bad "G13 ASCENT_ONLY='T11 T13.4' did not run T11 and T13 alone: $(printf '%s' "$others" | head -2 | tr '\n' ';')"; fi
RC=0; ASCENT_ONLY="T11 T99" bash "$GATE" "$F" </dev/null >"$WORK/out" 2>&1 || RC=$?
if [ "$RC" -eq 2 ] && grep -q "unknown ASCENT_ONLY label 'T99'" "$WORK/out"; then ok; else bad "G13 the list 'T11 T99' was not rejected (rc $RC)"; fi

# --- G14 ASCENT_T11_ONLY runs the behavior tests of the plugins it lists, and none for "none"
fixture g14 fa; fixture g14 fb; fixture g14 fc
for pl in fa fb fc; do testfile test-a "# exercises x.sh y.sh
touch '$WORK/g14-$pl-ran'; echo 'test-a: 1/1 PASS'" "$pl"; done
gate full ASCENT_T11_ONLY="fa fc"
if [ "$RC" -eq 0 ] && [ -e "$WORK/g14-fa-ran" ] && [ ! -e "$WORK/g14-fb-ran" ] && [ -e "$WORK/g14-fc-ran" ]; then ok
else bad "G14 ASCENT_T11_ONLY='fa fc' did not run exactly fa and fc (rc $RC): $(ls "$WORK" | grep g14- | tr '\n' ' ')"; fi
rm -f "$WORK"/g14-*-ran
gate full ASCENT_T11_ONLY=none
if [ "$RC" -eq 0 ] && ! ls "$WORK" | grep -q 'g14-.*-ran'; then ok; else bad "G14 ASCENT_T11_ONLY=none ran behavior tests (rc $RC)"; fi

# --- G15 ASCENT_T11_LEAD runs the named test first in fast mode, ahead of the tests
# that name ASCENT_T11_FIRST; an unknown name changes nothing; full mode ignores it
fixture g15
testfile test-a "# exercises x.sh
echo 'FAIL  from a'; echo 'test-a: 0/1 PASS'; exit 1"
testfile test-b "# exercises y.sh
echo 'FAIL  from b'; echo 'test-b: 0/1 PASS'; exit 1"
testfile test-c "# reads nothing named
echo 'FAIL  from c'; echo 'test-c: 0/1 PASS'; exit 1"
gate fast ASCENT_T11_LEAD=test-c
if t11 | grep -q 'test-c failed: FAIL  from c;' && ! t11 | grep -q 'test-[ab]'; then ok; else bad "G15 ASCENT_T11_LEAD=test-c did not run test-c first: $(t11)"; fi
gate fast ASCENT_T11_FIRST=y.sh ASCENT_T11_LEAD=test-c
if t11 | grep -q 'test-c failed: FAIL  from c;' && ! t11 | grep -q 'test-[ab]'; then ok; else bad "G15 the lead did not run ahead of the tests that name ASCENT_T11_FIRST: $(t11)"; fi
gate fast ASCENT_T11_LEAD=test-zzz
if t11 | grep -q 'test-a failed: FAIL  from a;' && ! t11 | grep -q 'test-[bc]'; then ok; else bad "G15 an unknown lead changed the name order: $(t11)"; fi
gate full ASCENT_T11_LEAD=test-c
if t11 | grep -q '^FAIL  test-plugins: T11 fx: test-a failed:'; then ok; else bad "G15 full mode did not ignore ASCENT_T11_LEAD: $(t11)"; fi
# A lead that passes leaves the other tests to run, so the verdict cannot change
testfile test-c "# reads nothing named
echo 'test-c: 1/1 PASS'"
gate fast ASCENT_T11_LEAD=test-c
if t11 | grep -q 'test-a failed: FAIL  from a;'; then ok; else bad "G15 a lead that passes stopped T11 before the test that fails: $(t11)"; fi
# Two plugins whose tests share the lead's name: fast mode stops at the first failing
# plugin, and within it the lead runs first
fixture g15p fa; fixture g15p fb
for pl in fa fb; do
  testfile test-x "# exercises x.sh y.sh
echo 'FAIL  from x'; echo 'test-x: 0/1 PASS'; exit 1" "$pl"
  testfile test-y "# exercises x.sh y.sh
echo 'FAIL  from y'; echo 'test-y: 0/1 PASS'; exit 1" "$pl"
done
gate fast ASCENT_T11_ONLY="fa fb" ASCENT_T11_LEAD=test-y
if t11 | grep -q '^FAIL  test-plugins: T11 fa: test-y failed: FAIL  from y;' && ! t11 | grep -q 'test-x' && ! t11 | grep -q ' fb:'; then ok
else bad "G15 with two plugins the lead did not run first in the first plugin alone: $(t11)"; fi

# --- G16 make/mutant-order.sh caught names the first test the T11 FAIL line says
# failed: not a problem that names no failing test, and not a later line or check
MO="$(dirname "$GATE")/mutant-order.sh"
caught_of() {  # caught_of WANT LINE — caught reads LINE as the gate's output
  printf '%s\n' "$2" > "$WORK/g16.out"; RC=0
  GOT=$(bash "$MO" caught "$WORK/g16.out" 2>&1) || RC=$?
  if [ "$RC" -eq 0 ] && [ "$GOT" = "$1" ]; then ok; else bad "G16 caught read '$2' as '$GOT' (rc $RC), expected '$1'"; fi
}
caught_of test-b 'FAIL  test-plugins: T11 fx: test-b failed: FAIL  x;'
caught_of test-c 'FAIL  test-plugins: T11 fx: scripts/z.sh is not exercised by any test; test-a printed FAIL lines but exited 0; test-c failed: FAIL  test-d failed: y;'
caught_of '' 'FAIL  test-plugins: T11 fx: scripts/z.sh is not exercised by any test;'
caught_of '' 'FAIL  test-plugins: T5 test-a failed: x'
caught_of '' ''

# --- G17 make/mutant-order.sh merge replaces and adds the rows of controls killed
# with a catching test, keeps every other row, drops the rows of controls that no
# longer exist and refuses a times file without the "caught by" column; count
# reports the led, T11 and stale counts, and a damaged order file is never fatal
T=$(printf '\t'); G17="$WORK/g17"; mkdir -p "$G17/root/tests/plugins/fx"
touch "$G17/root/tests/plugins/fx/t4.sh"
{ echo '# a header comment'; echo "A${T}t1"; echo "B${T}t2"; printf 'C%st3\r\n' "$T"; echo "Z${T}t9"; echo "B${T}t8"; echo junk; } > "$G17/order"
printf 'A\nB\nC\nD\n' > "$G17/ids"
{ echo "seconds${T}status${T}id${T}group${T}check${T}cached${T}caught by"
  echo "9${T}killed${T}A${T}g${T}T11${T}${T}t4"; echo "9${T}killed${T}B${T}g${T}T11${T}${T}"
  echo "9${T}SURVIVED${T}C${T}g${T}T11${T}${T}"; echo "9${T}killed${T}D${T}g${T}T11${T}${T}t5"
  echo "0${T}killed${T}E${T}g${T}T11${T}cached${T}"; echo "99${T}control${T}P00-baseline${T}baseline${T}baseline${T}${T}"; } > "$G17/times"
RC=0; bash "$MO" merge "$G17/times" "$G17/order" "$G17/ids" > "$WORK/g17.out" 2>&1 || RC=$?
rows=$(grep -v '^#' "$WORK/g17.out" | tr '\t\n' ' ;')
if [ "$RC" -eq 0 ] && [ "$rows" = "A t4;B t2;C t3;D t5;" ] && head -1 "$WORK/g17.out" | grep -q '^# Generated by make mutant-order FROM='; then ok
else bad "G17 merge gave (rc $RC): $(tr '\t\n' ' ;' < "$WORK/g17.out")"; fi
head -6 "$G17/times" | cut -f1-6 > "$G17/times6"
RC=0; bash "$MO" merge "$G17/times6" "$G17/order" "$G17/ids" > "$WORK/g17.out" 2>&1 || RC=$?
if [ "$RC" -eq 2 ] && grep -q 'times6 is not a times file with a "caught by" column' "$WORK/g17.out"; then ok
else bad "G17 merge accepted a times file without the caught by column (rc $RC): $(head -2 "$WORK/g17.out" | tr '\n' ';')"; fi
for c in A B E; do echo "g${T}$c${T}T11${T}edit${T}f${T}fx${T}0${T}0"; done > "$G17/manifest"
echo "g${T}F${T}T5${T}edit${T}f${T}fx${T}0${T}0" >> "$G17/manifest"
count_of() {  # count_of WANT ORDER [all]
  RC=0; GOT=$(bash "$MO" count "$2" "$G17/manifest" "$G17/root" ${3:-} 2>&1) || RC=$?
  if [ "$RC" -eq 0 ] && [ "$GOT" = "$1" ]; then ok; else bad "G17 count of $(basename "$2") ${3:-} gave '$GOT' (rc $RC), expected '$1'"; fi
}
{ echo '# a header comment'; echo "A${T}t4"; echo "B${T}t2"; echo "Z${T}t9"; } > "$G17/counted"
count_of '1 3 1' "$G17/counted"
count_of '1 3 2' "$G17/counted" all
{ echo "A${T}t4"; echo junk; } > "$G17/malformed"
count_of '1 3 1' "$G17/malformed"
: > "$G17/empty"; echo '# only a header' > "$G17/header"
count_of '0 3 0' "$G17/missing"
count_of '0 3 0' "$G17/empty"
count_of '0 3 0' "$G17/header"

# --- G18 make/test-mutants.sh --baselines: the baselines a run of the harness group
# would launch, without running anything. In fast mode P00-fast-baseline is the only
# one that runs the behavior tests; P00-baseline runs the other checks, and is not
# launched when T11 is the only one; full mode runs one baseline, the whole gate.
# The run's own ASCENT_MUTANT_* settings are reset: T14 runs inside a control's gate
HARN="$(dirname "$GATE")/test-mutants.sh"
baselines_of() {  # baselines_of WANT IDS [MODE]
  local start=$SECONDS
  RC=0; GOT=$(env ASCENT_MUTANT_GROUP=harness ASCENT_MUTANT_IDS="$2" ASCENT_MUTANT_MODE="${3:-}" ASCENT_MUTANT_TIMES= \
    ASCENT_MUTANT_CACHE= ASCENT_MUTANT_JOBS= ASCENT_MUTANT_RAW= MUTANT_FULL= bash "$HARN" --baselines 2>&1 </dev/null) || RC=$?
  if [ "$RC" -eq 0 ] && [ "$GOT" = "$1" ] && [ $((SECONDS - start)) -lt 10 ]; then ok
  else bad "G18 --baselines for '$2' ${3:-fast} gave (rc $RC, $((SECONDS - start))s): $(printf '%s' "$GOT" | tr '\t\n' ' ;')"; fi
}
baselines_of "P00-fast-baseline${T}T11${T}ascent-architecture" P361-harness-anchor-miss
baselines_of "P00-baseline${T}T5${T}ascent-architecture
P00-fast-baseline${T}T11${T}ascent-architecture" "P359-harness-survivor P361-harness-anchor-miss"
baselines_of "P00-baseline${T}T5 T13${T}none" "P359-harness-survivor P373-harness-other-subcheck"
baselines_of "P00-baseline${T}all${T}all" P361-harness-anchor-miss full

# --- G19 MUTANT_FULL scopes a full-mode rerun, so only the harness group's own
# controls may set it: a copy of the harness with it on a real group's control
# stops before any control, and the real harness lists its own group
mkdir -p "$WORK/h/make"
awk '!done && /^plugin_case P[0-9]/ && g == "ascent-security" { sub(/^/, "MUTANT_FULL=T5 "); done = 1 }
  /^mutant_group / { g = $2 } { print }' "$HARN" > "$WORK/h/make/test-mutants.sh"
RC=0; env ASCENT_MUTANT_GROUP=core ASCENT_MUTANT_IDS= ASCENT_MUTANT_MODE= bash "$WORK/h/make/test-mutants.sh" --list > "$WORK/g19.out" 2>&1 </dev/null || RC=$?
if [ "$RC" -eq 2 ] && grep -q "^test-mutants: MUTANT_FULL is only for the harness group's own controls; P[0-9]*-[a-z0-9-]* in group ascent-security sets it$" "$WORK/g19.out"; then ok
else bad "G19 MUTANT_FULL on a real group's control was not refused (rc $RC): $(head -2 "$WORK/g19.out" | tr '\n' ';')"; fi
RC=0; env ASCENT_MUTANT_GROUP=harness ASCENT_MUTANT_IDS= ASCENT_MUTANT_MODE= MUTANT_FULL= bash "$HARN" --list > "$WORK/g19.out" 2>&1 </dev/null || RC=$?
if [ "$RC" -eq 0 ] && grep -q 'P359-harness-survivor' "$WORK/g19.out"; then ok
else bad "G19 the harness group's own MUTANT_FULL controls were refused (rc $RC): $(head -2 "$WORK/g19.out" | tr '\n' ';')"; fi
# Every other way of setting it is refused too: from the environment, on a line of
# its own, exported, and as a prefix followed by two spaces
RC=0; env ASCENT_MUTANT_GROUP=ascent-docs ASCENT_MUTANT_IDS= ASCENT_MUTANT_MODE= MUTANT_FULL=T5 bash "$HARN" --list > "$WORK/g19.out" 2>&1 </dev/null || RC=$?
if [ "$RC" -eq 2 ] && grep -q "^test-mutants: MUTANT_FULL is set in the environment; only the harness group's own controls may set it$" "$WORK/g19.out"; then ok
else bad "G19 MUTANT_FULL from the environment was not refused (rc $RC): $(head -2 "$WORK/g19.out" | tr '\n' ';')"; fi
full_form() {  # WANT LINE — a copy of the harness with LINE after ascent-security's group line must be refused, naming WANT
  awk -v line="$2" '{ print } /^mutant_group ascent-security$/ { print line }' "$HARN" > "$WORK/h/make/test-mutants.sh"
  RC=0; env ASCENT_MUTANT_GROUP=core ASCENT_MUTANT_IDS= ASCENT_MUTANT_MODE= MUTANT_FULL= bash "$WORK/h/make/test-mutants.sh" --list > "$WORK/g19.out" 2>&1 </dev/null || RC=$?
  if [ "$RC" -eq 2 ] && grep -q "^test-mutants: MUTANT_FULL is only for the harness group's own controls; $1 in group ascent-security sets it$" "$WORK/g19.out"; then ok
  else bad "G19 '$2' in a real group was not refused (rc $RC): $(head -2 "$WORK/g19.out" | tr '\n' ';')"; fi
}
full_form 'line [0-9]*' 'MUTANT_FULL=T11'
full_form 'line [0-9]*' 'export MUTANT_FULL=T5'
full_form 'P9999-x' 'MUTANT_FULL=T5  plugin_case P9999-x T11 f s/a/b/'

# --- G20 make/mutant-order.sh write merges a times file into the repository's order
# file, with the controls --list has, readable by everyone; a bad times file changes nothing
G20="$WORK/g20"; mkdir -p "$G20/make"; cp "$MO" "$G20/make/mutant-order.sh"
printf '#!/usr/bin/env bash\nprintf "g\\tA\\tT11\\tedit\\tf\\tfx\\t0\\t0\\ng\\tB\\tT11\\tedit\\tf\\tfx\\t0\\t0\\ng\\tC\\tT5\\tedit\\tf\\tfx\\t0\\t0\\n"\n' > "$G20/make/test-mutants.sh"
{ echo '# old header'; echo "B${T}t2"; echo "Z${T}t9"; } > "$G20/make/mutant-order.tsv"; chmod 644 "$G20/make/mutant-order.tsv"
{ printf 'seconds\tstatus\tid\tgroup\tcheck\tcached\tcaught by\n'; echo "5${T}killed${T}A${T}g${T}T11${T}${T}t1"; } > "$G20/times"
RC=0; GOT=$(bash "$G20/make/mutant-order.sh" write "$G20/times" 2>&1) || RC=$?
WANT="# Generated by make mutant-order FROM=<times file> (ADR-029): the test file that caught;# each T11 control in fast mode, run first next time. It orders tests; it never changes a verdict.;A${T}t1;B${T}t2;"
if [ "$RC" -eq 0 ] && [ "$GOT" = "make/mutant-order.tsv: 2 rows (1 replaced or added, 1 removed)" ] && [ "$(tr '\n' ';' < "$G20/make/mutant-order.tsv")" = "$WANT" ]; then ok
else bad "G20 write gave (rc $RC) '$GOT': $(tr '\t\n' ' ;' < "$G20/make/mutant-order.tsv")"; fi
case "$(ls -l "$G20/make/mutant-order.tsv")" in -rw-r--r--*) ok ;; *) bad "G20 write left the order file unreadable to others: $(ls -l "$G20/make/mutant-order.tsv" | cut -c1-10)" ;; esac
cp "$G20/make/mutant-order.tsv" "$G20/before"; head -2 "$G20/times" | cut -f1-6 > "$G20/times6"
RC=0; bash "$G20/make/mutant-order.sh" write "$G20/times6" > "$WORK/g20.out" 2>&1 || RC=$?
if [ "$RC" -eq 2 ] && cmp -s "$G20/before" "$G20/make/mutant-order.tsv" && [ "$(ls "$G20/make" | grep -c 'mutant-order\.tsv\.')" -eq 0 ]; then ok
else bad "G20 write with a six-column times file changed the order file or left a temp file (rc $RC): $(ls "$G20/make" | tr '\n' ' ')"; fi

printf "test-gate-fast: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
