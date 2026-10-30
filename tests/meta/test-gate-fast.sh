#!/usr/bin/env bash
# Behavior test for the fast mode of make/test-plugins.sh (gate check T14, ADR-018).
#
# Builds fixture repositories with one plugin, fx, whose behavior tests pass, fail,
# hang or misreport on purpose, and runs the gate's T11 on them in fast mode
# (ASCENT_T11_FAST=1) and in full mode. Checks that fast mode stops a test at its
# first FAIL line and stops its children, stops T11 at the first failing test,
# runs first the tests that name ASCENT_T11_FIRST, gives each test its own TMPDIR,
# and reaches the same verdict as full mode; that a test printing a FAIL line and
# exiting 0 fails in both modes; that ASCENT_ONLY runs one section and rejects
# an unknown label; and that T7 names each failing file and its reason, or shows
# the checker's last lines when it gave none.
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
# own ASCENT_T11_FIRST and ASCENT_T11_ONLY set, which must not reach the fixtures.
gate() {
  local mode=$1; shift
  OUT="$WORK/out"; RC=0
  env ASCENT_T11_FIRST= ASCENT_T11_ONLY= ASCENT_ONLY=T11 ASCENT_T11_FAST=$([ "$mode" = fast ] && echo 1 || echo 0) "$@" \
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
if ! printf '%s\n' "$under" | grep -q 'skills/good/'; then ok; else bad "G10 T7 listed a file that passed: $(printf '%s' "$under" | tr '\n' ';')"; fi

# --- G11 when the checker fails without a reason, T7 shows its last three lines
printf '#!/usr/bin/env bash\nprintf "one\\ntwo\\nthree\\nfour\\n"; exit 3\n' > "$F/make/qa-skill-frontmatter.sh"
RC=0; ASCENT_ONLY=T7 bash "$GATE" "$F" </dev/null >"$WORK/out" 2>&1 || RC=$?
under=$(awk '/^FAIL  test-plugins: T7 / { on = 1; next } on && /^      / { print; next } { on = 0 }' "$WORK/out" | tr '\n' ';')
if [ "$RC" -ne 0 ] && grep -q '^FAIL  test-plugins: T7 .*(rc 3)$' "$WORK/out" && [ "$under" = "      two;      three;      four;" ]; then ok
else bad "G11 T7 did not show the checker's last lines and status (rc $RC): $under"; fi

printf "test-gate-fast: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
