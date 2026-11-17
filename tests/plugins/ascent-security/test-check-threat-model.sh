#!/usr/bin/env bash
# Behavior test for plugins/ascent-security/scripts/check-threat-model.sh.
#
# The good fixture (fixtures/threat-good: three entry points, seven threats, every
# one mitigated by a file that exists or accepted under an ADR that exists) passes
# SEC-T1–T4. Each check then gets negative controls: a copy broken in exactly one
# way fails that check and no other. Also covers path parameters written as {id}
# or :id, the STRIDE note, prototype maturity, an absent model and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-threat-model: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../../../plugins/ascent-security/scripts/check-threat-model.sh"
GOOD="$HERE/fixtures/threat-good"
TM=docs/security/THREAT-MODEL.md
for f in "$CHECK" "$GOOD/$TM" "$GOOD/docs/adr/ADR-012-catalog-listing.md" "$GOOD/src/items/delete.ts"; do
  [ -f "$f" ] || { echo "test-check-threat-model: missing $f"; echo "test-check-threat-model: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
run_in() { local d="$1"; shift; (cd "$d" && PATH="$SHIM:$PATH" bash "$CHECK" "$@") >"$WORK/out" 2>"$WORK/err"; RC=$?; OUT=$(cat "$WORK/out" "$WORK/err"); }
# chk NAME [ARGS] — the fixture's endpoints; NOEP drops them
chk() {
  local n="$1"; shift
  local a=(--today "${TODAY:-2026-11-20}" --maturity "${MATURITY:-enterprise}")
  [ "${NOEP:-0}" = 1 ] || a+=(--endpoint 'GET,DELETE /api/items/:id required write' --endpoint 'POST /api/chat required ai' --endpoint 'GET /api/catalog none -')
  run_in "$WORK/$n" "${a[@]}" "$@" "$TM"
}
mk() { rm -rf "${WORK:?}/$1"; cp -R "$GOOD" "$WORK/$1"; }
q() { printf '%s' "$1" | sed 's/"/\\"/g'; }
subst() { printf '{ if (index($0, "%s")) { i = index($0, "%s"); $0 = substr($0, 1, i - 1) "%s" substr($0, i + length("%s")) } print }' "$(q "$1")" "$(q "$1")" "$(q "$2")" "$(q "$1")"; }
after() { printf '{ print } index($0, "%s") && !d { print "%s"; d = 1 }' "$(q "$1")" "$(q "$2")"; }
drop()  { printf 'index($0, "%s") { next } { print }' "$(q "$1")"; }
edit() {
  awk "$2" "$WORK/$1/$TM" > "$WORK/edit.tmp" || { bad "$1: the edit's awk failed"; return 1; }
  if cmp -s "$WORK/$1/$TM" "$WORK/edit.tmp"; then bad "$1: edit changed nothing (stale anchor)"; return 1; fi
  mv "$WORK/edit.tmp" "$WORK/$1/$TM"
}
expect_only() {  # NAME CHECK [SEVERITY] — after chk
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|check-threat' | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-100 | tr '\n' ';')"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 *$3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1)"
  else ok; fi
}
expect_pass() { if [ "$RC" -eq 0 ]; then ok; else bad "$1 should pass: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"; fi; }
has() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi; }
lacks() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output must not contain: $2"; else ok; fi; }

matrix() {
  mk good; chk good
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 4 ]; then ok; else bad "good fixture should pass 4: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^PASS' | tr '\n' ';')"; fi
  has good 'it checks that threats are recorded and answered, not that the answers are right'
  lacks good 'NOTE'

  # SEC-T1 — present and well formed
  mkdir -p "$WORK/t1-absent"; chk t1-absent; expect_only t1-absent SEC-T1 Medium
  has t1-absent "$TM:absent"
  mk t1-method; edit t1-method "$(subst '| method | STRIDE |' '| method | PASTA |')" && chk t1-method && expect_only t1-method SEC-T1 Medium
  mk t1-nofields; edit t1-nofields "$(drop '| reviewed_')" && edit t1-nofields "$(drop '| method |')" && chk t1-nofields && expect_only t1-nofields SEC-T1 Medium
  mk t1-noth; edit t1-noth "$(subst '## Threats' '## Risks')" && NOEP=1 chk t1-noth && expect_only t1-noth SEC-T1 Medium
  mk t1-noep; edit t1-noep "$(subst '## Entry points' '## Interfaces')" && NOEP=1 chk t1-noep && has t1-noep 'no "## Entry points" table'
  mk t1-short; edit t1-short "$(after '| EP-3 | GET /api/catalog | internet → api | none |' '| EP-4 | GET /api/admin | none |')" && chk t1-short && expect_only t1-short SEC-T1 Medium

  # SEC-T2 — endpoints are entry points with threats
  mk t2-ep; chk t2-ep --endpoint 'POST /api/orders required write'; expect_only t2-ep SEC-T2 Medium
  has t2-ep 'endpoint POST /api/orders is not an entry point'
  mk t2-param; chk t2-param --endpoint 'GET /api/items/{itemId} required -'; expect_pass t2-param
  mk t2-nothreat; edit t2-nothreat "$(subst '| TH-5 | EP-3 |' '| TH-5 | EP-1 |')" && edit t2-nothreat "$(subst '| TH-7 | all |' '| TH-7 | EP-1 |')" && chk t2-nothreat && expect_only t2-nothreat SEC-T2 Medium
  has t2-nothreat 'entry point EP-3 (GET /api/catalog) has no threat'

  # SEC-T3 — every threat answered
  mk t3-open; edit t3-open "$(subst '| Rate limit in `src/http/limits.ts` | mitigated |' '| — | open |')" && chk t3-open && expect_only t3-open SEC-T3 Medium
  has t3-open 'TH-4 is open: A burst of chat requests runs up the model bill'
  mk t3-nofile; rm "$WORK/t3-nofile/src/chat/guard.ts"; chk t3-nofile; expect_only t3-nofile SEC-T3 Low
  has t3-nofile 'TH-3 is mitigated, but its mitigation names no file that exists'
  # a path outside the repository is never evidence, even when it exists
  mk t3-outside; : > "$WORK/guard.ts"; edit t3-outside "$(subst '`src/chat/guard.ts`' '`../guard.ts`')" && chk t3-outside && expect_only t3-outside SEC-T3 Low
  has t3-outside 'TH-3 is mitigated, but its mitigation names no file that exists'
  mk t3-noadr; rm "$WORK/t3-noadr/docs/adr/ADR-012-catalog-listing.md"; chk t3-noadr; expect_only t3-noadr SEC-T3 Low
  mk t3-adrdir; chk t3-adrdir --adr-dir docs/decisions; expect_only t3-adrdir SEC-T3 Low
  mk t3-noadrid; edit t3-noadrid "$(subst 'accepted (ADR-012)' 'accepted')" && chk t3-noadrid && expect_only t3-noadrid SEC-T3 Low
  mk t3-adr0; edit t3-adr0 "$(subst 'accepted (ADR-012)' 'accepted (ADR-12)')" && chk t3-adr0 && expect_pass t3-adr0
  mk t3-stride; edit t3-stride "$(subst '| TH-6 | EP-1, EP-2 | S |' '| TH-6 | EP-1, EP-2 | X |')" && chk t3-stride && expect_only t3-stride SEC-T3 Low
  has t3-stride 'no threat in STRIDE category S'
  mk t3-status; edit t3-status "$(subst '| Audit log in `src/items/delete.ts` | mitigated |' '| Audit log in `src/items/delete.ts` | done |')" && chk t3-status && expect_only t3-status SEC-T3 Low
  mk t3-ghost; edit t3-ghost "$(subst '| TH-7 | all |' '| TH-7 | EP-9 |')" && chk t3-ghost && expect_only t3-ghost SEC-T3 Low
  mk t3-escape; edit t3-escape "$(subst '`src/http/session.ts`' '`../../etc/hosts`')" && chk t3-escape && expect_only t3-escape SEC-T3 Low

  # SEC-T4 — reviewed by a person, recently
  mk t4-old; TODAY=2027-06-01 chk t4-old; expect_only t4-old SEC-T4 Low
  has t4-old 'reviewed 203 days ago (max 180)'
  mk t4-maxage; chk t4-maxage --max-age 5; expect_only t4-maxage SEC-T4 Low
  mk t4-nodate; edit t4-nodate "$(subst '| reviewed_on | 2026-11-10 |' '| reviewed_on | YYYY-MM-DD |')" && chk t4-nodate && expect_only t4-nodate SEC-T4 Low
  has t4-nodate 'reviewed_on is "YYYY-MM-DD", not a date'
  mk t4-claude; edit t4-claude "$(subst '| reviewed_by | Jane Doe |' '| reviewed_by | Claude |')" && chk t4-claude && expect_only t4-claude SEC-T4 Low
  mk t4-blank; edit t4-blank "$(subst '| reviewed_by | Jane Doe |' '| reviewed_by | — |')" && chk t4-blank && expect_only t4-blank SEC-T4 Low
  mk t4-future; edit t4-future "$(subst '| reviewed_on | 2026-11-10 |' '| reviewed_on | 2026-12-10 |')" && chk t4-future && expect_only t4-future SEC-T4 Low

  # maturity
  mk proto; MATURITY=prototype chk proto --endpoint 'POST /api/orders required write'
  if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^NOTE  SEC-T2 .*prototype: not rated'; then ok; else bad "prototype should note, not fail: $RC $(printf '%s\n' "$OUT" | grep -E '^(FAIL|NOTE)' | tr '\n' ';')"; fi

  # bad input
  chk good --today 2026-13-01x; [ "$RC" -eq 2 ] && ok || bad "a bad --today should exit 2, got $RC"
  chk good --max-age half; [ "$RC" -eq 2 ] && ok || bad "a non-numeric --max-age should exit 2, got $RC"
  MATURITY=mvp chk good; [ "$RC" -eq 2 ] && ok || bad "a bad --maturity should exit 2, got $RC"
  chk good --repo no-such-dir; [ "$RC" -eq 2 ] && ok || bad "a --repo that is not a directory should exit 2, got $RC"
  chk good --endpoint 'GET api/x none -'; [ "$RC" -eq 2 ] && ok || bad "an --endpoint path without / should exit 2, got $RC"
  run_in "$WORK/good" docs; [ "$RC" -eq 2 ] && ok || bad "a directory as MODEL should exit 2, got $RC"
  run_in "$WORK/good" "$TM" "$TM"; [ "$RC" -eq 2 ] && ok || bad "two models should exit 2, got $RC"
  run_in "$WORK/good" --colour "$TM"; [ "$RC" -eq 2 ] && ok || bad "an unknown option should exit 2, got $RC"
  run_in "$WORK/good" --help; if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^Usage: check-threat-model.sh'; then ok; else bad "--help should print usage and exit 0"; fi
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

printf "test-check-threat-model: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
