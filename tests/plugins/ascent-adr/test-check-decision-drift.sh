#!/usr/bin/env bash
# Behavior test for plugins/ascent-adr/scripts/check-decision-drift.sh.
#
# The good fixture (fixtures/adr-ascent: PostgreSQL in src/, CloudFormation in
# infra/, ADR-001 superseded by ADR-003) passes DEC-C1–C3 under three constraints.
# Each check then gets negative controls: a copy broken in exactly one way fails
# that check and no other. Also covers --under, the 20-match cap, binary files, a
# superseded ADR's constraint (reported, not enforced), new and ignored files in a
# throwaway git repository inside this test's temporary folder, prototype maturity
# and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-decision-drift: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../../../plugins/ascent-adr/scripts/check-decision-drift.sh"
GOOD="$HERE/fixtures/adr-ascent"
for f in "$CHECK" "$GOOD/src/store/db.js" "$GOOD/infra/cloudformation/stack.yml" "$GOOD/docs/adr/ADR-003-use-postgresql.md"; do
  [ -f "$f" ] || { echo "FAIL  test-check-decision-drift: missing $f"; echo "test-check-decision-drift: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
# chk NAME [ARGS] — the three good constraints, unless NOC=1
chk() {
  local n="$1"; shift
  local a=(--maturity "${MATURITY:-enterprise}")
  [ "${NOC:-0}" = 1 ] || a+=(--forbid ADR-003 'mysql' --under src/ --forbid ADR-003 "from ['\"]mongodb" --require ADR-002 infra/cloudformation/)
  (cd "$WORK/$n" && PATH="$SHIM:$PATH" HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 bash "$CHECK" "${a[@]}" "$@") >"$WORK/out" 2>"$WORK/err"; RC=$?
  OUT=$(cat "$WORK/out" "$WORK/err")
}
mk() { rm -rf "${WORK:?}/$1"; cp -R "$GOOD" "$WORK/$1"; }
expect_only() {  # NAME CHECK [SEVERITY] — after chk
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|check-decision' | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-110 | tr '\n' ';')"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 *$3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1)"
  else ok; fi
}
expect_pass() { if [ "$RC" -eq 0 ]; then ok; else bad "$1 should pass: exit $RC $(printf '%s\n' "$OUT" | grep -E '^FAIL|check-decision' | head -2 | tr '\n' ';')"; fi; }
expect_rc() { if [ "$RC" -eq "$2" ]; then ok; else bad "$1: expected exit $2, got $RC: $(printf '%s\n' "$OUT" | head -2 | tr '\n' ';')"; fi; }
has() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi; }
lacks() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output must not contain: $2"; else ok; fi; }
count() { n=$(printf '%s\n' "$OUT" | grep -c "$2" || true); if [ "$n" -eq "$3" ]; then ok; else bad "$1: expected $3 lines matching $2, got $n"; fi; }
G() { (cd "$WORK/$1" && shift && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@") >/dev/null 2>&1; }

matrix() {
  mk good; chk good
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 3 ]; then ok; else bad "good fixture should pass 3: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^PASS' | tr '\n' ';')"; fi
  has good 'it checks only the constraints declared, not every way code can drift from a decision'
  NOC=1 chk good; expect_pass good-none
  has good-none 'N/A   DEC-C3'

  # DEC-C1 — forbidden patterns
  mk c1; printf "import mysql from 'mysql2';\n" > "$WORK/c1/src/store/legacy.js"; chk c1; expect_only c1 DEC-C1 Medium
  has c1 'src/store/legacy.js:1  ADR-3 forbids /mysql/'
  mk c1-mongo; printf "const { MongoClient } = require('x');\nimport m from 'mongodb';\n" > "$WORK/c1-mongo/infra/seed.js"; chk c1-mongo; expect_only c1-mongo DEC-C1 Medium
  has c1-mongo 'infra/seed.js:2'
  mk c1-under; mkdir -p "$WORK/c1-under/docs"; printf 'We left mysql in 2026.\n' > "$WORK/c1-under/docs/history.md"; chk c1-under; expect_pass c1-under
  mk c1-adrdir; printf 'mysql\n' > "$WORK/c1-adrdir/docs/adr/notes.txt"; chk c1-adrdir --forbid ADR-003 'mysql'; expect_pass c1-adrdir
  mk c1-cap; awk 'BEGIN { for (i = 1; i <= 25; i++) print "const db" i " = mysql();" }' > "$WORK/c1-cap/src/store/many.js"; chk c1-cap; expect_only c1-cap DEC-C1 Medium
  count c1-cap '^FAIL  DEC-C1' 20
  has c1-cap '5 more match(es) of /mysql/ not listed'
  mk c1-bin; printf 'mysql\000\001\002' > "$WORK/c1-bin/src/store/blob.bin"; chk c1-bin; expect_pass c1-bin

  # DEC-C2 — required paths
  mk c2; rm -rf "$WORK/c2/infra/cloudformation"; chk c2; expect_only c2 DEC-C2 Medium
  has c2 'ADR-2 requires infra/cloudformation, which does not exist'

  # DEC-C3 — constraints on ADRs that are not accepted
  mk c3-super; printf "import mysql from 'mysql2';\n" > "$WORK/c3-super/src/store/legacy.js"; NOC=1 chk c3-super --forbid ADR-001 'postgres|pg'; expect_only c3-super DEC-C3 Low
  has c3-super 'names ADR-1, which is superseded, not accepted'
  mk c3-missing; chk c3-missing --require ADR-009 README.md; expect_only c3-missing DEC-C3 Low
  has c3-missing 'names ADR-9, which is not in docs/adr'
  # The folder search is check-adrs.sh's: an empty docs/adr does not hide docs/decisions,
  # and ADR-NNN files in a shared folder are found, and only they are left out of a forbid
  mk c3-emptydir; mv "$WORK/c3-emptydir/docs/adr" "$WORK/c3-emptydir/docs/decisions"; mkdir "$WORK/c3-emptydir/docs/adr"; chk c3-emptydir; expect_pass c3-emptydir
  mk c3-shared; mv "$WORK/c3-shared/docs/adr"/ADR-*.md "$WORK/c3-shared/docs/"; rm -rf "$WORK/c3-shared/docs/adr"; chk c3-shared; expect_pass c3-shared
  printf "import m from 'mongodb';\n" > "$WORK/c3-shared/docs/notes.md"; chk c3-shared; expect_only c3-shared-other DEC-C1 Medium
  has c3-shared-other 'docs/notes.md:1'

  # git: new files are searched, ignored files are not
  mkdir -p "$WORK/home"
  mk g; G g init -q && G g add -A && G g commit -qm base
  printf 'build/\n' > "$WORK/g/.gitignore"; mkdir -p "$WORK/g/src/build"; printf 'mysql\n' > "$WORK/g/src/build/out.js"
  chk g; expect_pass g-ignored
  printf "import mysql from 'mysql2';\n" > "$WORK/g/src/store/new.js"; chk g; expect_only g-new DEC-C1 Medium

  # Maturity, input
  mk proto; printf "import mysql from 'mysql2';\n" > "$WORK/proto/src/store/legacy.js"; MATURITY=prototype chk proto; expect_pass proto
  has proto 'NOTE  DEC-C1'
  mk in1; NOC=1 chk in1 --under src/; expect_rc in1-under 2
  NOC=1 chk in1 --forbid ADR-3 '('; expect_rc in1-regex 2
  NOC=1 chk in1 --require ADR-3 ../x; expect_rc in1-path 2
  NOC=1 chk in1 --forbid three 'x'; expect_rc in1-id 2
  NOC=1 chk in1 --maturity high; expect_rc in1-maturity 2
}

realpath_of() {
  local p="$1" l
  while [ -L "$p" ]; do l=$(ls -l "$p" | sed 's/.* -> //'); case "$l" in /*) p="$l" ;; *) p="$(dirname "$p")/$l" ;; esac; done
  printf '%s' "$p"
}
AWKS="default"; SEEN=" $(realpath_of "$(command -v awk)") "
[ "${ASCENT_HOOK_TEST_ONE_AWK:-0}" = 1 ] || for a in mawk gawk original-awk nawk; do
  p=$(command -v "$a" 2>/dev/null) || continue
  r=$(realpath_of "$p")
  case "$SEEN" in *" $r "*) continue ;; esac
  SEEN="$SEEN$r "; AWKS="$AWKS $a"
done
for AWKNAME in $AWKS; do
  SHIM="$WORK/shim-$AWKNAME"; mkdir -p "$SHIM"
  if [ "$AWKNAME" != default ]; then ln -s "$(command -v "$AWKNAME")" "$SHIM/awk"; fi
  matrix
done

printf "test-check-decision-drift: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
