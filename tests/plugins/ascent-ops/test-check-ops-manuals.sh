#!/usr/bin/env bash
# Behavior test for plugins/ascent-ops/scripts/check-ops-manuals.sh.
#
# The blueprint's two manuals (blueprints/operable-service) pass all eight checks
# against the blueprint's own Compose file and template. Each check then gets
# negative controls: a copy broken in exactly one way fails that check and no
# other. Also covers the 90-day boundary, source changes read through a fake git
# (no repository is created), N/A when there is no IaC to map, credential-like
# values never printed, prose and placeholders, and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-ops-manuals: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../../../plugins/ascent-ops/scripts/check-ops-manuals.sh"
BP="$HERE/../../../plugins/ascent-ops/blueprints/operable-service"
MO=MAINTENANCE-AND-OPERATIONS.md; TS=TROUBLESHOOTING.md
for f in "$CHECK" "$BP/$MO" "$BP/$TS" "$BP/compose.yml"; do [ -f "$f" ] || { echo "test-check-ops-manuals: missing $f"; echo "test-check-ops-manuals: 0/1 PASS"; exit 1; }; done
AS_OF=$(sed -n 's/^as_of: *//p' "$BP/$MO" | head -1)

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
GITSHIM=""
run() { PATH="$GITSHIM${GITSHIM:+:}$SHIM:$PATH" bash "$CHECK" "$@" >"$WORK/out" 2>"$WORK/err"; RC=$?; OUT=$(cat "$WORK/out" "$WORK/err"); }
mk() { rm -rf "${WORK:?}/$1"; cp -R "$BP" "$WORK/$1"; }
q() { printf '%s' "$1" | sed 's/"/\\"/g'; }
after() { printf '{ print } index($0, "%s") && !d { print "%s"; d = 1 }' "$(q "$1")" "$(q "$2")"; }
subst() { printf '{ if (index($0, "%s")) { i = index($0, "%s"); $0 = substr($0, 1, i - 1) "%s" substr($0, i + length("%s")) } print }' "$(q "$1")" "$(q "$1")" "$(q "$2")" "$(q "$1")"; }
drop()  { printf 'index($0, "%s") { next } { print }' "$(q "$1")"; }
edit() {
  awk "$3" "$WORK/$1/$2" > "$WORK/edit.tmp"
  if cmp -s "$WORK/$1/$2" "$WORK/edit.tmp"; then bad "$1: edit of $2 changed nothing (stale anchor)"; return 1; fi
  mv "$WORK/edit.tmp" "$WORK/$1/$2"
}
chk() {  # NAME [extra args] — check copy NAME against its own files
  local n="$1"; shift
  run --today "${TODAY:-$AS_OF}" --repo "$WORK/$n" "$@" "$WORK/$n/$MO" "$WORK/$n/$TS" "$WORK/$n"
}
expect_only() {  # NAME CHECK [SEVERITY] — after chk
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|failure' | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-90 | tr '\n' ';')"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 *$3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1)"
  else ok; fi
}
expect_pass() { if [ "$RC" -eq 0 ]; then ok; else bad "$1 should pass ($2): $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"; fi; }

# A fake git: "inside a work tree", every ref resolves, and log/diff print what
# FAKE_LOG and FAKE_DIFF name. FAKE_NOREF=1 makes refs fail to resolve.
mkdir -p "$WORK/gitshim"
cat > "$WORK/gitshim/git" <<'SH'
#!/bin/sh
while [ "${1:-}" = "-C" ]; do shift 2; done
case "$1 ${2:-}" in
  "rev-parse --is-inside-work-tree") echo true ;;
  "rev-parse --verify") [ "${FAKE_NOREF:-0}" = 1 ] && exit 1; echo 0000000 ;;
  "log --oneline") [ -n "${FAKE_LOG:-}" ] && printf '%s\n' $FAKE_LOG ;;
  "diff --name-only") [ -n "${FAKE_DIFF:-}" ] && printf '%s\n' "$FAKE_DIFF" ;;
esac
exit 0
SH
chmod +x "$WORK/gitshim/git"

matrix() {
  GITSHIM=""
  run --today "$AS_OF" --repo "$BP" "$BP/$MO" "$BP/$TS" "$BP"
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 8 ]; then ok
  else bad "blueprint manuals should pass all 8: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^PASS' | tr '\n' ';')"; fi

  # OPS-M1 — presence and front matter
  mk m1-absent;    rm "$WORK/m1-absent/$MO"; chk m1-absent; expect_only m1-absent OPS-M1 Medium
  mk m1-nofm;      edit m1-nofm "$TS" 'NR == 1, /^---$/ && NR > 1 { next } { print }' && chk m1-nofm && expect_only m1-nofm OPS-M1
  if printf '%s\n' "$OUT" | grep -q '^FAIL  OPS-M1 .*TROUBLESHOOTING.md:1  no front matter'; then ok; else bad "m1-nofm: should say there is no front matter: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -1)"; fi
  mk m1-describes; edit m1-describes "$MO" "$(drop 'describes:')" && chk m1-describes && expect_only m1-describes OPS-M1
  mk m1-sources;   edit m1-sources "$MO" '/^sources:/ { s = 1; next } s && /^  - / { next } { s = 0; print }' && chk m1-sources && expect_only m1-sources OPS-M1

  # OPS-M2 — sections
  mk m2-mo;        edit m2-mo "$MO" "$(subst '## Rollback' '## Going back')" && chk m2-mo && expect_only m2-mo OPS-M2 Medium
  mk m2-ts;        edit m2-ts "$TS" "$(subst '## Known issues' '## Quirks')" && chk m2-ts && expect_only m2-ts OPS-M2

  # OPS-M3 — the three C4 levels
  mk m3;           edit m3 "$MO" "$(subst '### Deployment' '### Hosting')" && edit m3 "$MO" "$(subst 'C4Deployment' 'flowchart TB')" && chk m3 && expect_only m3 OPS-M3 Medium

  # OPS-M4 — every service drawn
  mk m4-compose;   printf 'services:\n  cache:\n    image: docker.io/library/redis:7.4\n' > "$WORK/m4-compose/compose.cache.yml"; chk m4-compose; expect_only m4-compose OPS-M4 Medium
  if printf '%s\n' "$OUT" | grep -q 'cache (.*compose.cache.yml:2)'; then ok; else bad "m4-compose: the missing service should be named with its file:line"; fi
  mk m4-tf;        printf 'resource "aws_sqs_queue" "jobs" {\n  name = "jobs"\n}\n' > "$WORK/m4-tf/queue.tf"; chk m4-tf; expect_only m4-tf OPS-M4
  mk m4-generic;   printf 'resource "aws_s3_bucket" "this" {\n  bucket = "x"\n}\n' > "$WORK/m4-generic/bucket.tf"; chk m4-generic; expect_only m4-generic OPS-M4
  mk m4-generic-ok; printf 'resource "aws_s3_bucket" "this" {\n  bucket = "x"\n}\n' > "$WORK/m4-generic-ok/bucket.tf"
  edit m4-generic-ok "$MO" "$(after '    ContainerDb(db, "db", "PostgreSQL 16", "Volume db-data, backed up nightly")' '    Container(bk, "backup bucket", "S3")')" && chk m4-generic-ok && expect_pass m4-generic-ok 'a generic resource name is matched by its kind (s3)'
  run --today "$AS_OF" --repo "$BP" "$BP/$MO" "$BP/$TS"
  if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^N/A   OPS-M4 .*no IaC or Compose services found; check the diagrams against the system by reading'; then ok
  else bad "OPS-M4 should be N/A without IaC: $(printf '%s\n' "$OUT" | grep 'OPS-M4')"; fi

  # OPS-M5 — dependency map
  mk m5;           edit m5 "$MO" "$(subst '| Dependency | Kind | Version |' '| Dependency | Kind | Release |')" && chk m5 && expect_only m5 OPS-M5 Low

  # OPS-M6 — current
  TODAY=2027-01-23; mk m6-edge; chk m6-edge; expect_pass m6-edge 'exactly 90 days old'
  TODAY=2027-01-24; mk m6-old; chk m6-old; expect_only m6-old OPS-M6 Medium; TODAY=""
  mk m6-missing;   rm "$WORK/m6-missing/ops-script-template.sh"; chk m6-missing; expect_only m6-missing OPS-M6
  if printf '%s\n' "$OUT" | grep -q 'sources no longer exist: ops-script-template.sh'; then ok; else bad "m6-missing: should name the missing source"; fi
  GITSHIM="$WORK/gitshim"
  mk m6-git;       FAKE_LOG="a1 b2" FAKE_DIFF="compose.yml" chk m6-git; expect_only m6-git OPS-M6
  if printf '%s\n' "$OUT" | grep -q '2 commit(s) changed its sources since v1.0.0 (compose.yml)'; then ok; else bad "m6-git: should report 2 commits and the changed source: $(printf '%s\n' "$OUT" | grep OPS-M6 | head -1)"; fi
  mk m6-git-clean; FAKE_LOG="" chk m6-git-clean; expect_pass m6-git-clean 'no commits since the described release'
  if ! printf '%s\n' "$OUT" | grep -q '^NOTE '; then ok; else bad "m6-git-clean: no NOTE expected when git answers"; fi
  # Trailing comments in the front matter (as in references/manual-sections.md) are dropped.
  mk fm-comments;  edit fm-comments "$MO" '/^(as_of|describes|sources):/ && !d[$1]++ { $0 = $0 "   # a comment" } { print }' \
    && FAKE_LOG="a1 b2" FAKE_DIFF="compose.yml" chk fm-comments && expect_only fm-comments OPS-M6
  if printf '%s\n' "$OUT" | grep -q "$MO:1  out of date: 2 commit(s) changed its sources since v1.0.0 (compose.yml)"; then ok; else bad "fm-comments: as_of, describes and sources should parse: $(printf '%s\n' "$OUT" | grep -E '^(FAIL|NOTE)' | head -2 | tr '\n' ';')"; fi
  mk m6-noref;     FAKE_NOREF=1 chk m6-noref; expect_pass m6-noref 'an unknown describes value is a NOTE, not a failure'
  if printf '%s\n' "$OUT" | grep -q '^NOTE  OPS-M6 .*describes "v1.0.0" is not a commit or tag'; then ok; else bad "m6-noref: expected a NOTE"; fi
  GITSHIM=""

  # OPS-M7 — symptom table
  mk m7-cols;      edit m7-cols "$TS" "$(subst '| Symptom | Where to look | Likely cause | Fix or escalation |' '| Symptom | Where to look | Fix |')" && chk m7-cols && expect_only m7-cols OPS-M7 Medium
  mk m7-rows;      edit m7-rows "$TS" '/^## Symptoms/ { s = 1 } /^## Diagnostic/ { s = 0 } s && /^\|/ && !/^\| Symptom/ && !/^\|---/ { next } { print }' && chk m7-rows && expect_only m7-rows OPS-M7

  # OPS-M8 — credential-like values (never printed)
  mk m8;           edit m8 "$MO" "$(after 'Secrets are never written' 'Emergency: DB_PASSWORD=hunter2-fixture-value')" && chk m8 && expect_only m8 OPS-M8 High
  if printf '%s\n' "$OUT" | grep -q 'hunter2-fixture-value'; then bad "m8: the value was printed"; else ok; fi
  mk m8-akia;      printf '\naws_access_key_id = AKIAABCDEFGHIJKLMNOP\n' >> "$WORK/m8-akia/$TS"; chk m8-akia; expect_only m8-akia OPS-M8
  mk m8-pem;       printf '\n-----BEGIN OPENSSH PRIVATE KEY-----\n' >> "$WORK/m8-pem/$TS"; chk m8-pem; expect_only m8-pem OPS-M8
  mk m8-prose;     printf '\npassword: stored in Secrets Manager, never here\nDB_PASSWORD=<from Secrets Manager>\ntoken: ${API_TOKEN}\napi_token = ***\n' >> "$WORK/m8-prose/$TS"; chk m8-prose; expect_pass m8-prose 'prose, placeholders and references are not values'

  # Bad input and help.
  run "$BP/$MO"; [ "$RC" -eq 2 ] && ok || bad "one manual should exit 2, got $RC"
  run --today 25-10-2026 "$BP/$MO" "$BP/$TS"; [ "$RC" -eq 2 ] && ok || bad "a bad --today should exit 2, got $RC"
  run "$BP/$MO" "$BP/$TS" "$WORK/no-such-dir"; [ "$RC" -eq 2 ] && ok || bad "a missing IaC path should exit 2, got $RC"
  run --help; if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^Usage: check-ops-manuals.sh'; then ok; else bad "--help should print usage and exit 0"; fi
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

printf "test-check-ops-manuals: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
