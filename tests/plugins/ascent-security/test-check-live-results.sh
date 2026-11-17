#!/usr/bin/env bash
# Behavior test for plugins/ascent-security/scripts/check-live-results.sh.
#
# The good fixture (fixtures/live/results: a hardened target's results) passes
# SEC-L1–L8 and SEC-L10 and leaves SEC-L9 N/A. Each check then gets negative
# controls: a copy with one row changed fails that check and no other. Also covers
# the scanner reports (ZAP JSON, nuclei JSONL, dalfox) against the threshold,
# waivers, prototype maturity, the newest file chosen from a folder, and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-live-results: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../../../plugins/ascent-security/scripts/check-live-results.sh"
FX="$HERE/fixtures/live"
for f in "$CHECK" "$FX/results/2026-11-15-local.tsv" "$FX/zap-report.json" "$FX/nuclei-results.jsonl" "$FX/dalfox-results.jsonl"; do
  [ -f "$f" ] || { echo "test-check-live-results: missing $f"; echo "test-check-live-results: 0/1 PASS"; exit 1; }
done
RES=2026-11-15-local.tsv

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
run() { (PATH="$SHIM:$PATH" bash "$CHECK" "$@") >"$WORK/out" 2>"$WORK/err"; RC=$?; OUT=$(cat "$WORK/out" "$WORK/err"); }
# chk NAME [ARGS] — the fixture's contract values, on copy NAME
chk() {
  local n="$1"; shift
  run --target local --url http://127.0.0.1:8080 --today "${TODAY:-2026-11-20}" --maturity "${MATURITY:-enterprise}" \
    --endpoint 'GET,DELETE /api/items/{id} required write' --endpoint 'POST /api/items required write' --endpoint 'POST /api/chat required ai' \
    "$@" "$WORK/$n"
}
mk() { rm -rf "${WORK:?}/$1"; mkdir -p "$WORK/$1"; cp "$FX/results/$RES" "$WORK/$1/"; }
# setrow NAME PROBE METHOD PATH STATUS DETAIL — change one row's status and detail
setrow() {
  awk -F'\t' -v OFS='\t' -v p="$2" -v m="$3" -v pa="$4" -v s="$5" -v d="$6" '$1 == p && $2 == m && $3 == pa && !done { $4 = s; $5 = d; done = 1 } { print }' "$WORK/$1/$RES" > "$WORK/edit.tmp"
  if cmp -s "$WORK/$1/$RES" "$WORK/edit.tmp"; then bad "$1: setrow $2 $3 $4 changed nothing (stale anchor)"; return 1; fi
  mv "$WORK/edit.tmp" "$WORK/$1/$RES"
}
sethead() {  # NAME KEY VALUE
  awk -F'\t' -v OFS='\t' -v k="# $2" -v v="$3" '$1 == k { $2 = v } { print }' "$WORK/$1/$RES" > "$WORK/edit.tmp"; mv "$WORK/edit.tmp" "$WORK/$1/$RES"
}
expect_only() {  # NAME CHECK [SEVERITY] — after chk
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|check-live' | head -3 | tr '\n' ';')"
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
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 9 ] && printf '%s\n' "$OUT" | grep -q '^N/A   SEC-L9 .*no --zap'; then ok
  else bad "good fixture should pass 9 and leave SEC-L9 N/A: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^PASS' | tr '\n' ';')"; fi
  has good 'results show what the target answered when the checks ran, not that it is unchanged since'

  # SEC-L1 — security headers
  mk l1-csp; setrow l1-csp headers GET / 200 'missing=content-security-policy' && chk l1-csp && expect_only l1-csp SEC-L1 Medium
  mk l1-frame; setrow l1-frame headers GET / 200 'missing=frame-protection,x-content-type-options' && chk l1-frame && expect_only l1-frame SEC-L1 Medium
  has l1-frame 'missing x-content-type-options'
  mk l1-ref; setrow l1-ref headers GET / 200 'missing=referrer-policy' && chk l1-ref && expect_only l1-ref SEC-L1 Low
  mk l1-waived; setrow l1-waived headers GET / 200 'missing=referrer-policy' && chk l1-waived --waived SEC-L1:referrer-policy && expect_pass l1-waived
  has l1-waived 'INFO  SEC-L1'

  # SEC-L2 — TRACE and CONNECT
  mk l2-xst; setrow l2-xst verb TRACE /api/items 200 'echo=1' && chk l2-xst && expect_only l2-xst SEC-L2 Medium
  has l2-xst 'cross-site tracing'
  mk l2-connect; setrow l2-connect verb CONNECT / 200 - && chk l2-connect && expect_only l2-connect SEC-L2 Low
  mk l2-trace; setrow l2-trace verb TRACE / 200 - && chk l2-trace && expect_only l2-trace SEC-L2 Low
  mk l2-404; setrow l2-404 verb TRACE / 404 - && chk l2-404 && expect_pass l2-404

  # SEC-L3 — traversal
  mk l3; setrow l3 traversal GET '/api/items/..%2fetc%2fpasswd' 200 'leak=1' && chk l3 && expect_only l3 SEC-L3 High
  mk l3-200; setrow l3-200 traversal GET '/api/items/../etc/passwd' 200 - && chk l3-200 && expect_pass l3-200

  # SEC-L4 — unauthenticated writes
  mk l4; setrow l4 unauth-write DELETE /api/items/ascent-probe 204 - && chk l4 && expect_only l4 SEC-L4 High
  has l4 'DELETE /api/items/ascent-probe answered 204 without sign-in'
  mk l4-403; setrow l4-403 unauth-write POST /api/items 403 - && chk l4-403 && expect_pass l4-403
  mk l4-waived; setrow l4-waived unauth-write POST /api/items 201 - && chk l4-waived --waived SEC-L4:/api/items && expect_pass l4-waived

  # SEC-L5 — oversized bodies
  mk l5; setrow l5 oversize POST /api/items 200 'bytes=1150991' && chk l5 && expect_only l5 SEC-L5 Medium
  mk l5-502; setrow l5-502 oversize POST /api/items 502 'bytes=1150991' && chk l5-502 && expect_only l5-502 SEC-L5 Medium
  mk l5-none; setrow l5-none oversize POST /api/items 000 'bytes=1150991' && chk l5-none && expect_only l5-none SEC-L5 Medium
  has l5-none 'answered nothing'
  mk l5-400; setrow l5-400 oversize POST /api/items 400 'bytes=1150991' && chk l5-400 && expect_pass l5-400

  # SEC-L6 — disclosure
  mk l6-env; setrow l6-env disclosure GET /.env 200 'secret,env' && chk l6-env && expect_only l6-env SEC-L6 High
  mk l6-git; setrow l6-git disclosure GET /.git/config 200 git && chk l6-git && expect_only l6-git SEC-L6 High
  mk l6-404; setrow l6-404 disclosure GET /.env 404 secret && chk l6-404 && expect_pass l6-404
  mk l6-trace; setrow l6-trace malformed POST /api/items 500 trace && chk l6-trace && expect_only l6-trace SEC-L6 Medium
  mk l6-banner; setrow l6-banner headers GET / 200 'banner=server: nginx/1.25.3' && chk l6-banner && expect_only l6-banner SEC-L6 Low
  has l6-banner 'nginx/1.25.3'

  # SEC-L7 — the canary
  mk l7; setrow l7 canary POST /api/chat 200 'canary=1' && chk l7 && expect_only l7 SEC-L7 High
  mk l7-refused; setrow l7-refused canary POST /api/chat 200 - && chk l7-refused && expect_pass l7-refused

  # SEC-L8 — the burst
  mk l8; setrow l8 burst POST /api/chat - '200=10' && chk l8 && expect_only l8 SEC-L8 Medium
  mk l8-limited; setrow l8-limited burst POST /api/chat - '200=3;429=7' && chk l8-limited && expect_pass l8-limited
  mk l8-5xx; setrow l8-5xx burst POST /api/chat - '401=9;503=1' && chk l8-5xx && expect_only l8-5xx SEC-L8 Medium
  mk l8-limit5xx; setrow l8-limit5xx burst POST /api/chat - '429=9;503=1' && chk l8-limit5xx && expect_only l8-limit5xx SEC-L8 Medium
  has l8-limit5xx '1 of 10 burst requests failed'
  mk l8-mixed; setrow l8-mixed burst POST /api/chat - '200=2;401=8' && chk l8-mixed && expect_only l8-mixed SEC-L8 Medium

  # SEC-L9 — scanner reports
  mk l9; chk l9 --zap "$FX/zap-report.json"; expect_only l9-zap SEC-L9 High
  has l9-zap 'ZAP 40012 Cross Site Scripting (Reflected) (1 instance(s))'
  has l9-zap 'zap: 2 finding(s) below the High threshold, not rated'
  lacks l9-zap 'Timestamp Disclosure'
  chk l9 --nuclei "$FX/nuclei-results.jsonl"; expect_only l9-nuclei SEC-L9 High
  has l9-nuclei 'nuclei ai-proxy-system-override (high)'
  lacks l9-nuclei 'tech-detect'
  chk l9 --dalfox "$FX/dalfox-results.jsonl"; expect_only l9-dalfox SEC-L9 High
  has l9-dalfox 'dalfox V (verified) inHTML in q'
  lacks l9-dalfox 'jquery'
  # informational lines are never findings, at any threshold
  chk l9 --dalfox "$FX/dalfox-results.jsonl" --nuclei "$FX/nuclei-results.jsonl" --threshold Low
  lacks l9-info 'jquery'; lacks l9-info 'OutdatedComponent'; lacks l9-info 'tech-detect'; lacks l9-info 'below the Low threshold'
  chk l9 --nuclei "$FX/nuclei-results.jsonl" --threshold Medium; has l9-medium 'nuclei git-config (medium)'
  lacks l9-medium 'http-missing-security-headers'
  chk l9 --zap "$FX/zap-report.json" --threshold Low; if [ "$(printf '%s\n' "$OUT" | grep -c '^FAIL  SEC-L9')" -eq 3 ]; then ok; else bad "l9-low: ZAP at Low should rate 3 alerts: $(printf '%s\n' "$OUT" | grep '^FAIL' | tr '\n' ';')"; fi
  chk l9 --zap "$FX/zap-report.json" --waived 40012; expect_pass l9-waived
  has l9-waived 'INFO  SEC-L9'
  chk l9 --dalfox "$FX/dalfox-results.jsonl" --threshold Medium; has l9-dalfox-r 'dalfox R (reflected) inATTR in lang'
  chk l9 --dalfox "$FX/dalfox-results.jsonl" --waived dalfox:q; expect_pass l9-dalfox-waived
  printf '%s\n' '{"data":"http://admin:hunter2@127.0.0.1:8080/s?q=x","inject_type":"inHTML","param":"q","severity":"High","type":"V"}' > "$WORK/dalfox-cred.jsonl"
  chk l9 --dalfox "$WORK/dalfox-cred.jsonl"; lacks l9-cred 'hunter2'
  has l9-cred '://***@127.0.0.1'
  # Critical is rated High
  printf '%s\n' '{"template-id":"cve-2099-0001","info":{"name":"A critical issue","severity":"critical"},"matched-at":"http://127.0.0.1:8080/"}' > "$WORK/nuclei-critical.jsonl"
  chk l9 --nuclei "$WORK/nuclei-critical.jsonl"; expect_only l9-critical SEC-L9 High
  has l9-critical 'nuclei cve-2099-0001 (critical)'
  : > "$WORK/empty.jsonl"; chk l9 --nuclei "$WORK/empty.jsonl"; expect_pass l9-empty
  has l9-empty 'PASS  SEC-L9   scanner reports (no finding)'

  # SEC-L10 — present, fresh, for this target, complete
  mkdir -p "$WORK/l10-none"; chk l10-none; expect_only l10-none SEC-L10 Low
  has l10-none 'no results file for target local'
  has l10-none 'N/A   SEC-L1   security headers (unmeasured: no results)'
  has l10-none 'N/A   SEC-L9   scanner reports (no --zap'
  mk l10-old; TODAY=2026-12-31 chk l10-old; expect_only l10-old SEC-L10 Low
  has l10-old 'results are 46 days old (max 30)'
  mk l10-url; sethead l10-url url http://127.0.0.1:9090; chk l10-url; expect_only l10-url SEC-L10 Low
  mk l10-target; sethead l10-target target beta; chk l10-target; expect_only l10-target SEC-L10 Low
  mk l10-future; sethead l10-future date 2026-12-01; chk l10-future; expect_only l10-future SEC-L10 Low
  mk l10-skipw
  awk -F'\t' -v OFS='\t' '$1 == "unauth-write" || $1 == "oversize" || $1 == "malformed" { if (!s[$1]++) print $1, "-", "-", "-", "skipped=no --allow-writes"; next } { print }' "$WORK/l10-skipw/$RES" > "$WORK/edit.tmp" && mv "$WORK/edit.tmp" "$WORK/l10-skipw/$RES"
  chk l10-skipw; expect_only l10-skipw SEC-L10 Low
  has l10-skipw 'N/A   SEC-L4   writes need sign-in (unmeasured: skipped)'
  has l10-skipw 'SEC-L4 and SEC-L5 are unmeasured'
  run --target local --url http://127.0.0.1:8080 --today 2026-11-20 --endpoint 'GET /api/catalog none -' "$WORK/l10-skipw"; expect_pass l10-skipw-noneed
  # writes that need no sign-in still need the oversized body (trial, 2026-11-17)
  run --target local --url http://127.0.0.1:8080 --today 2026-11-20 --endpoint 'POST /api/journal none write' "$WORK/l10-skipw"
  expect_only l10-skipw-open SEC-L10 Low
  has l10-skipw-open 'SEC-L5 is unmeasured'
  has l10-skipw-open 'N/A   SEC-L5   oversized bodies refused (unmeasured: skipped)'
  has l10-skipw-open 'N/A   SEC-L4   writes need sign-in (no write endpoint that requires sign-in)'
  mk l10-nowrite; awk -F'\t' -v OFS='\t' '$1 == "unauth-write" { print; next } $1 == "oversize" || $1 == "malformed" { if (!s[$1]++) print $1, "-", "-", "-", "skipped=no write endpoint"; next } { print }' "$WORK/l10-nowrite/$RES" > "$WORK/edit.tmp" && mv "$WORK/edit.tmp" "$WORK/l10-nowrite/$RES"
  run --target local --url http://127.0.0.1:8080 --today 2026-11-20 --endpoint 'DELETE /api/items/{id} none write' "$WORK/l10-nowrite"; expect_pass l10-nowrite
  mk l10-skipai
  awk -F'\t' -v OFS='\t' '$1 == "canary" || $1 == "burst" { print $1, "-", "-", "-", "skipped=no --allow-ai"; next } { print }' "$WORK/l10-skipai/$RES" > "$WORK/edit.tmp" && mv "$WORK/edit.tmp" "$WORK/l10-skipai/$RES"
  chk l10-skipai; expect_only l10-skipai SEC-L10 Low
  mk l10-bad; { echo '# some other file'; tail -n +2 "$FX/results/$RES"; } > "$WORK/l10-bad/$RES"; chk l10-bad; expect_only l10-bad SEC-L10 Low
  mk l10-noans; setrow l10-noans headers GET / 000 - && chk l10-noans && expect_only l10-noans SEC-L10 Low
  # the newest file for the target is read; other targets' files are not
  mk newest; sed 's/^canary\tPOST\t\/api\/chat\t401\t-$/canary\tPOST\t\/api\/chat\t200\tcanary=1/' "$FX/results/$RES" > "$WORK/newest/2026-11-01-local.tsv"
  sed 's/^unauth-write\tPOST\t\/api\/items\t401/unauth-write\tPOST\t\/api\/items\t200/' "$FX/results/$RES" > "$WORK/newest/2026-11-19-beta.tsv"
  chk newest; expect_pass newest
  run --target local --url http://127.0.0.1:8080 --today 2026-11-20 "$WORK/newest/2026-11-01-local.tsv"; expect_only file-given SEC-L7 High

  # maturity
  mk proto; setrow proto unauth-write POST /api/items 200 - && MATURITY=prototype chk proto
  if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^NOTE  SEC-L4 .*prototype: not rated'; then ok; else bad "prototype should note, not fail: $RC $(printf '%s\n' "$OUT" | grep -E '^(FAIL|NOTE)' | tr '\n' ';')"; fi

  # bad input
  run --target local "$WORK/good"; [ "$RC" -eq 2 ] && ok || bad "a missing --url should exit 2, got $RC"
  run --target 'lo cal' --url http://x "$WORK/good"; [ "$RC" -eq 2 ] && ok || bad "a --target with a space should exit 2, got $RC"
  chk good --threshold Severe; [ "$RC" -eq 2 ] && ok || bad "a bad --threshold should exit 2, got $RC"
  MATURITY=mvp chk good; [ "$RC" -eq 2 ] && ok || bad "a bad --maturity should exit 2, got $RC"
  TODAY=20-11-2026 chk good; [ "$RC" -eq 2 ] && ok || bad "a bad --today should exit 2, got $RC"
  chk good --max-age thirty; [ "$RC" -eq 2 ] && ok || bad "a non-numeric --max-age should exit 2, got $RC"
  chk good --zap "$WORK/no-such.json"; [ "$RC" -eq 2 ] && ok || bad "a missing --zap report should exit 2, got $RC"
  chk good --endpoint 'GET /x maybe -'; [ "$RC" -eq 2 ] && ok || bad "an --endpoint auth of maybe should exit 2, got $RC"
  chk good --endpoint 'GET /x'; [ "$RC" -eq 2 ] && ok || bad "an --endpoint with two fields should exit 2, got $RC"
  chk good "$WORK/good"; [ "$RC" -eq 2 ] && ok || bad "two results paths should exit 2, got $RC"
  chk good --colour; [ "$RC" -eq 2 ] && ok || bad "an unknown option should exit 2, got $RC"
  run --help; if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^Usage: check-live-results.sh'; then ok; else bad "--help should print usage and exit 0"; fi
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

printf "test-check-live-results: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
