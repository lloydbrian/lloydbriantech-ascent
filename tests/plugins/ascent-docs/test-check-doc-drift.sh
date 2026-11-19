#!/usr/bin/env bash
# Behavior test for plugins/ascent-docs/scripts/check-doc-drift.sh.
#
# The good fixture (fixtures/docs-good: documents that name existing paths, make
# targets from the Makefile and a file it includes, package scripts, environment
# variables from .env.example and the code, the version in package.json and a
# Node.js range the .nvmrc pin satisfies) passes DOC-R1–R6. Each check then gets
# negative controls: a copy broken in exactly one way fails that check and no
# other. Also covers what is never checked (code fences in other languages, prose,
# changelogs, ADR folders), --ignore, --ignore-env, --version-file, Python pins,
# prototype maturity and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-doc-drift: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.
set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../../../plugins/ascent-docs/scripts/check-doc-drift.sh"
GOOD="$HERE/fixtures/docs-good"
for f in "$CHECK" "$GOOD/README.md" "$GOOD/docs/guide.md" "$GOOD/Makefile" "$GOOD/package.json"; do
  [ -f "$f" ] || { echo "FAIL  test-check-doc-drift: missing $f"; echo "test-check-doc-drift: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
chk() {  # NAME [ARGS] — no git unless GIT=1
  local n="$1"; shift
  local a=(--maturity "${MATURITY:-enterprise}")
  [ "${GIT:-0}" = 1 ] || a+=(--no-git)
  (cd "$WORK/$n" && PATH="$SHIM:$PATH" HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 bash "$CHECK" "${a[@]}" "$@") >"$WORK/out" 2>"$WORK/err"; RC=$?
  OUT=$(cat "$WORK/out" "$WORK/err")
}
mk() { rm -rf "${WORK:?}/$1"; cp -R "$GOOD" "$WORK/$1"; }
q() { printf '%s' "$1" | sed 's/"/\\"/g'; }
subst() { printf '{ if (index($0, "%s")) { i = index($0, "%s"); $0 = substr($0, 1, i - 1) "%s" substr($0, i + length("%s")) } print }' "$(q "$1")" "$(q "$1")" "$(q "$2")" "$(q "$1")"; }
drop()  { printf 'index($0, "%s") { next } { print }' "$(q "$1")"; }
edit() {  # COPY FILE AWK
  awk "$3" "$WORK/$1/$2" > "$WORK/edit.tmp" || { bad "$1: the edit's awk failed"; return 1; }
  if cmp -s "$WORK/$1/$2" "$WORK/edit.tmp"; then bad "$1: edit changed nothing (stale anchor)"; return 1; fi
  mv "$WORK/edit.tmp" "$WORK/$1/$2"
}
expect_only() {  # NAME CHECK [SEVERITY]
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|test-check-doc-drift' | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-110 | tr '\n' ';')"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 *$3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1)"
  else ok; fi
}
expect_pass() { if [ "$RC" -eq 0 ]; then ok; else bad "$1 should pass: exit $RC $(printf '%s\n' "$OUT" | grep -E '^FAIL|test-check-doc-drift:' | head -2 | tr '\n' ';')"; fi; }
expect_rc() { if [ "$RC" -eq "$2" ]; then ok; else bad "$1: expected exit $2, got $RC: $(printf '%s\n' "$OUT" | head -2 | tr '\n' ';')"; fi; }
has() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi; }
lacks() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output must not contain: $2"; else ok; fi; }
G() { (cd "$WORK/$1" && shift && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@") >/dev/null 2>&1; }
head_of() { (cd "$WORK/$1" && HOME="$WORK/home" GIT_CONFIG_NOSYSTEM=1 git log -1 --format=%h); }

matrix() {
  mk good; chk good
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 6 ]; then ok; else bad "good fixture should pass 6: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^PASS' | tr '\n' ';')"; fi
  has good 'not that their descriptions are right'

  # DOC-R1 — paths
  mk r1; edit r1 README.md "$(subst '`src/app.js`' '`src/server.js`')" && chk r1 && expect_only r1 DOC-R1 Medium
  has r1 'README.md:23  names src/server.js, which does not exist (its folder src/ does)'
  mk r1-folder; printf '\nSee `lib/helpers.js` and `src/app.js:3`.\n' >> "$WORK/r1-folder/docs/guide.md"; chk r1-folder; expect_pass r1-folder
  mk r1-rel; printf '\nAlso `reference/config.md`.\n' >> "$WORK/r1-rel/docs/guide.md"; chk r1-rel; expect_pass r1-rel
  mk r1-ph; printf '\nUse `src/<name>.js` or `src/*.js`.\n' >> "$WORK/r1-ph/docs/guide.md"; chk r1-ph; expect_pass r1-ph
  mk r1-n; printf '\nEach phase has `docs/phase-N-plan.md`, numbered.\n' >> "$WORK/r1-n/docs/guide.md"; chk r1-n; expect_pass r1-n
  mk r1-example; printf '\nAdd `src/x.js` or `src/whatever.sh`.\n' >> "$WORK/r1-example/docs/guide.md"; chk r1-example; expect_pass r1-example
  mk r1-ign; edit r1-ign README.md "$(subst '`src/app.js`' '`src/server.js`')" && chk r1-ign --ignore src/server.js && expect_pass r1-ign
  mk r1-adr; chk r1-adr --path docs; expect_pass r1-adr
  mk r1-log; printf '# Changelog\n\n- Removed `src/old.js`.\n' > "$WORK/r1-log/docs/CHANGELOG.md"; printf '\n[Changes](CHANGELOG.md)\n' >> "$WORK/r1-log/docs/guide.md"; chk r1-log; expect_pass r1-log

  # DOC-R2 — make targets
  mk r2; edit r2 docs/guide.md "$(subst 'run `make build`' 'run `make bundle`')" && chk r2 && expect_only r2 DOC-R2 Medium
  has r2 'make bundle: the Makefile has no target bundle'
  mk r2-fence; printf '\n```sh\n$ make deploy ENV=prod\n```\n' >> "$WORK/r2-fence/docs/guide.md"; chk r2-fence; expect_only r2-fence DOC-R2 Medium
  mk r2-chain; printf '\nRun `make dev && make release`.\n' >> "$WORK/r2-chain/docs/guide.md"; chk r2-chain; expect_only r2-chain DOC-R2 Medium
  has r2-chain 'make release: the Makefile has no target release'
  lacks r2-chain 'no target make'
  mk r2-include; printf '\nRun `make test`.\n' >> "$WORK/r2-include/docs/guide.md"; chk r2-include; expect_pass r2-include
  mk r2-prose; printf '\n```text\nmake sure the tests pass\n```\n\nWe make releases weekly.\n```python\nmake(widget)\n```\n\n```sh\necho make nothing\n```\n' >> "$WORK/r2-prose/docs/guide.md"; chk r2-prose; expect_pass r2-prose
  mk r2-vars; printf '\nRun `make build VERBOSE=1 -j4` or `make <target>`.\n' >> "$WORK/r2-vars/docs/guide.md"; chk r2-vars; expect_pass r2-vars
  mk r2-aligned; printf '\n```\nmake build        Build the bundle\n```\n' >> "$WORK/r2-aligned/docs/guide.md"; chk r2-aligned; expect_pass r2-aligned
  mk r2-dir; printf '\n```sh\nmake -C frontend bundle\nmake -f other.mk deploy\nmake -j 4 build\n```\n' >> "$WORK/r2-dir/docs/guide.md"; chk r2-dir; expect_pass r2-dir
  mk r2-optarg; printf '\n```sh\nmake -o build test\nmake -W src/app.js release\n```\n' >> "$WORK/r2-optarg/docs/guide.md"; chk r2-optarg; expect_only r2-optarg DOC-R2 Medium
  has r2-optarg 'make release: the Makefile has no target release'
  lacks r2-optarg 'no target src/app.js'
  mk r2-wild; edit r2-wild Makefile "$(subst 'include make/dev.mk' 'include $(wildcard make/*.mk)')" && printf '\nRun `make test`.\n' >> "$WORK/r2-wild/docs/guide.md" && chk r2-wild && expect_pass r2-wild
  mk r2-gnu; printf 'only:\n\t@true\n' > "$WORK/r2-gnu/GNUmakefile"; chk r2-gnu; expect_only r2-gnu DOC-R2 Medium
  mk r2-nomake; rm "$WORK/r2-nomake/Makefile"; chk r2-nomake; expect_pass r2-nomake
  has r2-nomake 'N/A   DOC-R2  make targets exist (no Makefile)'
  mk r2-ign; edit r2-ign docs/guide.md "$(subst 'run `make build`' 'run `make bundle`')" && chk r2-ign --ignore bundle && expect_pass r2-ign

  # DOC-R3 — package scripts
  mk r3; edit r3 CONTRIBUTING.md "$(subst 'npm run lint' 'npm run format')" && chk r3 && expect_only r3 DOC-R3 Medium
  has r3 'npm run format: package.json has no script format'
  mk r3-pnpm; printf '\n```bash\npnpm run e2e\n```\n' >> "$WORK/r3-pnpm/docs/guide.md"; chk r3-pnpm; expect_only r3-pnpm DOC-R3 Medium
  mk r3-builtin; printf '\nRun `npm install` and `npm test`.\n' >> "$WORK/r3-builtin/docs/guide.md"; chk r3-builtin; expect_pass r3-builtin
  mk r3-brace; printf '{\n  "name": "catalog-service",\n  "version": "1.4.0",\n  "scripts": {\n    "format": "prettier --write \\"**/*.{js,md}\\"",\n    "build": "node build.js",\n    "test": "node --test",\n    "lint": "eslint ."\n  },\n  "engines": { "node": ">=22" }\n}\n' > "$WORK/r3-brace/package.json"; chk r3-brace; expect_pass r3-brace
  mk r3-ws; mkdir -p "$WORK/r3-ws/packages/web"; printf '{ "name": "web", "scripts": { "e2e": "playwright test" } }\n' > "$WORK/r3-ws/packages/web/package.json"
  printf '\n```bash\npnpm run e2e\n```\n' >> "$WORK/r3-ws/docs/guide.md"; chk r3-ws; expect_pass r3-ws

  # DOC-R4 — environment variables
  mk r4; printf '\nSet `REDIS_URL` for caching.\n' >> "$WORK/r4/docs/guide.md"; chk r4; expect_only r4 DOC-R4 Low
  has r4 'names the environment variable REDIS_URL, which nothing in the repository defines or reads'
  mk r4-assign; printf '\nRun with `LOG_LEVEL=debug`.\n' >> "$WORK/r4-assign/docs/guide.md"; chk r4-assign; expect_only r4-assign DOC-R4 Low
  mk r4-code; printf '\nSet `CACHE_TTL`.\n' >> "$WORK/r4-code/docs/guide.md"; printf 'const ttl = process.env.CACHE_TTL;\n' >> "$WORK/r4-code/src/app.js"; chk r4-code; expect_pass r4-code
  mk r4-example; printf '\nSet `SMTP_HOST`.\n' >> "$WORK/r4-example/docs/guide.md"; printf 'SMTP_HOST=\n' >> "$WORK/r4-example/.env.example"; chk r4-example; expect_pass r4-example
  mk r4-ci; printf '\nCI sets `GITHUB_TOKEN` and `CI_DEPLOY_KEY`.\n' >> "$WORK/r4-ci/docs/guide.md"; chk r4-ci --ignore-env CI_DEPLOY_KEY; expect_pass r4-ci
  mk r4-md; printf '\nSet `ONLY_IN_DOCS`.\n' >> "$WORK/r4-md/docs/guide.md"; printf '\n`ONLY_IN_DOCS`\n' >> "$WORK/r4-md/docs/reference/config.md"; chk r4-md; expect_only r4-md DOC-R4 Low

  # DOC-R5 — the version
  mk r5; edit r5 README.md "$(subst 'Version: 1.4.0' 'Version: 1.3.2')" && chk r5 && expect_only r5 DOC-R5 Low
  has r5 'says version 1.3.2; package.json says 1.4.0'
  mk r5-bold; edit r5-bold README.md "$(subst 'Version: 1.4.0' '**Version:** v1.4.0')" && chk r5-bold && expect_pass r5-bold
  mk r5-file; printf '2.0.0\n' > "$WORK/r5-file/VERSION"; chk r5-file; expect_only r5-file DOC-R5 Low
  chk r5-file --version-file package.json; expect_pass r5-file-flag
  mk r5-prose; printf '\nThe version: field in the manifest is 9.9.9 in examples.\n' >> "$WORK/r5-prose/docs/guide.md"; chk r5-prose; expect_pass r5-prose
  mk r5-own; printf '\nVersion: 0.9.0\n' >> "$WORK/r5-own/docs/guide.md"; chk r5-own; expect_pass r5-own
  mk r5-pre; edit r5-pre package.json "$(subst '"version": "1.4.0"' '"version": "1.4.0-rc.1"')" && edit r5-pre README.md "$(subst 'Version: 1.4.0' 'Version: 1.4.0-rc.1')" && chk r5-pre && expect_pass r5-pre
  mk r5-pre-bad; edit r5-pre-bad package.json "$(subst '"version": "1.4.0"' '"version": "1.4.0-rc.2"')" && edit r5-pre-bad README.md "$(subst 'Version: 1.4.0' 'Version: 1.4.0-rc.1')" && chk r5-pre-bad && expect_only r5-pre-bad DOC-R5 Low
  mk r5-dev; printf 'v1.4.0-dev\n' > "$WORK/r5-dev/VERSION"; edit r5-dev README.md "$(subst 'Version: 1.4.0' 'Version: 1.4.0-dev')" && chk r5-dev && expect_pass r5-dev
  mk r6-plus; edit r6-plus README.md "$(subst 'Node.js >= 20' 'Node.js 20+')" && chk r6-plus && expect_pass r6-plus
  mk r6-plus-bad; edit r6-plus-bad README.md "$(subst 'Node.js >= 20' 'Node.js 24+')" && chk r6-plus-bad && expect_only r6-plus-bad DOC-R6 Low
  mk r5-sub; mkdir -p "$WORK/r5-sub/docs/api"; printf '# API\n\nVersion: 0.9.0\n' > "$WORK/r5-sub/docs/api/README.md"; printf '\n[API](api/README.md)\n' >> "$WORK/r5-sub/docs/guide.md"; chk r5-sub; expect_only r5-sub DOC-R5 Low

  # DOC-R6 — runtimes
  mk r6; edit r6 README.md "$(subst 'Node.js >= 20' 'Node.js >= 24')" && chk r6 && expect_only r6 DOC-R6 Low
  has r6 '.nvmrc pins Node.js 22'
  mk r6-exact; edit r6-exact README.md "$(subst 'Node.js >= 20' 'Node 18')" && chk r6-exact && expect_only r6-exact DOC-R6 Low
  mk r6-ok; edit r6-ok README.md "$(subst 'Node.js >= 20' 'Node.js 22')" && chk r6-ok && expect_pass r6-ok
  mk r6-engines; rm "$WORK/r6-engines/.nvmrc"; edit r6-engines README.md "$(subst 'Node.js >= 20' 'Node.js 20')" && chk r6-engines && expect_only r6-engines DOC-R6 Low
  has r6-engines 'package.json engines.node pins Node.js 22'
  mk r6-py; printf '3.12.4\n' > "$WORK/r6-py/.python-version"; printf '\nUse Python 3.11 locally.\n' >> "$WORK/r6-py/docs/guide.md"; chk r6-py; expect_only r6-py DOC-R6 Low
  mk r6-py-ok; printf '3.12.4\n' > "$WORK/r6-py-ok/.python-version"; printf '\nUse Python >= 3.10.\n' >> "$WORK/r6-py-ok/docs/guide.md"; chk r6-py-ok; expect_pass r6-py-ok

  # Maturity, input
  mk proto; printf '\nSet `REDIS_URL`.\n' >> "$WORK/proto/docs/guide.md"; MATURITY=prototype chk proto; expect_pass proto
  has proto 'NOTE  DOC-R4'
  mk in1; chk in1 --path ../x; expect_rc in1-path 2
  chk in1 --ignore-env lower_case; expect_rc in1-env 2
  chk in1 --ignore 'a b'; expect_rc in1-ignore 2
  chk in1 --version-file NOPE; expect_rc in1-version 2
  chk in1 --maturity high; expect_rc in1-maturity 2
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

printf "test-check-doc-drift: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
