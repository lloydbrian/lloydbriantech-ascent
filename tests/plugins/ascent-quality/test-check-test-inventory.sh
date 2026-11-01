#!/usr/bin/env bash
# Behavior test for plugins/ascent-quality/scripts/check-test-inventory.sh.
#
# The good fixture (unit, integration, contract and e2e tests; a workflow that runs
# them through make, npx and a package script; a database and an HTTP client each
# reached by a test) passes all five checks. Each check then gets negative
# controls: a copy broken in exactly one way fails that check and no other. Also
# covers how tests are typed, CI steps followed through make and package scripts,
# test doubles, the trial calibration (make as the operator vocabulary, a step
# name that mentions a runner), and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-test-inventory: N/N PASS" last (make/test-plugins.sh T11
# requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-quality"
CHECK="$PLUGIN/scripts/check-test-inventory.sh"
GOOD="$HERE/fixtures/quality-good"
for f in "$CHECK" "$GOOD/.github/workflows/ci.yml" "$GOOD/Makefile"; do [ -f "$f" ] || { echo "test-check-test-inventory: missing $f"; echo "test-check-test-inventory: 0/1 PASS"; exit 1; }; done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
# run DIR [OPTIONS] — the check with every type required, from DIR (TYPES replaces
# the list).
run() {
  local d="$1"; shift
  (cd "$d" && PATH="$SHIM:$PATH" bash "$CHECK" --types "${TYPES:-unit,integration,contract,e2e}" "$@" .) >"$WORK/out" 2>"$WORK/err"; RC=$?
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
add() { mkdir -p "$(dirname "$WORK/$1/$2")"; printf '%b\n' "$3" > "$WORK/$1/$2"; }
expect_only() {  # NAME CHECK [SEVERITY]
  run "$WORK/$1"
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|check-test-inventory:' | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-90 | tr '\n' ';')"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 *$3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1)"
  else ok; fi
}
expect_pass() {  # NAME WHY
  run "$WORK/$1"
  if [ "$RC" -eq 0 ]; then ok; else bad "$1 should pass ($2): $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"; fi
}
has_line() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi; }

matrix() {
  run "$GOOD"
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 5 ]; then ok
  else bad "good fixture should pass all 5: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^PASS' | tr '\n' ';')"; fi
  has_line good 'check-test-inventory: 8 test file(s) (unit 5, integration 1, contract 1, e2e 1)'

  # QA-I1 — a required type with no tests
  mk i1;          rm -rf "$WORK/i1/tests/contract"; edit i1 .github/workflows/ci.yml "$(drop 'npm run test:contract')" && expect_only i1 QA-I1 Medium
  has_line i1 'no contract tests, and the contract requires them'
  mk i1-e2e;      rm -rf "$WORK/i1-e2e/tests/e2e"; TYPES=unit,integration,contract expect_pass i1-e2e 'e2e is not required'
  mk i1-int;      rm -rf "$WORK/i1-int/tests/integration"; add i1-int tests/unit/pool.test.js "import pg from 'pg'\nit('pool', () => { expect(pg).toBeDefined() })"; expect_only i1-int QA-I1
  # QA-I2 — no CI, or CI that runs no tests
  mk i2;          rm -rf "$WORK/i2/.github"; expect_only i2 QA-I2 Medium
  has_line i2 'no CI configuration, so no test runs on a change'
  mk i2-norun;    rm -rf "$WORK/i2-norun/tests/e2e" "$WORK/i2-norun/tests/contract"; printf 'name: ci\non: [push]\njobs:\n  lint:\n    runs-on: ubuntu-24.04\n    steps:\n      - name: Run the tests later\n        run: make lint\n' > "$WORK/i2-norun/.github/workflows/ci.yml"; printf 'lint: ## Lint\n\tshellcheck *.sh\n' >> "$WORK/i2-norun/Makefile"
  TYPES=unit,integration expect_only i2-norun QA-I2
  has_line i2-norun '.github/workflows/ci.yml:1  no CI step runs the tests'
  # One CI step each, no e2e or contract tests: the step's own words name no runner,
  # so only following the recipe or the script finds the tests.
  mk i2-make;     rm -rf "$WORK/i2-make/tests/e2e" "$WORK/i2-make/tests/contract"; printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: make everything\n' > "$WORK/i2-make/.github/workflows/ci.yml"; printf 'everything: build\n\t$(MAKE) gather\nbuild:\n\t@true\ngather:\n\tpytest\n' >> "$WORK/i2-make/Makefile"; TYPES=unit,integration expect_pass i2-make 'make everything runs pytest two levels down'
  mk i2-npm;      rm -rf "$WORK/i2-npm/tests/e2e" "$WORK/i2-npm/tests/contract"; printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: npm run verify\n' > "$WORK/i2-npm/.github/workflows/ci.yml"; edit i2-npm package.json "$(after '"scripts": {' '    "verify": "vitest run",')" && TYPES=unit,integration expect_pass i2-npm 'a package script that runs vitest'
  mk i2-comment;  rm -rf "$WORK/i2-comment/tests/e2e" "$WORK/i2-comment/tests/contract"; printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-24.04\n    steps:\n      # - run: npm test\n      - run: make lint\n' > "$WORK/i2-comment/.github/workflows/ci.yml"; printf 'lint: ## Lint\n\tshellcheck *.sh\n' >> "$WORK/i2-comment/Makefile"
  TYPES=unit,integration expect_only i2-comment QA-I2
  # QA-I3 — e2e or contract tests no CI step runs
  mk i3;          edit i3 .github/workflows/ci.yml "$(drop 'npx playwright test')" && expect_only i3 QA-I3 Low
  has_line i3 'tests/e2e/checkout.spec.ts:1  end-to-end tests exist (1 file(s)) but no CI step runs them'
  mk i3-contract; edit i3-contract .github/workflows/ci.yml "$(drop 'npm run test:contract')" && edit i3-contract package.json "$(drop '"test:contract"')" && expect_only i3-contract QA-I3
  mk i3-script;   edit i3-script .github/workflows/ci.yml "$(subst 'npx playwright test' 'npm run e2e')" && edit i3-script package.json "$(after '"scripts": {' '    "e2e": "playwright test",')" && expect_pass i3-script 'an npm script that runs Playwright'
  # QA-I4 — a boundary no test reaches
  mk i4;          edit i4 tests/integration/db.test.js "$(drop "import pg from 'pg'")" && edit i4 tests/integration/db.test.js "$(drop 'testcontainers')" && edit i4 tests/integration/db.test.js "$(subst 'new pg.Client' 'new Client')" && edit i4 tests/integration/db.test.js "$(subst 'GenericContainer' 'Container')" && expect_only i4 QA-I4 Low
  has_line i4 'src/db.js:1  the db client pg is used here, but no test names it or uses a test double for it (heuristic)'
  mk i4-py;       edit i4-py tests/test_discount.py "$(drop 'import responses')" && edit i4-py tests/test_discount.py "$(drop 'responses.')" && expect_only i4-py QA-I4
  mk i4-double;   edit i4-double tests/test_discount.py "$(drop 'import responses')" && edit i4-double tests/test_discount.py "$(subst '@responses.activate' '@pytest.mark.usefixtures("requests_mock")')" && edit i4-double tests/test_discount.py "$(drop 'responses.post')" && expect_pass i4-double 'requests_mock is a double for requests'
  mk i4-go;       add i4-go src/client/client.go 'package client\nimport "net/http"\nfunc Get(u string) (*http.Response, error) { return http.Get(u) }'; expect_only i4-go QA-I4
  mk i4-go-db;    add i4-go-db src/store/store.go 'package store\nimport (\n\t"database/sql"\n\t_ "github.com/lib/pq"\n)\nvar DB *sql.DB'; expect_only i4-go-db QA-I4
  mk i4-scoped;   add i4-scoped src/queue.js "import { SQSClient } from '@aws-sdk/client-sqs'"; edit i4-scoped tests/integration/db.test.js "$(subst "from 'testcontainers'" "from 'pg-mem'")" && expect_only i4-scoped QA-I4
  has_line i4-scoped 'the queue client @aws-sdk/client-sqs is used here'
  mk i4-memory;   add i4-memory src/cache.py 'import sqlalchemy'; add i4-memory tests/test_cache.py 'def test_cache():\n    url = "sqlite:///:memory:"\n    assert url'; expect_pass i4-memory 'an in-memory SQLite is a database double'
  # QA-I5 — package.json test script
  mk i5;          edit i5 package.json "$(subst '"vitest run tests/unit tests/integration"' '"echo \\"Error: no test specified\\" && exit 1"')" && edit i5 Makefile "$(subst 'npm test' 'npx vitest run tests/unit tests/integration')" && expect_only i5 QA-I5 Low
  has_line i5 "package.json:5  the test script is npm's placeholder"
  mk i5-none;     edit i5-none package.json "$(drop '"test": ')" && edit i5-none Makefile "$(subst 'test: ## Run' 'check: ## Run')" && edit i5-none .github/workflows/ci.yml "$(subst 'make test' 'make check')" && expect_only i5-none QA-I5
  # Trial calibration (ground-turf-truth): make is the operator vocabulary.
  mk i5-make;     edit i5-make package.json "$(drop '"test": ')" && expect_pass i5-make 'a make test target stands in for the npm script'
  # Review fixes (v0.4.11)
  # A prerequisite cycle ends at the depth limit, not in a crash.
  mk i2-cycle;    printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: make loop-a\n      - run: npx playwright test\n      - run: npm run test:contract\n      - run: make test\n' > "$WORK/i2-cycle/.github/workflows/ci.yml"; printf 'loop-a: loop-b\nloop-b: loop-a\n' >> "$WORK/i2-cycle/Makefile"; expect_pass i2-cycle 'a make prerequisite cycle'
  # Installing a runner is not running it.
  mk i2-install;  rm -rf "$WORK/i2-install/tests/e2e" "$WORK/i2-install/tests/contract"; printf 'name: ci\non: [push]\njobs:\n  lint:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: pip install pytest ruff\n      - run: npm i -D jest\n      - run: ruff check .\n' > "$WORK/i2-install/.github/workflows/ci.yml"
  TYPES=unit,integration expect_only i2-install QA-I2
  mk i2-install-run; rm -rf "$WORK/i2-install-run/tests/e2e" "$WORK/i2-install-run/tests/contract"; printf 'name: ci\non: [push]\njobs:\n  t:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: pip install pytest && pytest -q\n' > "$WORK/i2-install-run/.github/workflows/ci.yml"
  TYPES=unit,integration expect_pass i2-install-run 'pytest runs after the install'
  # contract and pact are whole words of a file name.
  mk type-impact; add type-impact tests/unit/impact.test.js "it('impact', () => { expect(1).toBe(1) })"; run "$WORK/type-impact"; has_line type-impact '(unit 6, integration 1, contract 1, e2e 1)'
  # A package.json on one line.
  mk i5-oneline;  printf '{"name":"a","scripts":{"test":"echo \\"Error: no test specified\\" && exit 1"}}\n' > "$WORK/i5-oneline/package.json"; edit i5-oneline Makefile "$(subst 'npm test' 'npx vitest run tests/unit tests/integration')" && expect_only i5-oneline QA-I5
  has_line i5-oneline 'package.json:1  the test script is npm'
  # A repository under a directory named test/, given by an absolute path.
  mkdir -p "$WORK/test"; rm -rf "$WORK/test/repo"; cp -R "$GOOD" "$WORK/test/repo"
  (bash "$CHECK" --types unit,integration,contract,e2e "$WORK/test/repo") >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out")
  if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q 'test file(s) (unit 5, integration 1, contract 1, e2e 1), [1-9][0-9]* source file(s)'; then ok; else bad "ancestor test/: source files should be read: exit $RC $(printf '%s\n' "$OUT" | tail -1)"; fi

  # Typing and parsing.
  mk type-name;   mv "$WORK/type-name/tests/integration/db.test.js" "$WORK/type-name/tests/db.integration.test.js"; rmdir "$WORK/type-name/tests/integration"; expect_pass type-name 'a name with integration is an integration test'
  mk type-import; mv "$WORK/type-import/tests/e2e/checkout.spec.ts" "$WORK/type-import/tests/checkout.spec.ts"; rmdir "$WORK/type-import/tests/e2e"; expect_pass type-import 'a test that imports Playwright is end-to-end'
  mk type-mark;   rm -rf "$WORK/type-mark/tests/integration"; add type-mark tests/unit/pool.test.js "import pg from 'pg'\nit('pool', () => { expect(pg).toBeDefined() })"; add type-mark tests/test_orders.py 'import pytest\n\n@pytest.mark.integration\ndef test_orders():\n    assert True'; expect_pass type-mark '@pytest.mark.integration types the file'
  mk type-gotag;  rm -rf "$WORK/type-gotag/tests/integration"; add type-gotag tests/unit/pool.test.js "import pg from 'pg'\nit('pool', () => { expect(pg).toBeDefined() })"; add type-gotag src/rules/tax/db_test.go '//go:build integration\n\npackage tax\n\nimport "testing"\n\nfunc TestDB(t *testing.T) { t.Log("db") }'; expect_pass type-gotag 'a Go integration build tag types the file'
  mk helper-dir;  add helper-dir tests/helpers/setup.js 'export function setup() { return 1 }'; run "$WORK/helper-dir"; has_line helper-dir 'check-test-inventory: 8 test file(s)'
  mk name-line;   edit name-line .github/workflows/ci.yml "$(subst 'run: npx playwright test' 'run: echo skipped')" && expect_only name-line QA-I3
  mk crlf;        awk '{ printf "%s\r\n", $0 }' "$GOOD/.github/workflows/ci.yml" > "$WORK/crlf/.github/workflows/ci.yml"; awk '{ printf "%s\r\n", $0 }' "$GOOD/package.json" > "$WORK/crlf/package.json"; expect_pass crlf 'CRLF line endings'

  # Bad input and help.
  run "$GOOD" --bogus; [ "$RC" -eq 2 ] && ok || bad "unknown option should exit 2, got $RC"
  TYPES=unit,smoke run "$GOOD"; [ "$RC" -eq 2 ] && ok || bad "an unknown test type should exit 2, got $RC"
  (cd "$GOOD" && PATH="$SHIM:$PATH" bash "$CHECK" ./does-not-exist) >/dev/null 2>&1; [ $? -eq 2 ] && ok || bad "a missing path should exit 2"
  (cd "$GOOD" && PATH="$SHIM:$PATH" bash "$CHECK" docs/criteria.md) >/dev/null 2>&1; [ $? -eq 2 ] && ok || bad "a named Markdown file is not an inventory input and should exit 2"
  OUT=$(PATH="$SHIM:$PATH" bash "$CHECK" --help 2>&1); if printf '%s\n' "$OUT" | grep -q '^Usage: check-test-inventory.sh'; then ok; else bad "--help should print usage"; fi
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

printf "test-check-test-inventory: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
