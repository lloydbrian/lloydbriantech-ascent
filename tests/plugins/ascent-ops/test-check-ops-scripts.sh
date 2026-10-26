#!/usr/bin/env bash
# Behavior test for plugins/ascent-ops/scripts/check-ops-scripts.sh.
#
# The good fixtures (a zero-touch deploy script, a read-only POSIX script, a sourced
# library, a Makefile, a multi-stage Dockerfile, Compose, Terraform versions and a
# workflow) pass all nine checks. Each check then gets negative controls: a copy
# broken in exactly one way fails that check and no other. Also covers exemptions
# (mktemp and build-directory removal, heredoc bodies, here-strings, libraries,
# test code), CRLF, the plugin's own scripts, and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-ops-scripts: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-ops"
CHECK="$PLUGIN/scripts/check-ops-scripts.sh"
GOOD="$HERE/fixtures/scripts-good"
for f in "$CHECK" "$GOOD/scripts/deploy.sh" "$GOOD/Makefile"; do [ -f "$f" ] || { echo "test-check-ops-scripts: missing $f"; echo "test-check-ops-scripts: 0/1 PASS"; exit 1; }; done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
run() { PATH="$SHIM:$PATH" bash "$CHECK" "$@" >"$WORK/out" 2>"$WORK/err"; RC=$?; OUT=$(cat "$WORK/out" "$WORK/err"); }
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
expect_only() {  # NAME CHECK [SEVERITY]
  run "$WORK/$1"
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|failure' | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-80 | tr '\n' ';')"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 *$3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1)"
  else ok; fi
}
expect_pass() {  # NAME WHY
  run "$WORK/$1"
  if [ "$RC" -eq 0 ]; then ok; else bad "$1 should pass ($2): $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"; fi
}
# script NAME FILE BODY — a well-formed script (shebang, strict mode, --help) with BODY
script() {
  printf '#!/usr/bin/env bash\n# Usage: %s [--help]\nset -euo pipefail\ncase "${1:-}" in -h|--help) echo usage; exit 0 ;; esac\n%b\n' "$2" "$3" > "$WORK/$1/scripts/$2"
}

matrix() {
  run "$GOOD"
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 9 ]; then ok
  else bad "good fixtures should pass all 9: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^PASS' | tr '\n' ';')"; fi

  mk z1;          edit z1 scripts/deploy.sh 'NR == 1 { next } { print }' && expect_only z1 Z1 Medium
  mk z2;          edit z2 scripts/deploy.sh "$(subst 'set -euo pipefail' 'set -eu')" && expect_only z2 Z2 Medium
  mk z2-sh;       edit z2-sh scripts/status.sh "$(subst 'set -eu' 'set -e')" && expect_only z2-sh Z2
  mk z2-none;     edit z2-none scripts/deploy.sh "$(drop 'set -euo pipefail')" && expect_only z2-none Z2
  mk z3;          edit z3 scripts/status.sh "$(subst '-h|--help|"")' '"")')" && expect_only z3 Z3 Low
  mk z4;          script z4 restart.sh 'preflight() { systemctl is-active app; }\npreflight\nsystemctl restart app\ncurl -sf http://localhost:8080/-/health'; expect_only z4 Z4 Medium
  mk z5-read;     edit z5-read scripts/deploy.sh "$(after 'read -rs -p' 'read -r -p "DB password: " DB_PASSWORD')" && expect_only z5-read Z5 High
  mk z5-arg;      edit z5-arg scripts/deploy.sh "$(after 'WORK="$(mktemp -d)"' 'API_TOKEN="${1:-}"')" && expect_only z5-arg Z5
  mk z5-opt;      edit z5-opt scripts/deploy.sh "$(after '    --yes) YES=1; shift ;;' '    --password) shift 2 ;;')" && expect_only z5-opt Z5
  mk z5-echo;     edit z5-echo scripts/deploy.sh "$(after 'read -rs -p' 'echo "token is $REGISTRY_TOKEN"')" && expect_only z5-echo Z5
  mk z5-check;    edit z5-check scripts/deploy.sh "$(after 'read -rs -p' 'echo "token set: ${REGISTRY_TOKEN:+yes}"')" && expect_pass z5-check '${VAR:+...} does not print the value'
  mk z6;          script z6 nuke.sh 'DRY_RUN=0\npreflight() { :; }\npostflight() { :; }\npreflight\nterraform -chdir=infra destroy -auto-approve\npostflight'; expect_only z6 Z6 High
  mk z6-rm;       script z6-rm wipe.sh 'rm -rf /srv/app/data'; expect_only z6-rm Z6
  mk z6-sql;      script z6-sql reset-db.sh 'psql -c "DROP TABLE items"'; expect_only z6-sql Z6
  mk z6-build;    script z6-build clean.sh 'rm -rf node_modules dist\nT="$(mktemp -d)"\nrm -rf "$T"'; expect_pass z6-build 'build directories and mktemp directories are exempt'
  mk z6-guarded;  script z6-guarded nuke.sh 'DRY_RUN=0\npreflight() { :; }\npostflight() { :; }\nread -r -p "Type the stack name to confirm: " ANSWER\npreflight\nterraform destroy -auto-approve\npostflight'; expect_pass z6-guarded 'a typed confirmation guards it'
  mk z7;          printf 'clean:\n\trm -f out.txt\n' >> "$WORK/z7/Makefile"; expect_only z7 Z7 Low
  mk z8-latest;   edit z8-latest Dockerfile "$(subst 'node:22.11.0-alpine' 'node:latest')" && expect_only z8-latest Z8 Medium
  mk z8-untagged; edit z8-untagged Dockerfile "$(subst 'node:22.11.0-alpine' 'node')" && expect_only z8-untagged Z8
  mk z8-compose;  edit z8-compose compose.yml "$(subst '"postgres:16.4"' 'postgres')" && expect_only z8-compose Z8
  mk z8-npx;      edit z8-npx .github/workflows/ci.yml "$(subst '@0.14.0' '@latest')" && expect_only z8-npx Z8
  mk z8-action;   edit z8-action .github/workflows/ci.yml "$(subst 'actions/checkout@v4' 'actions/checkout@main')" && expect_only z8-action Z8
  mk z8-floor;    edit z8-floor infra/versions.tf "$(subst '"~> 5.70"' '">= 5.0"')" && expect_only z8-floor Z8
  mk z8-nover;    edit z8-nover infra/versions.tf "$(drop 'version = "3.6.3"')" && expect_only z8-nover Z8
  mk z8-git;      edit z8-git infra/versions.tf "$(subst '?ref=v1.2.0' '')" && expect_only z8-git Z8
  mk z8-module;   edit z8-module infra/versions.tf "$(drop 'version = "5.13.0"')" && expect_only z8-module Z8
  mk z8-curl;     edit z8-curl scripts/deploy.sh "$(after 'trap ' 'curl -fsSL https://get.example.dev/install.sh | sh')" && expect_only z8-curl Z8
  mk z8-old;      edit z8-old infra/versions.tf "$(subst 'random = {' 'null = "~> 3.2"\n    random = {')" && expect_pass z8-old 'the string form of a provider constraint is read'
  mk z9;          script z9 restart.sh 'DRY_RUN="${DRY_RUN:-0}"\nsystemctl restart app'; expect_only z9 Z9 Low

  # Exemptions and parsing.
  mk heredoc;     printf '#!/bin/sh\n# Usage: notes.sh\nset -eu\n[ "${1:-}" = --help ] && exit 0\ncat <<EOF\nnever run: rm -rf /srv/data and terraform destroy\nEOF\n' > "$WORK/heredoc/scripts/notes.sh"; expect_pass heredoc 'heredoc bodies are text, not commands'
  mk herestring;  script herestring check.sh 'grep -q x <<<"$1"\nrm -rf /srv/app/data'; expect_only herestring Z6
  mk herestring2; script herestring2 check.sh 'grep -q x <<<yes\nrm -rf /srv/app/data'; expect_only herestring2 Z6
  mk tests;       run --include-tests "$WORK/tests"
  if [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q 'tests/test-deploy.sh:1'; then ok; else bad "--include-tests should check tests/test-deploy.sh"; fi
  mk crlf;        awk '{ printf "%s\r\n", $0 }' "$GOOD/scripts/deploy.sh" > "$WORK/crlf/scripts/deploy.sh"; expect_pass crlf 'CRLF line endings'

  # Review findings (ADR-013 calibration). CHG marks a changing script as dry-run
  # capable and checked before and after, so only the check under test can fail.
  CHG='DRY_RUN="${DRY_RUN:-0}"\npreflight() { :; }\npostflight() { :; }\n'
  mk guard-token;   script guard-token teardown.sh "${CHG}"'read -rsp "Vault token: " VAULT_TOKEN\nterraform destroy -auto-approve'; expect_only guard-token Z6 High
  mk guard-answer;  script guard-answer teardown.sh "${CHG}"'read -rp "Proceed? " answer\n[ "$answer" = yes ] || exit 1\nterraform destroy -auto-approve'; expect_pass guard-answer 'a read into answer is a confirmation'
  mk read-rp;       script read-rp login.sh 'read -rp "API token: " API_TOKEN'; expect_only read-rp Z5 High
  mk z6-no-line;    script z6-no-line reset.sh 'PGPASSWORD=fixture-literal-value psql -c "DROP TABLE users"'; expect_only z6-no-line Z6 High
  if printf '%s\n' "$OUT" | grep -q 'fixture-literal-value'; then bad "z6-no-line: the line (and its secret) was printed"; elif printf '%s\n' "$OUT" | grep -q 'flag (--yes, --apply, CONFIRM): DROP TABLE$'; then ok; else bad "z6-no-line: the finding should name DROP TABLE: $(printf '%s\n' "$OUT" | grep '^FAIL  Z6' | head -1)"; fi
  mk compose-build; printf 'services:\n  web:\n    build: ./web\n    image: app-web\n' > "$WORK/compose-build/compose.dev.yml"; expect_pass compose-build 'a service with build: names its own image'
  mk compose-alpine; printf 'services:\n  proxy:\n    image: nginx:alpine\n' > "$WORK/compose-alpine/compose.proxy.yml"; expect_only compose-alpine Z8 Medium
  mk from-alpine;   printf 'FROM nginx:alpine\n' > "$WORK/from-alpine/Dockerfile.proxy"; expect_only from-alpine Z8
  mk git-ssh;       printf 'module "vpc" {\n  source = "git@github.com:example/vpc.git?ref=v1.2.0"\n}\n' > "$WORK/git-ssh/infra/vpc.tf"; expect_pass git-ssh 'a git@ source pinned with ?ref='
  mk git-ssh-ref;   printf 'module "vpc" {\n  source = "git@github.com:example/vpc.git"\n}\n' > "$WORK/git-ssh-ref/infra/vpc.tf"; expect_only git-ssh-ref Z8

  # The plugin's own scripts pass.
  run "$PLUGIN/scripts"
  if [ "$RC" -eq 0 ]; then ok; else bad "plugin scripts should pass: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -3 | tr '\n' ';')"; fi

  # Bad input and help.
  run "$WORK/does-not-exist"; [ "$RC" -eq 2 ] && ok || bad "missing path should exit 2, got $RC"
  run "$GOOD/compose.yml" "$HERE/fixtures/iac-good/manual.md"; [ "$RC" -eq 2 ] && ok || bad "a named non-script file should exit 2, got $RC"
  run --bogus "$GOOD"; [ "$RC" -eq 2 ] && ok || bad "unknown option should exit 2, got $RC"
  run --help; if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^Usage: check-ops-scripts.sh'; then ok; else bad "--help should print usage and exit 0"; fi
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

printf "test-check-ops-scripts: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
