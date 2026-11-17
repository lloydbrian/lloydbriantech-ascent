#!/usr/bin/env bash
# Behavior test for plugins/ascent-security/scripts/run-live-checks.sh.
#
# Starts the fixture target (fixtures/live/live-app.py) on 127.0.0.1 in each of its
# three modes and runs the script against it: the vulnerable target is caught by
# every probe, the hardened one by none, and the rate-limited one shows 429 in the
# burst. check-live-results.sh then rates each file (end to end). Also covers the
# refusals (a host not allowed, credentials in the URL, production, a non-loopback
# target inside Claude Code), skipped probes, the dry run, what the file never
# holds, and bad input. Every server it starts is stopped when it exits.
#
# Needs python3 for the fixture target and curl.
# Prints "test-run-live-checks: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; PIDS=""
cleanup() { for p in $PIDS; do kill "$p" 2>/dev/null; wait "$p" 2>/dev/null; done; rm -rf "$WORK"; }
trap cleanup EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
RUN="$HERE/../../../plugins/ascent-security/scripts/run-live-checks.sh"
CHECK="$HERE/../../../plugins/ascent-security/scripts/check-live-results.sh"
APP="$HERE/fixtures/live/live-app.py"
for f in "$RUN" "$CHECK" "$APP"; do [ -f "$f" ] || { echo "test-run-live-checks: missing $f"; echo "test-run-live-checks: 0/1 PASS"; exit 1; }; done
for t in python3 curl; do command -v "$t" >/dev/null 2>&1 || { echo "test-run-live-checks: $t not found"; echo "test-run-live-checks: 0/1 PASS"; exit 1; }; done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
has() { if printf '%s\n' "$2" | grep -qF -- "$3"; then ok; else bad "$1: lacks: $3"; fi; }
lacks() { if printf '%s\n' "$2" | grep -qF -- "$3"; then bad "$1: must not contain: $3"; else ok; fi; }
row() { awk -F'\t' -v p="$2" -v m="$3" -v pa="$4" '$1 == p && $2 == m && $3 == pa { print $4 "\t" $5; exit }' "$1"; }
start() {  # MODE: starts the fixture in this shell, so cleanup can stop it
  python3 -I "$APP" "$1" "$WORK/port-$1" >/dev/null 2>&1 & PIDS="$PIDS $!"
  local i=0; while [ ! -s "$WORK/port-$1" ] && [ $i -lt 100 ]; do sleep 0.1; i=$((i + 1)); done
  [ -s "$WORK/port-$1" ] || { echo "test-run-live-checks: the $1 fixture did not start"; echo "test-run-live-checks: 0/1 PASS"; exit 1; }
}
EPS=(--endpoint 'GET,DELETE /api/items/{id} required write' --endpoint 'POST /api/items required write' --endpoint 'POST /api/chat required ai' --endpoint 'GET /api/catalog none -')
live() {  # MODE OUT [ARGS] — run against the MODE fixture, RC and OUT set
  local mode="$1" out="$2"; shift 2
  (unset CLAUDECODE; bash "$RUN" --target local --url "http://127.0.0.1:$(cat "$WORK/port-$mode")" --today 2026-11-20 "${EPS[@]}" "$@" --out "$out") >"$WORK/o" 2>&1; RC=$?; OUT=$(cat "$WORK/o")
}
rate() {  # MODE FILE -> RC, OUT of check-live-results
  bash "$CHECK" --target local --url "http://127.0.0.1:$(cat "$WORK/port-$1")" --today 2026-11-20 "${EPS[@]}" "$2" >"$WORK/o" 2>&1; RC=$?; OUT=$(cat "$WORK/o")
}
refuse() {  # NAME EXPECTED-TEXT ARGS...
  local n="$1" t="$2"; shift 2
  (if [ -n "${IN_CLAUDE:-}" ]; then export CLAUDECODE=1; else unset CLAUDECODE; fi; bash "$RUN" "$@") >"$WORK/o" 2>&1; RC=$?; OUT=$(cat "$WORK/o")
  if [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -qF -- "$t"; then ok; else bad "$n: expected exit 2 and '$t', got $RC: $(head -c 200 "$WORK/o")"; fi
}

start vulnerable; start hardened; start ratelimited
V=$(cat "$WORK/port-vulnerable"); H=$(cat "$WORK/port-hardened")

# The vulnerable target: every probe catches it.
live vulnerable "$WORK/v.tsv" --allow-writes --allow-ai
[ "$RC" -eq 0 ] && ok || bad "vulnerable run should exit 0, got $RC: $OUT"
F="$WORK/v.tsv"
[ "$(head -n 1 "$F")" = '# ascent-live-results 1' ] && ok || bad "the file should open with '# ascent-live-results 1'"
has v-header "$(cat "$F")" "$(printf '# url\thttp://127.0.0.1:%s' "$V")"
has v-headers "$(row "$F" headers GET /)" 'missing=content-security-policy,x-content-type-options,frame-protection,referrer-policy,permissions-policy'
has v-banner "$(row "$F" headers GET /)" 'banner=server: Express/4.18.2'
has v-trace "$(row "$F" verb TRACE /)" "$(printf '200\techo=1')"
has v-connect "$(row "$F" verb CONNECT /api/catalog)" '200'
has v-traversal "$(row "$F" traversal GET '/api/items/..%2fetc%2fpasswd')" 'leak=1'
[ "$(awk -F'\t' '$1 == "traversal"' "$F" | wc -l | tr -d ' ')" = 6 ] && ok || bad "six traversal payloads for the one GET endpoint with a parameter"
has v-env "$(row "$F" disclosure GET /.env)" 'secret,env'
has v-git "$(row "$F" disclosure GET /.git/config)" 'git'
has v-unauth "$(row "$F" unauth-write DELETE /api/items/ascent-probe)" '200'
has v-unauth-post "$(row "$F" unauth-write POST /api/items)" '200'
lacks v-no-get-write "$(awk -F'\t' '$1 == "unauth-write" && $2 == "GET"' "$F")" 'GET'
has v-oversize "$(row "$F" oversize POST /api/items)" "$(printf '200\tbytes=1150991')"
has v-malformed "$(row "$F" malformed POST /api/items)" 'trace'
has v-canary "$(row "$F" canary POST /api/chat)" 'canary=1'
has v-burst "$(row "$F" burst POST /api/chat)" '200=10'
lacks v-no-body "$(cat "$F")" 'hunter22'
lacks v-no-key "$(cat "$F")" 'sk_live'
lacks v-no-passwd "$(cat "$F")" 'root:x:0:0'
rate vulnerable "$F"
[ "$RC" -eq 1 ] && ok || bad "the vulnerable results should fail check-live-results, got $RC"
for k in L1 L2 L3 L4 L5 L6 L7 L8; do has "v-rated-$k" "$OUT" "FAIL  SEC-$k "; done
has v-l10 "$OUT" 'PASS  SEC-L10'

# The hardened target: no probe catches it.
live hardened "$WORK/h.tsv" --allow-writes --allow-ai
F="$WORK/h.tsv"
has h-headers "$(row "$F" headers GET /)" "$(printf '200\t-')"
has h-trace "$(row "$F" verb TRACE /)" '405'
has h-unauth "$(row "$F" unauth-write DELETE /api/items/ascent-probe)" '401'
has h-oversize "$(row "$F" oversize POST /api/items)" '413'
has h-burst "$(row "$F" burst POST /api/chat)" '401=10'
rate hardened "$F"
if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 9 ]; then ok; else bad "the hardened results should pass 9 checks: $RC $(printf '%s\n' "$OUT" | grep -v '^PASS' | tr '\n' ';')"; fi

# The rate-limited target: the burst is limited, the canary refused.
live ratelimited "$WORK/r.tsv" --allow-ai
F="$WORK/r.tsv"
has r-burst "$(row "$F" burst POST /api/chat)" '200=2;429=8'
has r-canary "$(row "$F" canary POST /api/chat)" "$(printf '200\t-')"
has r-skipped "$(row "$F" unauth-write - -)" 'skipped=no --allow-writes'
rate ratelimited "$F"
has r-l8 "$OUT" 'PASS  SEC-L8'
has r-l10 "$OUT" 'FAIL  SEC-L10  Low'

# Without --allow-writes and --allow-ai nothing that writes or calls a model is sent.
live hardened "$WORK/s.tsv"
F="$WORK/s.tsv"
has s-writes "$(row "$F" oversize - -)" 'skipped=no --allow-writes'
has s-ai "$(row "$F" canary - -)" 'skipped=no --allow-ai'
lacks s-no-post "$(awk -F'\t' '$2 == "POST" || $2 == "DELETE"' "$F")" 'POST'

# The dry run sends nothing: it plans against a port nothing listens on.
(unset CLAUDECODE; bash "$RUN" --target local --url http://127.0.0.1:9 "${EPS[@]}" --allow-writes --allow-ai --dry-run) >"$WORK/o" 2>&1; RC=$?; OUT=$(cat "$WORK/o")
[ "$RC" -eq 0 ] && ok || bad "a dry run should exit 0, got $RC"
has dry-plan "$OUT" 'PLAN  DELETE  unauth-write'
has dry-nothing "$OUT" 'dry run, nothing sent'
[ "$(printf '%s\n' "$OUT" | grep -c '^PLAN  POST    burst')" = 10 ] && ok || bad "the dry run should plan 10 burst requests"

# Refusals.
refuse host-not-allowed 'is not an allowed host' --target beta --url https://beta.example.com --out "$WORK/x.tsv"
refuse host-other 'is not an allowed host' --target beta --url https://beta.example.com --allow-host other.example.com --dry-run
refuse creds 'must not hold credentials' --target local --url http://admin:pw@127.0.0.1:8080 --dry-run
refuse prod 'production target' --target prod --url http://127.0.0.1:8080 --dry-run
refuse prod-flag 'production target' --target live --url http://127.0.0.1:8080 --prod --dry-run
IN_CLAUDE=1 refuse claude 'inside Claude Code only loopback targets run' --target beta --url https://beta.example.com --allow-host beta.example.com --dry-run
(unset CLAUDECODE; bash "$RUN" --target beta --url https://beta.example.com --allow-host beta.example.com --dry-run) >"$WORK/o" 2>&1
[ $? -eq 0 ] && ok || bad "an allowed host outside Claude Code should plan: $(head -c 200 "$WORK/o")"
(unset CLAUDECODE; bash "$RUN" --target prod --url https://app.example.com --allow-host app.example.com --allow-prod --dry-run) >"$WORK/o" 2>&1
[ $? -eq 0 ] && ok || bad "a production target with --allow-prod should plan: $(head -c 200 "$WORK/o")"
(CLAUDECODE=1 bash "$RUN" --target local --url "http://localhost:$H" --dry-run) >"$WORK/o" 2>&1
[ $? -eq 0 ] && ok || bad "loopback inside Claude Code should plan: $(head -c 200 "$WORK/o")"
refuse ipv6-host 'is not an allowed host' --target x --url 'http://[fe80::1]:8080' --dry-run

# Bad input.
refuse no-out 'give --out FILE, or --dry-run' --target local --url http://127.0.0.1:8080
refuse scheme 'must start with http:// or https://' --target local --url ftp://127.0.0.1 --dry-run
refuse target-name 'must be letters' --target 'my target' --url http://127.0.0.1:8080 --dry-run
refuse ep-fields "must be 'METHODS PATH AUTH FLAGS'" --target local --url http://127.0.0.1:8080 --endpoint 'GET /x' --dry-run
refuse ep-auth 'auth must be required or none' --target local --url http://127.0.0.1:8080 --endpoint 'GET /x maybe -' --dry-run
refuse ep-flag 'flags are write, ai or -' --target local --url http://127.0.0.1:8080 --endpoint 'GET /x none admin' --dry-run
refuse ep-path 'path must start with /' --target local --url http://127.0.0.1:8080 --endpoint 'GET x none -' --dry-run
refuse ep-query "must not hold a tab, '?' or '#'" --target local --url http://127.0.0.1:8080 --endpoint 'GET /x?a=1 none -' --dry-run
refuse maxbody 'must be a number of bytes' --target local --url http://127.0.0.1:8080 --max-body 1mb --dry-run
refuse unknown 'unknown argument' --target local --url http://127.0.0.1:8080 --colour --dry-run
(bash "$RUN" --help) >"$WORK/o" 2>&1; if [ $? -eq 0 ] && grep -q '^Usage: run-live-checks.sh' "$WORK/o"; then ok; else bad "--help should print usage and exit 0"; fi

printf "test-run-live-checks: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
