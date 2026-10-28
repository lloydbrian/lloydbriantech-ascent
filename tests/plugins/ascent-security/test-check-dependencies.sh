#!/usr/bin/env bash
# Behavior test for plugins/ascent-security/scripts/check-dependencies.sh.
#
# The good fixture (an npm workspace with package-lock v3, a yarn v1 and a pnpm v9
# project, uv, pip-compile and Pipfile projects, a Go module and a Cargo crate, a
# public .npmrc and a waived .trivyignore entry) passes all seven checks. Each check
# then gets negative controls: a copy broken in exactly one way fails that check and
# no other. Also covers maturity and pinning options, declared registries, URL
# masking, licence expressions, every scanner ignore format, an untracked lockfile
# (through a stand-in git), skipped directories, CRLF and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-dependencies: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-security"
CHECK="$PLUGIN/scripts/check-dependencies.sh"
GOOD="$HERE/fixtures/deps-good"
for f in "$CHECK" "$GOOD/package.json" "$GOOD/package-lock.json"; do [ -f "$f" ] || { echo "test-check-dependencies: missing $f"; echo "test-check-dependencies: 0/1 PASS"; exit 1; }; done
BASE=(--waived CVE-2021-23337 --today 2026-10-27)

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
# A stand-in git that tracks every file: the result never depends on whether the
# fixtures are committed, or on a git work tree around $TMPDIR. A case that needs an
# untracked file puts its own git in $SHIM, ahead of this one.
GITSHIM="$WORK/git-shim"; mkdir -p "$GITSHIM"
printf '#!/bin/sh\n[ "$1" = -C ] && cd "$2" && shift 2\n[ "$1" = -c ] && shift 2\ncase "$1" in rev-parse) exit 0 ;; ls-files) find . -type f | sed "s|^\\./||" ;; esac\n' > "$GITSHIM/git"; chmod +x "$GITSHIM/git"
run() { PATH="$SHIM:$GITSHIM:$PATH" bash "$CHECK" "$@" >"$WORK/out" 2>"$WORK/err"; RC=$?; OUT=$(cat "$WORK/out" "$WORK/err"); }
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
has() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output should contain \"$2\": $(printf '%s\n' "$OUT" | grep -E '^(FAIL|NOTE)' | head -2 | tr '\n' ';')"; fi; }
hasnt() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output should not contain \"$2\""; else ok; fi; }
expect_only() {  # NAME CHECK SEVERITY|- [OPTIONS...]
  local name="$1" chk="$2" sev="${3:--}"; shift $(($# < 3 ? $# : 3))
  run "${BASE[@]}" "$@" "$WORK/$name"
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $chk " || true)
  if [ "$RC" -ne 1 ]; then bad "$name: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|check-dep' | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$name: $chk did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$name: expected only $chk to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-110 | tr '\n' ';')"
  elif [ "$sev" != - ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $chk *$sev "; then bad "$name: $chk should be $sev: $(printf '%s\n' "$OUT" | grep "^FAIL  $chk" | head -1)"
  else ok; fi
}
expect_pass() {  # NAME WHY [OPTIONS...]
  local name="$1" why="$2"; shift 2
  run "${BASE[@]}" "$@" "$WORK/$name"
  if [ "$RC" -eq 0 ]; then ok; else bad "$name should pass ($why): exit $RC $(printf '%s\n' "$OUT" | grep -E '^FAIL|check-dep' | head -2 | tr '\n' ';')"; fi
}

matrix() {
  run "${BASE[@]}" "$GOOD"
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 6 ] && printf '%s\n' "$OUT" | grep -q '^N/A   SEC-D6 '; then ok
  else bad "good fixture should pass six checks with D6 N/A: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^PASS' | tr '\n' ';')"; fi
  has good '9 manifests (npm 4, python 3, go 1, cargo 1), 8 lockfiles, 1 ignore files, 0 findings'
  has good 'INFO  SEC-D10 '

  # SEC-D1 lockfile present
  mk d1;          rm "$WORK/d1/package-lock.json"; expect_only d1 SEC-D1 Medium
  has d1 'no package-lock.json, yarn.lock or pnpm-lock.yaml here or above'
  mk d1-proto;    rm "$WORK/d1-proto/package-lock.json"; expect_pass d1-proto 'no lockfile is required at prototype' --maturity prototype
  mk d1-off;      rm "$WORK/d1-off/package-lock.json"; expect_pass d1-off '--lockfile-required no' --lockfile-required no
  mk d1-ws;       mkdir -p "$WORK/d1-ws/packages/extra"; printf '{ "name": "extra", "dependencies": { "ms": "2.1.3" } }\n' > "$WORK/d1-ws/packages/extra/package.json"; expect_only d1-ws SEC-D1 Medium
  has d1-ws 'has no entry for packages/extra'
  mk d1-py;       rm "$WORK/d1-py/api/uv.lock"; expect_only d1-py SEC-D1
  mk d1-pip;      rm "$WORK/d1-pip/pipenv/Pipfile.lock"; expect_only d1-pip SEC-D1
  mk d1-go;       rm "$WORK/d1-go/gosvc/go.sum"; expect_only d1-go SEC-D1
  has d1-go 'no go.sum beside go.mod'
  mk d1-cargo;    rm "$WORK/d1-cargo/rust/Cargo.lock"; expect_only d1-cargo SEC-D1
  mk d1-req;      edit d1-req svc/requirements.txt "$(subst 'werkzeug==3.0.4' 'werkzeug~=3.0.4')" && expect_only d1-req SEC-D1 Medium --pinning minor
  has d1-req 'svc/requirements.in:1'
  mk d1-untracked; printf '#!/bin/sh\n[ "$1" = -C ] && cd "$2" && shift 2\n[ "$1" = -c ] && shift 2\ncase "$1" in rev-parse) exit 0 ;; ls-files) find . -type f | sed "s|^\\./||" | grep -v "^api/uv.lock$" ;; esac\n' > "$SHIM/git"; chmod +x "$SHIM/git"
  expect_only d1-untracked SEC-D1 Medium; rm -f "$SHIM/git"
  has d1-untracked 'api/uv.lock is not tracked by git'

  # SEC-D2 version pinning
  mk d2;          edit d2 package.json "$(subst '"lodash": "4.17.21"' '"lodash": "^4.17.21"')" && edit d2 package-lock.json "$(subst '"lodash": "4.17.21"' '"lodash": "^4.17.21"')" && expect_only d2 SEC-D2 Low
  has d2 '1 of 2 dependencies use ranges under version_pinning exact (first: lodash ^4.17.21)'
  expect_pass d2 'a caret range is bounded under minor' --pinning minor
  mk d2-star;     edit d2-star package.json "$(subst '"lodash": "4.17.21"' '"lodash": "*"')" && edit d2-star package-lock.json "$(subst '"lodash": "4.17.21"' '"lodash": "*"')" && expect_only d2-star SEC-D2 Low --pinning minor
  mk d2-gte;      edit d2-gte package.json "$(subst '"lodash": "4.17.21"' '"lodash": ">=4"')" && edit d2-gte package-lock.json "$(subst '"lodash": "4.17.21"' '"lodash": ">=4"')" && expect_only d2-gte SEC-D2 Low --pinning minor
  mk d2-py;       edit d2-py api/pyproject.toml "$(subst 'fastapi==0.115.0' 'fastapi>=0.115')" && expect_only d2-py SEC-D2
  mk d2-poetry;   printf '\n[tool.poetry.dependencies]\npython = "^3.12"\nhttpx = "*"\n' >> "$WORK/d2-poetry/api/pyproject.toml"; printf '\n[[package]]\nname = "httpx"\n' >> "$WORK/d2-poetry/api/uv.lock"; expect_only d2-poetry SEC-D2 Low --pinning minor
  mk d2-pipfile;  edit d2-pipfile pipenv/Pipfile "$(subst 'django = "==5.1.2"' 'django = "*"')" && expect_only d2-pipfile SEC-D2

  # SEC-D3 lockfile in step
  mk d3;          edit d3 package.json "$(subst '"lodash": "4.17.21"' '"lodash": "4.17.20"')" && expect_only d3 SEC-D3 Medium
  has d3 'lodash: manifest 4.17.20, lockfile 4.17.21'
  mk d3-extra;    edit d3-extra package.json "$(drop '"minimist": "1.2.8"')" && expect_only d3-extra SEC-D3
  has d3-extra 'minimist is in the lockfile but not the manifest'
  mk d3-ws;       edit d3-ws packages/app/package.json "$(subst '"semver": "7.6.3"' '"semver": "7.6.2"')" && expect_only d3-ws SEC-D3
  mk d3-yarn;     edit d3-yarn web/package.json "$(subst '"react": "18.3.1"' '"react": "18.3.0"')" && expect_only d3-yarn SEC-D3
  has d3-yarn 'react@18.3.0 has no yarn.lock entry'
  mk d3-pnpm;     edit d3-pnpm pn/package.json "$(subst '"zod": "3.23.8"' '"zod": "3.23.7"')" && expect_only d3-pnpm SEC-D3
  mk d3-py;       edit d3-py api/pyproject.toml "$(after '"fastapi==0.115.0",' '    "httpx==0.27.2",')" && expect_only d3-py SEC-D3
  has d3-py '1 dependency is not in the lockfile (httpx)'
  mk d3-req;      printf 'click==8.1.7\n' >> "$WORK/d3-req/svc/requirements.in"; expect_only d3-req SEC-D3
  mk d3-pipenv;   edit d3-pipenv pipenv/Pipfile "$(after 'django = ' 'Celery_Beat = "==2.7.0"')" && expect_only d3-pipenv SEC-D3
  has d3-pipenv 'celery-beat'

  # SEC-D4 engine constraint
  mk d4;          edit d4 package.json "$(drop '"engines"')" && expect_only d4 SEC-D4 Low
  mk d4-nvmrc;    edit d4-nvmrc package.json "$(drop '"engines"')" && echo 22 > "$WORK/d4-nvmrc/.nvmrc"; expect_pass d4-nvmrc '.nvmrc declares the version for the tree'
  mk d4-py;       edit d4-py api/pyproject.toml "$(drop 'requires-python')" && expect_only d4-py SEC-D4
  mk d4-pyver;    edit d4-pyver api/pyproject.toml "$(drop 'requires-python')" && echo 3.12 > "$WORK/d4-pyver/api/.python-version"; expect_pass d4-pyver '.python-version declares it'
  mk d4-pipenv;   edit d4-pipenv pipenv/Pipfile "$(drop 'python_version')" && expect_only d4-pipenv SEC-D4

  # SEC-D5 sources
  mk d5-http;     printf 'registry=http://npm.corp.example/\n' > "$WORK/d5-http/.npmrc"; expect_only d5-http SEC-D5 High
  has d5-http 'and it is plain http://'
  mk d5-reg;      printf 'registry=https://npm.corp.example/\n' > "$WORK/d5-reg/.npmrc"; expect_only d5-reg SEC-D5 Medium
  expect_pass d5-reg 'a declared registry is allowed' --registry https://npm.corp.example/
  mk d5-mask;     printf '@corp:registry=https://ci:s3cr3tpass@npm.corp.example/repo?token=abc123\n//npm.corp.example/:_authToken=npm_SECRETVALUE\n' > "$WORK/d5-mask/.npmrc"; expect_only d5-mask SEC-D5
  has d5-mask 'https://***@npm.corp.example/repo'
  hasnt d5-mask 's3cr3tpass'; hasnt d5-mask 'abc123'; hasnt d5-mask 'SECRETVALUE'
  mk d5-lock;     edit d5-lock package-lock.json "$(subst 'https://registry.npmjs.org/lodash' 'https://npm.corp.example/lodash')" && edit d5-lock package-lock.json "$(subst 'https://registry.npmjs.org/semver' 'https://npm.corp.example/semver')" && expect_only d5-lock SEC-D5 Medium
  has d5-lock '2 packages resolved from https://npm.corp.example, not the public default'
  mk d5-git;      edit d5-git web/yarn.lock "$(subst 'resolved "https://registry.yarnpkg.com/react' 'resolved "git+ssh://git@github.com/fork/react')" && expect_only d5-git SEC-D5
  mk d5-manifest; rm "$WORK/d5-manifest/pn/pnpm-lock.yaml"; edit d5-manifest pn/package.json "$(subst '"zod": "3.23.8"' '"zod": "github:colinhacks/zod#v3.23.8"')" && expect_only d5-manifest SEC-D5 Medium --lockfile-required no
  mk d5-index;    printf -- '--extra-index-url http://pypi.corp.example/simple\n' | cat - "$GOOD/svc/requirements.txt" > "$WORK/d5-index/svc/requirements.txt"; expect_only d5-index SEC-D5 High
  mk d5-trusted;  printf -- '--trusted-host pypi.corp.example\n' >> "$WORK/d5-trusted/svc/requirements.txt"; expect_only d5-trusted SEC-D5 Medium
  mk d5-url;      edit d5-url api/pyproject.toml "$(after '"fastapi==0.115.0",' '    "mylib @ https://files.corp.example/mylib-1.0.tar.gz",')" && expect_only d5-url SEC-D5
  mk d5-poetry;   printf '\n[tool.poetry.dependencies]\nmylib = { git = "https://github.com/corp/mylib.git", tag = "v1" }\n' >> "$WORK/d5-poetry/api/pyproject.toml"; expect_only d5-poetry SEC-D5
  mk d5-uvidx;    printf '\n[[tool.uv.index]]\nname = "corp"\nurl = "https://pypi.corp.example/simple"\n' >> "$WORK/d5-uvidx/api/pyproject.toml"; expect_only d5-uvidx SEC-D5
  mk d5-go;       printf 'replace github.com/google/uuid => github.com/fork/uuid v1.6.1\n' >> "$WORK/d5-go/gosvc/go.mod"; expect_only d5-go SEC-D5
  has d5-go 'github.com/google/uuid is replaced by another module'
  mk d5-cargo;    edit d5-cargo rust/Cargo.toml "$(after 'anyhow = ' 'mycrate = { git = "https://github.com/corp/mycrate" }')" && expect_only d5-cargo SEC-D5
  mk d5-creg;     edit d5-creg rust/Cargo.toml "$(after 'anyhow = ' 'mycrate = { version = "1", registry = "corp" }')" && expect_only d5-creg SEC-D5
  expect_pass d5-creg 'a declared registry name is allowed' --registry corp

  # SEC-D6 licences
  expect_pass d5-reg 'MIT and ISC pass a GPL deny list' --registry https://npm.corp.example/ --deny GPL-3.0-only,AGPL-3.0-only
  mk d6;          expect_only d6 SEC-D6 High --deny ISC
  has d6 'semver is licensed ISC'
  has d6 'web/yarn.lock records no licences: licences_denied is not checked for it'
  mk d6-or;       edit d6-or package-lock.json "$(subst '"license": "ISC"' '"license": "(ISC OR GPL-3.0-only)"')" && expect_pass d6-or 'one alternative is allowed' --deny GPL-3.0-only
  expect_only d6-or SEC-D6 High --deny GPL-3.0-only,isc
  mk d6-and;      edit d6-and package-lock.json "$(subst '"license": "ISC"' '"license": "(ISC AND GPL-3.0-only)"')" && expect_only d6-and SEC-D6 High --deny GPL-3.0-only

  # SEC-D10 scanner ignore files
  mk d10;         BASE=(--today 2026-10-27); expect_only d10 SEC-D10 Low
  has d10 'CVE-2021-23337 is suppressed with no waiver ADR'
  expect_pass d10 'a NOTE at prototype' --maturity prototype
  has d10 'NOTE  SEC-D10 '
  BASE=(--waived CVE-2021-23337 --today 2026-10-27)
  mk d10-exp;     printf 'GHSA-xxxx-yyyy-zzzz exp:2026-01-31\n' >> "$WORK/d10-exp/.trivyignore"; expect_only d10-exp SEC-D10
  has d10-exp 'the suppression expired on 2026-01-31'
  mk d10-yaml;    printf 'vulnerabilities:\n  - id: CVE-2024-0001\n    statement: accepted\n    expired_at: 2027-01-01\n' > "$WORK/d10-yaml/.trivyignore.yaml"; expect_only d10-yaml SEC-D10
  has d10-yaml '.trivyignore.yaml:2'
  mk d10-osv;     printf '[[IgnoredVulns]]\nid = "GHSA-aaaa-bbbb-cccc"\nignoreUntil = 2020-01-01T00:00:00Z\nreason = "x"\n' > "$WORK/d10-osv/osv-scanner.toml"; expect_only d10-osv SEC-D10
  has d10-osv 'expired on 2020-01-01'
  expect_pass d10-osv 'a waived id is INFO' --waived CVE-2021-23337,ghsa-aaaa-bbbb-cccc
  mk d10-nsprc;   printf '{\n  "1096460": { "active": true, "notes": "x" },\n  "GHSA-dddd-eeee-ffff": { "active": true }\n}\n' > "$WORK/d10-nsprc/.nsprc"; expect_only d10-nsprc SEC-D10
  [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  SEC-D10')" -eq 2 ] && ok || bad "d10-nsprc: both .nsprc keys should be findings"
  mk d10-ci;      printf '{\n  // allowed advisories\n  "allowlist": ["GHSA-1111-2222-3333", { "id": "CVE-2024-9" }]\n}\n' > "$WORK/d10-ci/audit-ci.jsonc"; expect_only d10-ci SEC-D10
  [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  SEC-D10')" -eq 2 ] && ok || bad "d10-ci: both allowlist entries should be findings"

  # Regressions from the 0.2.0 review: each was a false PASS, a false finding or a leak.
  # Declared registries match at a host boundary, any case, with or without a slash.
  mk r-boundary;  printf 'registry=https://npm.corp.example.attacker.io/\n' > "$WORK/r-boundary/.npmrc"; expect_only r-boundary SEC-D5 Medium --registry https://npm.corp.example
  printf 'registry=HTTPS://NPM.Corp.Example/repo/\n' > "$WORK/r-boundary/.npmrc"; expect_pass r-boundary 'a path under a declared registry, any case' --registry https://npm.corp.example
  printf 'registry=https://registry.npmjs.org\n' > "$WORK/r-boundary/.npmrc"; expect_pass r-boundary 'the public registry without a trailing slash'
  # Masking: the last "@" of the host part, and token-like path segments.
  mk r-mask;      printf 'registry=https://ci:p@ss@npm.corp.example/Abcdefghij1234567890XYZ/\n' > "$WORK/r-mask/.npmrc"; expect_only r-mask SEC-D5
  has r-mask 'https://***@npm.corp.example/***/'; hasnt r-mask 'ss@npm'; hasnt r-mask 'Abcdefghij1234567890XYZ'
  mk r-d3mask;    edit r-d3mask package.json "$(subst '"lodash": "4.17.21"' '"lodash": "git+https://u:t0ken@github.com/x/lodash.git"')" && expect_only r-d3mask SEC-D3 Medium
  has r-d3mask 'manifest git+https://***@github.com/x/lodash.git'; hasnt r-d3mask 't0ken'
  # Licence expressions: AND binds tighter than OR, parentheses group, WITH binds an exception.
  mk r-lic;       edit r-lic package-lock.json "$(subst '"license": "ISC"' '"license": "GPL-3.0-only AND (MIT OR BSD-3-Clause)"')" && expect_only r-lic SEC-D6 High --deny GPL-3.0-only
  mk r-lic-ok;    edit r-lic-ok package-lock.json "$(subst '"license": "ISC"' '"license": "(MIT OR GPL-3.0-only) AND ISC"')" && expect_pass r-lic-ok 'MIT AND ISC avoids GPL' --deny GPL-3.0-only
  mk r-lic-group; edit r-lic-group package-lock.json "$(subst '"license": "ISC"' '"license": "(MIT AND GPL-3.0-only) OR ISC"')" && expect_pass r-lic-group 'the group is one side of the OR' --deny GPL-3.0-only
  mk r-lic-with;  edit r-lic-with package-lock.json "$(subst '"license": "ISC"' '"license": "GPL-2.0-only WITH Classpath-exception-2.0"')" && expect_only r-lic-with SEC-D6 High --deny GPL-2.0-only
  # The project's own licence (packages[""]) is not a dependency's.
  mk r-rootlic;   edit r-rootlic package-lock.json "$(subst '"workspaces": ["packages/*"],' '"workspaces": ["packages/*"], "license": "GPL-3.0-only",')" && expect_pass r-rootlic 'the root licence is the project, not a dependency' --deny GPL-3.0-only
  # npm lockfile v2 repeats sources in its legacy section: counted once.
  mk r-v2;        edit r-v2 package-lock.json "$(subst '"lockfileVersion": 3,' '"lockfileVersion": 2, "dependencies": { "lodash": { "version": "4.17.21", "resolved": "https://npm.corp.example/lodash/-/lodash-4.17.21.tgz" } },')" && edit r-v2 package-lock.json "$(subst 'https://registry.npmjs.org/lodash' 'https://npm.corp.example/lodash')" && expect_only r-v2 SEC-D5 Medium
  has r-v2 '1 package resolved from https://npm.corp.example'
  # npm lockfile v1: the legacy section is the lockfile.
  mkdir -p "$WORK/r-v1"; printf '{ "name": "v1", "engines": { "node": "22" }, "dependencies": { "ms": "2.1.3", "debug": "4.3.7" } }\n' > "$WORK/r-v1/package.json"
  printf '{ "name": "v1", "lockfileVersion": 1, "dependencies": { "ms": { "version": "2.1.3", "resolved": "https://npm.corp.example/ms/-/ms-2.1.3.tgz" } } }\n' > "$WORK/r-v1/package-lock.json"
  run "${BASE[@]}" "$WORK/r-v1"; has r-v1 'debug is not in the lockfile'; has r-v1 '1 package resolved from https://npm.corp.example, not the public default or a declared registry (first: ms)'
  # yarn Berry: one quoted header with several descriptors; npm: resolutions are the registry.
  mkdir -p "$WORK/r-berry"; printf '{ "name": "b", "engines": { "node": "22" }, "dependencies": { "lodash": "^4.17.21" } }\n' > "$WORK/r-berry/package.json"
  printf '__metadata:\n  version: 8\n\n"lodash@npm:^4.17.20, lodash@npm:^4.17.21":\n  version: 4.17.21\n  resolution: "lodash@npm:4.17.21"\n' > "$WORK/r-berry/yarn.lock"
  expect_pass r-berry 'a Berry header with two descriptors' --pinning minor
  printf '\n"x@https://github.com/a/x.git#commit=abc":\n  version: 1.0.0\n  resolution: "x@https://github.com/a/x.git#commit=abc"\n' >> "$WORK/r-berry/yarn.lock"; expect_only r-berry SEC-D5 Medium --pinning minor
  # pnpm: a v6 single-project lockfile, v5 importer specifiers, tarball sources.
  mkdir -p "$WORK/r-pn6"; cp "$GOOD/pn/package.json" "$WORK/r-pn6/"
  printf "lockfileVersion: '6.0'\n\ndependencies:\n  zod:\n    specifier: 3.23.8\n    version: 3.23.8\n\npackages:\n\n  /zod@3.23.8:\n    resolution: {integrity: sha512-c}\n" > "$WORK/r-pn6/pnpm-lock.yaml"
  echo 22 > "$WORK/r-pn6/.nvmrc"; expect_pass r-pn6 'a pnpm v6 single-project lockfile'
  edit r-pn6 pnpm-lock.yaml "$(subst 'specifier: 3.23.8' 'specifier: 3.23.7')" && expect_only r-pn6 SEC-D3 Medium
  mkdir -p "$WORK/r-pn5"; cp "$GOOD/pn/package.json" "$WORK/r-pn5/"; echo 22 > "$WORK/r-pn5/.nvmrc"
  printf "lockfileVersion: 5.4\n\nimporters:\n\n  .:\n    specifiers:\n      zod: 3.23.7\n    dependencies:\n      zod: 3.23.8\n" > "$WORK/r-pn5/pnpm-lock.yaml"
  expect_only r-pn5 SEC-D3 Medium; has r-pn5 'zod: manifest 3.23.8, lockfile 3.23.7'
  mk r-pntar;     edit r-pntar pn/pnpm-lock.yaml "$(subst 'resolution: {integrity: sha512-cccc}' 'resolution: {tarball: https://npm.corp.example/zod.tgz}')" && expect_only r-pntar SEC-D5 Medium
  # Local paths are not GitHub shorthand; an npm: alias is still a range.
  mk r-local;     rm "$WORK/r-local/pn/pnpm-lock.yaml"; edit r-local pn/package.json "$(subst '"zod": "3.23.8"' '"zod": "../shared"')" && expect_pass r-local 'a relative path is local' --lockfile-required no
  mk r-alias;     edit r-alias package.json "$(subst '"lodash": "4.17.21"' '"lodash": "npm:lodash@*"')" && edit r-alias package-lock.json "$(subst '"lodash": "4.17.21"' '"lodash": "npm:lodash@*"')" && expect_only r-alias SEC-D2 Low --pinning minor
  # setup.cfg and setup.py.
  mkdir -p "$WORK/r-cfg"; printf '[metadata]\nname = x\n\n[options]\npython_requires = >=3.12\ninstall_requires =\n    requests>=2.0  # http\n\n    click==8.1.7\n' > "$WORK/r-cfg/setup.cfg"
  expect_only r-cfg SEC-D2 Low --lockfile-required no; has r-cfg 'setup.cfg:7'; has r-cfg '1 of 2 dependencies'; has r-cfg '1 manifests (npm 0, python 1'
  mkdir -p "$WORK/r-py"; printf 'from setuptools import setup\nsetup(\n    name="x",\n    python_requires=">=3.12",\n    install_requires=[\n        "requests>=2.0",\n        "click==8.1.7",\n    ],\n)\n' > "$WORK/r-py/setup.py"
  expect_only r-py SEC-D2 Low --lockfile-required no; has r-py '1 of 2 dependencies'
  # A TOML array does not end at the "]" of an item's extras; include-group is no dependency.
  mk r-extras;    edit r-extras api/pyproject.toml "$(after '"fastapi==0.115.0",' '    "requests[socks]==2.32.3",')" && edit r-extras api/pyproject.toml "$(after '"requests[socks]==2.32.3",' '    "httpx==0.27.2",')" && expect_only r-extras SEC-D3
  has r-extras 'requests, httpx'
  mk r-group;     printf '\n[dependency-groups]\ntest = ["pytest==8.3.3", {include-group = "dev"}]\n' >> "$WORK/r-group/api/pyproject.toml"; expect_pass r-group 'include-group names a group, not a package'
  # Requirements: -e of the project itself keeps a pinned file a lockfile; remote -e,
  # --editable, --find-links and name @ URL are sources.
  mk r-ed;        printf -- '-e file:.\n' >> "$WORK/r-ed/svc/requirements.txt"; expect_pass r-ed 'pip-compile writes -e file:.'
  mk r-edgit;     printf -- '-e git+https://github.com/corp/lib.git#egg=lib\n' >> "$WORK/r-edgit/svc/requirements.txt"; expect_only r-edgit SEC-D5 Medium --lockfile-required no
  mk r-editable;  printf -- '--editable=git+https://github.com/corp/lib.git#egg=lib\n' >> "$WORK/r-editable/svc/requirements.txt"; expect_only r-editable SEC-D5 Medium --lockfile-required no
  mk r-findlinks; printf -- '--find-links http://files.corp.example/wheels\n' >> "$WORK/r-findlinks/svc/requirements.txt"; expect_only r-findlinks SEC-D5 High
  mk r-at;        printf 'mylib @ https://files.corp.example/mylib-1.0.tar.gz\n' >> "$WORK/r-at/svc/requirements.in"; expect_only r-at SEC-D5 Medium
  # Go: go.sum beside go.mod; a replace to the same module; replace ( ) blocks.
  mk r-gonest;    mkdir -p "$WORK/r-gonest/gosvc/sub"; printf 'module example.com/sub\n\ngo 1.23\n\nrequire github.com/google/uuid v1.6.0\n' > "$WORK/r-gonest/gosvc/sub/go.mod"; expect_only r-gonest SEC-D1 Medium
  mk r-gosame;    printf 'replace github.com/google/uuid v1.6.0 => github.com/google/uuid v1.6.1\n' >> "$WORK/r-gosame/gosvc/go.mod"; expect_pass r-gosame 'a replace to the same module pins a version'
  mk r-goblock;   printf 'replace (\n\tgithub.com/google/uuid => github.com/fork/uuid v1.6.1\n)\n' >> "$WORK/r-goblock/gosvc/go.mod"; expect_only r-goblock SEC-D5 Medium
  # Cargo: [patch] sources, and Cargo.lock sources.
  mk r-patch;     printf '\n[patch.crates-io]\nserde = { git = "https://github.com/fork/serde" }\n' >> "$WORK/r-patch/rust/Cargo.toml"; expect_only r-patch SEC-D5 Medium
  has r-patch 'serde is patched from git'
  mk r-ctable;    printf '\n[dependencies.mycrate]\ngit = "https://github.com/corp/mycrate"\n' >> "$WORK/r-ctable/rust/Cargo.toml"; expect_only r-ctable SEC-D5 Medium
  mk r-clock;     printf 'source = "registry+https://github.com/rust-lang/crates.io-index"\n\n[[package]]\nname = "mycrate"\nversion = "0.1.0"\nsource = "git+https://github.com/corp/mycrate?rev=abc#abc"\n' >> "$WORK/r-clock/rust/Cargo.lock"; expect_only r-clock SEC-D5 Medium
  has r-clock '1 package resolved from git+https://github.com, not the public default or a declared registry (first: mycrate)'
  # osv-scanner.toml: ignoreUntil may come before id.
  mk r-osv;       printf '[[IgnoredVulns]]\nignoreUntil = 2020-01-01T00:00:00Z\nid = "GHSA-aaaa-aaaa-aaaa"\n\n[[IgnoredVulns]]\nid = "GHSA-bbbb-bbbb-bbbb"\n' > "$WORK/r-osv/osv-scanner.toml"; expect_only r-osv SEC-D10
  has r-osv 'GHSA-aaaa-aaaa-aaaa is suppressed, and the suppression expired on 2020-01-01'; has r-osv 'GHSA-bbbb-bbbb-bbbb is suppressed with no waiver ADR'
  # The SEC-D6 cap: ten findings per lockfile, the rest counted.
  mkdir -p "$WORK/r-cap"; printf '{ "name": "c", "engines": { "node": "22" }, "dependencies": { "p1": "1.0.0" } }\n' > "$WORK/r-cap/package.json"
  awk 'BEGIN { printf "{ \"lockfileVersion\": 3, \"packages\": { \"\": { \"dependencies\": { \"p1\": \"1.0.0\" } }"; for (i = 1; i <= 12; i++) printf ",\n \"node_modules/p%d\": { \"version\": \"1.0.0\", \"license\": \"GPL-3.0-only\" }", i; print " } }" }' > "$WORK/r-cap/package-lock.json"
  run "${BASE[@]}" --deny GPL-3.0-only "$WORK/r-cap"
  [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  SEC-D6 ')" -eq 10 ] && ok || bad "r-cap: expected 10 SEC-D6 findings"
  has r-cap 'r-cap/package-lock.json: 2 more packages with a denied licence'
  # A PATH named like a skipped directory is still read; a trailing slash changes nothing.
  mk build;       run "${BASE[@]}" "$WORK/build"; [ "$RC" -eq 0 ] && ok || bad "build: a PATH named build should be checked, exit $RC"; has build '9 manifests'
  # Older BSD find prints PATH/ as PATH//x; a stand-in find does the same here.
  mk r-slash;     printf '#!/bin/sh\ncase "$1" in */) s="$1"; "%s" "$@" | sed "s#^$s#$s/#" ;; *) exec "%s" "$@" ;; esac\n' "$(command -v find)" "$(command -v find)" > "$SHIM/find"; chmod +x "$SHIM/find"
  run "${BASE[@]}" "$WORK/r-slash/"; rm -f "$SHIM/find"; [ "$RC" -eq 0 ] && ok || bad "r-slash: a trailing slash should change nothing: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -1)"
  # Lockfile tracking: an untracked npm lockfile, and a second PATH outside git.
  mk r-untr;      printf '#!/bin/sh\n[ "$1" = -C ] && cd "$2" && shift 2\n[ "$1" = -c ] && shift 2\ncase "$1" in rev-parse) exit 0 ;; ls-files) find . -type f | sed "s|^\\./||" | grep -v "^package-lock.json$" ;; esac\n' > "$SHIM/git"; chmod +x "$SHIM/git"
  expect_only r-untr SEC-D1 Medium; has r-untr 'r-untr/package-lock.json is not tracked by git'
  mk r-ingit; mk r-nogit; printf '#!/bin/sh\n[ "$1" = -C ] && cd "$2" && shift 2\n[ "$1" = -c ] && shift 2\ncase "$1" in rev-parse) case "$PWD" in *r-ingit*) exit 0 ;; *) exit 1 ;; esac ;; ls-files) find . -type f | sed "s|^\\./||" ;; esac\n' > "$SHIM/git"
  run "${BASE[@]}" "$WORK/r-ingit" "$WORK/r-nogit"; rm -f "$SHIM/git"; [ "$RC" -eq 0 ] && ok || bad "r-nogit: a PATH outside git has no untracked lockfiles: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -1)"
  # A file name with a newline is skipped, not split into two names.
  mk r-newline;   : > "$WORK/r-newline/a
package.json"; expect_pass r-newline 'a newline in a file name'

  # Skipped directories, named files, CRLF
  mk skip;        mkdir -p "$WORK/skip/node_modules/x" "$WORK/skip/tests/fx"; printf '{ "dependencies": { "a": "*" } }\n' | tee "$WORK/skip/node_modules/x/package.json" > "$WORK/skip/tests/fx/package.json"; expect_pass skip 'node_modules and test code are skipped'
  run "${BASE[@]}" --include-tests "$WORK/skip"; [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q 'tests/fx/package.json' && ok || bad "skip: --include-tests should read tests/"
  run "${BASE[@]}" "$WORK/skip/tests/fx/package.json"; [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q 'tests/fx/package.json' && ok || bad "skip: a named file is always read, got $RC"
  mk crlf;        for f in package.json package-lock.json api/pyproject.toml svc/requirements.txt; do awk '{ printf "%s\r\n", $0 }' "$WORK/crlf/$f" > "$WORK/edit.tmp" && mv "$WORK/edit.tmp" "$WORK/crlf/$f"; done; expect_pass crlf 'CRLF line endings'
  mkdir -p "$WORK/empty"; run "$WORK/empty"
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^N/A ')" -eq 7 ]; then ok; else bad "empty: all seven checks should be N/A, exit $RC"; fi

  # Bad input and help.
  run "$WORK/does-not-exist"; [ "$RC" -eq 2 ] && ok || bad "missing path should exit 2, got $RC"
  run "$GOOD/rust/Cargo.toml" "$HERE/test-check-dependencies.sh"; [ "$RC" -eq 2 ] && ok || bad "a named non-manifest should exit 2, got $RC"
  run --maturity high "$GOOD"; [ "$RC" -eq 2 ] && ok || bad "bad --maturity should exit 2, got $RC"
  run --today 27-10-2026 "$GOOD"; [ "$RC" -eq 2 ] && ok || bad "bad --today should exit 2, got $RC"
  run --bogus "$GOOD"; [ "$RC" -eq 2 ] && ok || bad "unknown option should exit 2, got $RC"
  run --help; if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^Usage: check-dependencies.sh'; then ok; else bad "--help should print usage and exit 0"; fi
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

printf "test-check-dependencies: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
