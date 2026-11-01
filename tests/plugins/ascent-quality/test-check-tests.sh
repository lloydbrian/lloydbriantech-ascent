#!/usr/bin/env bash
# Behavior test for plugins/ascent-quality/scripts/check-tests.sh.
#
# The good fixture (criteria with ids, core rules in JS, Python and Go, tests in JS,
# TS, Python, Go, bats and shell, a Playwright config) passes all eight checks.
# Each check then gets negative controls: a copy broken in exactly one way fails
# that check and no other. Also covers what must not fail (skip reasons, skipif,
# ids inside longer words, parent ids, focus and skip words in strings and
# comments, assertion helpers, CRLF), the trial calibration (a test that only
# checks "does not throw"), and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-tests: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-quality"
CHECK="$PLUGIN/scripts/check-tests.sh"
GOOD="$HERE/fixtures/quality-good"
for f in "$CHECK" "$GOOD/docs/criteria.md" "$GOOD/tests/unit/pricing.test.js"; do [ -f "$f" ] || { echo "test-check-tests: missing $f"; echo "test-check-tests: 0/1 PASS"; exit 1; }; done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
# run DIR [OPTIONS] — the check with the good fixture's contract values, from DIR
# (RUNOPTS replaces them).
run() {
  local d="$1"; shift
  # shellcheck disable=SC2086
  (cd "$d" && PATH="$SHIM:$PATH" bash "$CHECK" ${RUNOPTS:---criteria docs --core src/rules --helper check_close} "$@" .) >"$WORK/out" 2>"$WORK/err"; RC=$?
  OUT=$(cat "$WORK/out" "$WORK/err")
}
mk() { rm -rf "${WORK:?}/$1"; cp -R "$GOOD" "$WORK/$1"; }
q() { printf '%s' "$1" | sed 's/"/\\"/g'; }
after() { printf '{ print } index($0, "%s") && !d { print "%s"; d = 1 }' "$(q "$1")" "$(q "$2")"; }
subst() { printf '{ if (index($0, "%s")) { i = index($0, "%s"); $0 = substr($0, 1, i - 1) "%s" substr($0, i + length("%s")) } print }' "$(q "$1")" "$(q "$1")" "$(q "$2")" "$(q "$1")"; }
drop()  { printf 'index($0, "%s") { next } { print }' "$(q "$1")"; }
edit() {
  awk "$3" "$WORK/$1/$2" > "$WORK/edit.tmp"
  if cmp -s "$WORK/$1/$2" "$WORK/edit.tmp"; then bad "$1: edit of $2 changed nothing (stale anchor)"; return 1; fi
  mv "$WORK/edit.tmp" "$WORK/$1/$2"
}
# add NAME FILE BODY — writes BODY (printf %b) to a new file in the copy.
add() { mkdir -p "$(dirname "$WORK/$1/$2")"; printf '%b\n' "$3" > "$WORK/$1/$2"; }
expect_only() {  # NAME CHECK [SEVERITY] [OPTIONS...]
  local n="$1" c="$2" sev="${3:-}"; shift 3 2>/dev/null || shift $#
  run "$WORK/$n" "$@"
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $c " || true)
  if [ "$RC" -ne 1 ]; then bad "$n: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|check-tests:' | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$n: $c did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$n: expected only $c to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-90 | tr '\n' ';')"
  elif [ -n "$sev" ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $c *$sev "; then bad "$n: $c should be $sev: $(printf '%s\n' "$OUT" | grep "^FAIL  $c" | head -1)"
  else ok; fi
}
expect_pass() {  # NAME WHY [OPTIONS...]
  local n="$1" why="$2"; shift 2
  run "$WORK/$n" "$@"
  if [ "$RC" -eq 0 ]; then ok; else bad "$n should pass ($why): $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"; fi
}
has_line() {  # NAME TEXT — the last run printed a line containing TEXT
  if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi
}

matrix() {
  run "$GOOD"
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 8 ]; then ok
  else bad "good fixture should pass all 8: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^(PASS|NOTE)' | tr '\n' ';')"; fi
  if [ "$(printf '%s\n' "$OUT" | grep -c '^NOTE  QA-H2 ')" -eq 2 ]; then ok; else bad "good fixture: the two skips with a reason should be NOTE lines"; fi

  # QA-T1 — a criterion no test names
  mk t1;          edit t1 tests/integration/db.test.js "$(subst "'AC-3 loads" "'loads")" && expect_only t1 QA-T1 Medium
  has_line t1 'docs/criteria.md:6  acceptance criterion AC-3 is named by no test'
  mk t1-child;    edit t1-child docs/criteria.md "$(after 'AC-2.1:' '  - AC-2.2: a second refund cannot exceed the first.')" && expect_only t1-child QA-T1
  # QA-T2 — a test names an undefined id
  mk t2;          edit t2 tests/bats/cli.bats "$(subst 'AC-2 the' 'AC-9 the')" && expect_only t2 QA-T2 Low
  mk t2-parent;   edit t2-parent tests/bats/cli.bats "$(subst 'AC-2 the' 'AC-2.7 the')" && expect_pass t2-parent 'AC-2 defines AC-2.7'
  # QA-T3 — no ids at all
  mk t3;          expect_only t3 QA-T3 Low --id-pattern 'REQ-[0-9]+'
  # QA-T4 — a core file no test names
  mk t4;          add t4 src/rules/shipping.js 'export const fee = (kg) => kg * 2'; expect_only t4 QA-T4 Medium
  has_line t4 'src/rules/shipping.js:1  core rule source shipping is named by no test'
  mk t4-index;    add t4-index src/rules/loyalty/index.js 'export const points = (x) => x'; expect_only t4-index QA-T4
  mk t4-dirname;  add t4-dirname src/rules/loyalty/index.js 'export const points = (x) => x'; add t4-dirname tests/unit/loyalty.test.js "import { points } from '../../src/rules/loyalty'\nit('x', () => { expect(points(1)).toBe(1) })"; expect_pass t4-dirname 'index.js is named by its directory'
  mk t4-go;       add t4-go src/rules/fx/fx.go 'package fx\nfunc Rate() int { return 1 }'; expect_only t4-go QA-T4
  mk t4-go-dir;   add t4-go-dir src/rules/fx/fx.go 'package fx\nfunc Rate() int { return 1 }'; add t4-go-dir src/rules/fx/convert.go 'package fx\nfunc Convert() int { return 2 }'; add t4-go-dir src/rules/fx/fx_test.go 'package fx\nimport "testing"\nfunc TestRate(t *testing.T) { if Rate() != 1 { t.Fatal("rate") } }'; expect_pass t4-go-dir 'a _test.go file in the directory names it'
  mk t4-none;     RUNOPTS="--criteria docs --helper check_close" run "$WORK/t4-none"
  if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^N/A   QA-T4 .*no --core paths given'; then ok; else bad "t4-none: QA-T4 should be N/A without --core: $(printf '%s\n' "$OUT" | grep 'QA-T4')"; fi

  # QA-H1 — focused tests
  mk h1;          edit h1 tests/unit/pricing.test.js "$(subst "it('AC-1" "it.only('AC-1")" && expect_only h1 QA-H1 High
  mk h1-fit;      edit h1-fit tests/unit/pricing.test.js "$(subst "it('AC-1" "fit('AC-1")" && expect_only h1-fit QA-H1
  mk h1-describe; edit h1-describe tests/integration/db.test.js "$(subst "describe('price list'" "describe.only('price list'")" && expect_only h1-describe QA-H1
  mk h1-pw;       edit h1-pw tests/e2e/checkout.spec.ts "$(subst "test('AC-1" "test.only('AC-1")" && expect_only h1-pw QA-H1
  mk h1-py;       edit h1-py tests/test_discount.py "$(subst 'def test_apply():' '@pytest.mark.only\ndef test_apply():')" && expect_only h1-py QA-H1
  mk h1-text;     edit h1-text tests/unit/pricing.test.js "$(subst "it('AC-1 sums" "it('AC-1 sums, unlike it.only( in docs,")" && expect_pass h1-text '.only inside a string is text'
  mk h1-comment;  edit h1-comment tests/unit/pricing.test.js "$(after "describe('pricing'" "  // never commit it.only( or fdescribe(")" && expect_pass h1-comment '.only in a comment is text'
  # QA-H2 — skips without a reason
  mk h2;          edit h2 tests/unit/pricing.test.js "$(drop '// Pending the multi-currency')" && expect_only h2 QA-H2 Medium
  mk h2-xit;      edit h2-xit tests/unit/pricing.test.js "$(after "it.skip('converts" "  xit('rounds', () => { expect(1).toBe(1) })")" && expect_only h2-xit QA-H2
  mk h2-py;       edit h2-py tests/test_discount.py "$(subst '@pytest.mark.skip(reason="needs the payments sandbox")' '@pytest.mark.skip')" && expect_only h2-py QA-H2
  mk h2-go;       edit h2-go src/rules/tax/tax_test.go "$(after 'func TestRateZero' '	t.SkipNow()')" && expect_only h2-go QA-H2
  mk h2-go-msg;   edit h2-go-msg src/rules/tax/tax_test.go "$(after 'func TestRateZero' '	t.Skip("needs the tax tables")')" && expect_pass h2-go-msg 't.Skip with a message gives its reason'
  mk h2-bats;     edit h2-bats tests/bats/cli.bats "$(after '@test "AC-2' '  skip')" && expect_only h2-bats QA-H2
  mk h2-pw-cond;  edit h2-pw-cond tests/e2e/checkout.spec.ts "$(after "async ({ page })" "  test.skip(isMobile, 'no checkout on mobile yet')")" && expect_pass h2-pw-cond 'a conditional skip with a message'
  # QA-H3 — tests that assert nothing
  mk h3;          edit h3 tests/unit/pricing.test.js "$(after "it.skip('converts" "  it('computes', () => {\n    total([])\n  })")" && expect_only h3 QA-H3 Medium
  has_line h3 "test 'computes' has no assertion"
  mk h3-py;       edit h3-py tests/test_discount.py "$(subst 'assert discount.apply(10, 10) == 9.0' 'discount.apply(10, 10)')" && expect_only h3-py QA-H3
  mk h3-helper;   RUNOPTS="--criteria docs --core src/rules" expect_only h3-helper QA-H3 Medium
  has_line h3-helper 'tests/test_discount.py:17  test test_apply_rounds has no assertion' 
  mk h3-go;       edit h3-go src/rules/tax/tax_test.go "$(subst 'checkRate(t, 0, 0)' '_ = Rate(0)')" && expect_only h3-go QA-H3
  mk h3-bats;     edit h3-bats tests/bats/cli.bats "$(drop '[ "$')" && expect_only h3-bats QA-H3
  mk h3-nested;   edit h3-nested tests/integration/db.test.js "$(subst '    expect(client).toBeDefined()' '    await client.connect()')" && expect_only h3-nested QA-H3
  # A block ends where its language says, so an assertion in code after the last
  # test is not that test's.
  mk h3-end-js;   add h3-end-js tests/unit/after.test.js "it('runs', () => {\n  total([])\n})\nfunction helper() { expect(1).toBe(1) }"; expect_only h3-end-js QA-H3
  mk h3-end-go;   add h3-end-go src/rules/tax/end_test.go 'package tax\nimport "testing"\nfunc TestRuns(t *testing.T) { _ = Rate(1) }\nfunc helperEnd(t *testing.T) { t.Fatal("x") }'; expect_only h3-end-go QA-H3
  mk h3-end-py;   add h3-end-py tests/test_after.py 'def test_runs():\n    print(1)\n\ndef helper():\n    assert True'; expect_only h3-end-py QA-H3
  mk h3-end-bats; add h3-end-bats tests/bats/after.bats '@test "runs" {\n  run true\n}\n\nhelper() {\n  false\n}'; expect_only h3-end-bats QA-H3
  # A code line between a comment and a skip: the comment is not the skip's reason.
  mk h2-comment-far; add h2-comment-far tests/unit/reason.test.js "// pending the tax tables\nconst rate = 1\nit.skip('later', () => { expect(rate).toBe(1) })"; expect_only h2-comment-far QA-H2
  # Review fixes (v0.4.11): Black's multi-line signature, triple-quoted strings
  mk h3-py-sig;   add h3-py-sig tests/test_sig.py 'def test_sig(\n    client,\n    db,\n):\n    assert client'; expect_pass h3-py-sig 'a signature over several lines is still the test'
  mk h3-py-doc;   add h3-py-doc tests/test_doc.py 'def test_doc():\n    expected = """\nline one\n"""\n    assert render() == expected'; expect_pass h3-py-doc 'a column-0 line inside a triple-quoted string does not end the test'
  mk h3-py-docassert; add h3-py-docassert tests/test_docassert.py 'def test_docassert():\n    """\n    We assert the total later.\n    """\n    total()'; expect_only h3-py-docassert QA-H3
  # Retries passed to the code under test are not the runner retrying
  mk h4-option;   add h4-option tests/unit/retry.test.js "it('retries', async () => { await withRetry(fn, { retries: 3 }); expect(calls).toBe(3) })"; expect_pass h4-option 'an option of the code under test'
  mk h4-configure; add h4-configure tests/e2e/flaky.spec.ts "test.describe.configure({ retries: 2 })\ntest('x', async () => { expect(1).toBe(1) })"; expect_only h4-configure QA-H4
  # A dotted core file name, named through an import path
  mk t4-dotted;   add t4-dotted src/rules/user.service.ts 'export const find = () => 1'; add t4-dotted tests/unit/users.test.ts "import { find } from '../../src/rules/user.service'\nit('finds', () => { expect(find()).toBe(1) })"; expect_pass t4-dotted 'the import path names user.service'
  # A repository under a directory named test/, given by absolute paths
  mkdir -p "$WORK/test"; rm -rf "$WORK/test/repo"; cp -R "$GOOD" "$WORK/test/repo"
  (bash "$CHECK" --criteria "$WORK/test/repo/docs" --core "$WORK/test/repo/src/rules" --helper check_close "$WORK/test/repo") >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out")
  if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^PASS  QA-T4 .*(3 checked)'; then ok; else bad "ancestor test/: core files should be checked, got exit $RC: $(printf '%s\n' "$OUT" | grep 'QA-T4\|^FAIL' | head -2 | tr '\n' ';')"; fi
  # A --core value that starts with - is a directory, never a find expression
  mk core-dash;   add core-dash -print/rate.js 'export const rate = () => 1'; RUNOPTS="--criteria docs --core -print --helper check_close" run "$WORK/core-dash"
  if [ "$RC" -eq 1 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL ')" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL  QA-T4   Medium -print/rate.js:1 '; then ok; else bad "core-dash: --core -print should read that directory only: exit $RC $(printf '%s\n' "$OUT" | grep '^FAIL\|QA-T4' | head -2 | tr '\n' ';')"; fi
  mk core-empty;  mkdir -p "$WORK/core-empty/src/empty"; RUNOPTS="--criteria docs --core src/empty --helper check_close" run "$WORK/core-empty"
  if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^N/A   QA-T4 .*no source files under the --core paths'; then ok; else bad "core-empty: QA-T4 should be N/A with no source under --core: $(printf '%s\n' "$OUT" | grep 'QA-T4')"; fi
  # QA-H4 — retries
  mk h4;          edit h4 playwright.config.ts "$(subst 'retries: 0' 'retries: process.env.CI ? 2 : 0')" && expect_only h4 QA-H4 Low
  mk h4-jest;     edit h4-jest tests/unit/pricing.test.js "$(after "from '../../src/rules/pricing.js'" "jest.retryTimes(3)")" && expect_only h4-jest QA-H4
  mk h4-py;       edit h4-py tests/test_discount.py "$(subst 'def test_apply():' '@pytest.mark.flaky(reruns=2)\ndef test_apply():')" && expect_only h4-py QA-H4
  mk h4-ci;       edit h4-ci .github/workflows/ci.yml "$(subst 'run: make test' 'run: pytest --reruns 3')" && expect_only h4-ci QA-H4
  mk h4-toml;     edit h4-toml pyproject.toml "$(subst 'addopts = "-q"' 'addopts = "-q --reruns 2"')" && expect_only h4-toml QA-H4

  # What must not fail.
  mk ids-word;    edit ids-word docs/criteria.md "$(after '# Checkout' 'Unrelated: XAC-12 and AC-5a are not criterion ids.')" && expect_pass ids-word 'ids inside longer words are not ids'
  mk ids-fence;   printf '\n```\nAC-77: an example inside a code fence\n```\n' >> "$WORK/ids-fence/docs/criteria.md"; expect_pass ids-fence 'ids in a code fence are examples'
  mk ids-after;   printf '\n```\nAC-77: an example\n```\n\n- AC-78: a real criterion after the fence\n' >> "$WORK/ids-after/docs/criteria.md"; expect_only ids-after QA-T1
  has_line ids-after 'acceptance criterion AC-78 is named by no test' 
  mk crlf;        for f in tests/unit/pricing.test.js tests/test_discount.py docs/criteria.md; do awk '{ printf "%s\r\n", $0 }' "$GOOD/$f" > "$WORK/crlf/$f"; done; expect_pass crlf 'CRLF line endings'
  mk template;    edit template tests/unit/pricing.test.js "$(after "it.skip('converts" "  it('renders', () => {\n    const html = \`<p>(\n    </p>\`\n    expect(html).toContain('p')\n  })")" && expect_pass template 'a multi-line template literal with a parenthesis'
  mk fixtures;    add fixtures tests/fixtures/broken.test.js "it.only('x', () => {})"; expect_pass fixtures 'files under fixtures/ are test inputs, not tests'
  mk nomsg;       edit nomsg tests/test_discount.py "$(after 'def test_apply_rounds' '    discount.apply(1, 1)  # does not throw')" && expect_pass nomsg 'a comment does not hide the helper call'

  # Trial calibration (homelab-toolkit): a test that only checks "does not throw".
  mk no-throw;    add no-throw tests/test_common.py 'from src.rules import discount\n\n\ndef test_apply_accepts_zero():\n    discount.apply(0, 0)'; expect_only no-throw QA-H3 Medium

  # Bad input and help.
  run "$GOOD" --bogus; [ "$RC" -eq 2 ] && ok || bad "unknown option should exit 2, got $RC"
  run "$GOOD" --id-pattern 'x*'; [ "$RC" -eq 2 ] && ok || bad "an id pattern matching the empty string should exit 2, got $RC"
  # The guard reads the pattern as the check does: \\? is an optional backslash.
  run "$GOOD" --id-pattern '\\?'; [ "$RC" -eq 2 ] && ok || bad "the guard should read the pattern as the check does: \\\\? should exit 2, got $RC"
  run "$GOOD" --helper 'a;b'; [ "$RC" -eq 2 ] && ok || bad "a helper that is not a name should exit 2, got $RC"
  (cd "$GOOD" && PATH="$SHIM:$PATH" bash "$CHECK" ./does-not-exist) >/dev/null 2>&1; [ $? -eq 2 ] && ok || bad "a missing path should exit 2"
  (cd "$GOOD" && PATH="$SHIM:$PATH" bash "$CHECK" src/rules/pricing.js) >/dev/null 2>&1; [ $? -eq 2 ] && ok || bad "a named source file is not a test file and should exit 2"
  OUT=$(PATH="$SHIM:$PATH" bash "$CHECK" --help 2>&1); if printf '%s\n' "$OUT" | grep -q '^Usage: check-tests.sh'; then ok; else bad "--help should print usage"; fi
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

printf "test-check-tests: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
