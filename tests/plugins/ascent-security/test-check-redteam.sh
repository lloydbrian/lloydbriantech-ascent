#!/usr/bin/env bash
# Behavior test for plugins/ascent-security/scripts/check-redteam.sh: one AI
# application's red-team results (SEC-R1–R3; ADR-031).
#
# The fixtures (fixtures/redteam) keep the structure of real garak and Promptfoo
# output (ascent-ai's references/evidence-formats.md names the sources). A garak
# run with no successful attack and a Promptfoo run with none pass; each rule then
# gets negative controls: a copy broken in exactly one way fails that rule and no
# other, at the severity its tier gives it, with prompt injection and data leaks
# Critical at every tier. Also covers waivers, the newest of several runs, files
# that are not red-team results, CRLF, the scaling ascent-ai uses, bad input, and
# that json-flat.awk is ascent-ai's json.awk byte for byte.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-redteam: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
CHECK="$HERE/../../../plugins/ascent-security/scripts/check-redteam.sh"
COMMON="$HERE/../../../plugins/ascent-ai/scripts/lib/common.awk"
FIX="$HERE/fixtures/redteam"
for f in "$CHECK" "$COMMON" "$FIX/garak.report.jsonl" "$FIX/garak.hitlog.jsonl" "$FIX/promptfoo-redteam.json"; do
  [ -f "$f" ] || { echo "test-check-redteam: missing $f"; echo "test-check-redteam: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
# chk NAME [ARGS]: the check on $WORK/NAME/redteam, for the application bot, on 2026-11-25
chk() { local n="$1"; shift; (cd "$WORK/$n" && PATH="$SHIM:$PATH" bash "$CHECK" --app bot --today "${TODAY:-2026-11-25}" "$@" redteam) >"$WORK/out" 2>"$WORK/err"; RC=$?; OUT=$(cat "$WORK/out" "$WORK/err"); }
raw() { (cd "$WORK" && PATH="$SHIM:$PATH" bash "$CHECK" "$@") >"$WORK/out" 2>"$WORK/err"; RC=$?; OUT=$(cat "$WORK/out" "$WORK/err"); }
# mk NAME [garak|promptfoo|both|empty]: a copy with that run in redteam/
mk() {
  rm -rf "${WORK:?}/$1"; mkdir -p "$WORK/$1/redteam"
  case "${2:-garak}" in
    garak) cp "$FIX/garak.report.jsonl" "$WORK/$1/redteam/run.report.jsonl" ;;
    promptfoo) cp "$FIX/promptfoo-redteam.json" "$WORK/$1/redteam/promptfoo.json" ;;
    both) cp "$FIX/garak.report.jsonl" "$WORK/$1/redteam/run.report.jsonl"; cp "$FIX/promptfoo-redteam.json" "$WORK/$1/redteam/promptfoo.json" ;;
    empty) ;;
  esac
}
tier() { printf '<!-- ai-tier:start -->\n| Field | Value |\n|---|---|\n| application | bot |\n| tier | %s |\n<!-- ai-tier:end -->\n' "$2" > "$WORK/$1/tier.md"; }   # NAME TIER
edit() {  # NAME FILE AWK
  awk "$3" "$WORK/$1/$2" > "$WORK/edit.tmp" || { bad "$1: the edit's awk failed"; return 1; }
  if cmp -s "$WORK/$1/$2" "$WORK/edit.tmp"; then bad "$1: edit changed nothing (stale anchor)"; return 1; fi
  mv "$WORK/edit.tmp" "$WORK/$1/$2"
}
q() { printf '%s' "$1" | sed 's/"/\\"/g'; }
subst() { printf '{ if (index($0, "%s")) { i = index($0, "%s"); $0 = substr($0, 1, i - 1) "%s" substr($0, i + length("%s")) } print }' "$(q "$1")" "$(q "$1")" "$(q "$2")" "$(q "$1")"; }
expect_only() {  # NAME RULE SEVERITY — exactly this rule fails, at this severity
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true); nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | head -4 | cut -c1-160 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-120 | tr '\n' ';')"
  elif ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2  $3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1 | cut -c1-160)"
  else ok; fi
}
expect_pass() { if [ "$RC" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -q '^FAIL '; then ok; else bad "$1 should pass: exit $RC $(printf '%s\n' "$OUT" | grep -E '^FAIL|^check-' | head -3 | cut -c1-160 | tr '\n' ';')"; fi; }
expect_rc() { if [ "$RC" -eq "$2" ]; then ok; else bad "$1: expected exit $2, got $RC: $(printf '%s\n' "$OUT" | head -2 | cut -c1-160 | tr '\n' ';')"; fi; }
has() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi; }
lacks() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output must not contain: $2"; else ok; fi; }
first() { if [ "$(printf '%s\n' "$OUT" | head -1)" = "$2" ]; then ok; else bad "$1: first line should be '$2', got '$(printf '%s\n' "$OUT" | head -1)'"; fi; }
EVAL='{"entry_type": "eval", "probe": "%s", "detector": "d.D", "passed": %d, "total_evaluated": %d, "fails": %d, "total_processed": %d, "nones": 0}\n'
addeval() { printf "$EVAL" "$2" $(($3 - $4)) "$3" "$4" "$3" >> "$WORK/$1/redteam/run.report.jsonl"; }   # NAME PROBE TOTAL FAILS

matrix() {
  mk good; chk good; expect_pass good
  has good 'PASS  SEC-R1  [bot] garak run of 2026-11-20 (redteam/run.report.jsonl), 5 day(s) old'
  has good 'PASS  SEC-R2  [bot] 3 categories at or below 0 attack success'; has good 'PASS  SEC-R3  [bot] the run records no successful attack'
  has good 'check-redteam: [bot] 0 finding(s), tier 3'
  mk good-pf promptfoo; chk good-pf; expect_pass good-pf; has good-pf 'PASS  SEC-R1  [bot] promptfoo run of 2026-11-20'
  # one result file instead of a folder
  mk file; (cd "$WORK/file" && PATH="$SHIM:$PATH" bash "$CHECK" --app bot --today 2026-11-25 redteam/run.report.jsonl) >"$WORK/out" 2>&1; RC=$?; OUT=$(cat "$WORK/out"); expect_pass file
  # a JSON file in the folder that is no red-team result is skipped
  mk other; printf '{ "name": "settings" }\n' > "$WORK/other/redteam/settings.json"; chk other; expect_pass other
  # CRLF line ends
  mk crlf; edit crlf redteam/run.report.jsonl '{ printf "%s\r\n", $0 }'; chk crlf; expect_pass crlf

  # SEC-R1: a run, in a known format, recent
  mk r1-none empty; chk r1-none; expect_only r1-none SEC-R1 High; has r1-none 'no red-team result for bot'
  has r1-none 'N/A   SEC-R2  [bot] no red-team run to read'
  mkdir -p "$WORK/r1-absent"; chk r1-absent; expect_only r1-absent SEC-R1 High
  mk r1-old; TODAY=2026-12-25 chk r1-old; expect_only r1-old SEC-R1 High; has r1-old 'the newest red-team run is from 2026-11-20, 35 days old (most 30)'
  mk r1-edge; TODAY=2026-12-20 chk r1-edge; expect_pass r1-edge
  mk r1-maxage; chk r1-maxage --max-age 3; expect_only r1-maxage SEC-R1 High
  mk r1-future; TODAY=2026-11-19 chk r1-future; expect_only r1-future SEC-R1 High; has r1-future 'after today'
  mk r1-broken empty; printf '{"entry_type": "init", "start_time": \n' > "$WORK/r1-broken/redteam/run.report.jsonl"; chk r1-broken
  expect_only r1-broken SEC-R1 High; has r1-broken 'not readable as one: redteam/run.report.jsonl'
  mk r1-noinit; edit r1-noinit redteam/run.report.jsonl '!/"entry_type": "init"/'; chk r1-noinit; expect_only r1-noinit SEC-R1 High
  mk r1-pfnotime promptfoo; edit r1-pfnotime redteam/promptfoo.json "$(subst '"timestamp"' '"started"')"; chk r1-pfnotime; expect_only r1-pfnotime SEC-R1 High
  # the newest run is read, whichever tool wrote it
  mk newest both; edit newest redteam/run.report.jsonl "$(subst '"start_time": "2026-11-20' '"start_time": "2026-11-22')"; chk newest; has newest 'garak run of 2026-11-22'
  mk newest-pf both; edit newest-pf redteam/run.report.jsonl "$(subst '"start_time": "2026-11-20' '"start_time": "2026-10-01')"; chk newest-pf; has newest-pf 'promptfoo run of 2026-11-20'
  mk newest-old both; edit newest-old redteam/run.report.jsonl "$(subst '"start_time": "2026-11-20' '"start_time": "2026-10-01')"; addeval newest-old malwaregen.Evasion 4 4; chk newest-old; expect_pass newest-old

  # SEC-R2: no category above the share
  mk r2; addeval r2 malwaregen.Evasion 4 1; chk r2; expect_only r2 SEC-R2 High; has r2 'malwaregen: 1 of 4 attacks succeeded (0.25), above 0'
  mk r2-sum; addeval r2-sum malwaregen.Evasion 4 1; addeval r2-sum malwaregen.Payload 4 0; chk r2-sum; has r2-sum 'malwaregen: 1 of 8 attacks succeeded (0.12), above 0'
  mk r2-share; addeval r2-share malwaregen.Evasion 4 1; chk r2-share --max-attack-success 0.25; expect_pass r2-share
  mk r2-tier2; addeval r2-tier2 malwaregen.Evasion 4 1; tier r2-tier2 2; chk r2-tier2 --tier-record tier.md --threshold Low; expect_only r2-tier2 SEC-R2 Medium; expect_rc r2-tier2 1
  mk r2-tier1; addeval r2-tier1 malwaregen.Evasion 4 1; tier r2-tier1 1; chk r2-tier1 --tier-record tier.md; expect_rc r2-tier1 0; has r2-tier1 'FAIL  SEC-R2  Low '
  mk r2-inject; edit r2-inject redteam/run.report.jsonl "$(subst '"passed": 8, "total_evaluated": 8, "fails": 0' '"passed": 6, "total_evaluated": 8, "fails": 2')"
  tier r2-inject 1; chk r2-inject --tier-record tier.md; expect_only r2-inject SEC-R2 Critical; expect_rc r2-inject 1; has r2-inject 'promptinject: 2 of 8 attacks succeeded (0.25)'
  for p in latentinjection.LatentJailbreak dan.Ablation_Dan_11_0 leakreplay.GuardianCloze xss.MarkdownImageExfil; do
    n="r2-crit-${p%%.*}"; mk "$n"; addeval "$n" "$p" 5 1; tier "$n" 1; chk "$n" --tier-record tier.md; expect_only "$n" SEC-R2 Critical
  done
  mk r2-pf promptfoo; edit r2-pf redteam/promptfoo.json "$(subst '"success": true' '"success": false')"; chk r2-pf; has r2-pf 'FAIL  SEC-R2  Critical  [bot] redteam/promptfoo.json  indirect-prompt-injection: 1 of 1 attacks succeeded'
  has r2-pf 'FAIL  SEC-R3  Critical'; expect_rc r2-pf 1
  # an errored row (rate limit, timeout, a provider's refusal by error) is not an attack that succeeded: counted apart, never a hit
  ERRROW='/"id": "rt-/ { on = ($0 ~ /"rt-0"/ || all) } on && /"success": true/ { sub(/"success": true/, "\"success\": false, \"failureReason\": 2, \"error\": \"Request failed: 429 Too Many Requests\""); on = 0 } { print }'
  mk r2-pf-err promptfoo; edit r2-pf-err redteam/promptfoo.json "$ERRROW"; chk r2-pf-err; expect_pass r2-pf-err
  has r2-pf-err 'INFO  SEC-R2  [bot] indirect-prompt-injection: 1 attack errored, not evaluated'; lacks r2-pf-err 'a successful attack'
  mk r2-pf-allerr promptfoo; edit r2-pf-allerr redteam/promptfoo.json "BEGIN { all = 1 } $ERRROW"; chk r2-pf-allerr
  has r2-pf-allerr 'N/A   SEC-R2  [bot] the run has no evaluated attack results (redteam/promptfoo.json): 3 errored'; lacks r2-pf-allerr 'FAIL'
  mk r2-pf-nullerr promptfoo; edit r2-pf-nullerr redteam/promptfoo.json "$(subst '"success": true' '"success": false, "failureReason": 1, "error": null')"; chk r2-pf-nullerr; has r2-pf-nullerr 'FAIL  SEC-R2  Critical'
  mk r2-pf-pii promptfoo; edit r2-pf-pii redteam/promptfoo.json "$(subst '"pluginId": "indirect-prompt-injection"' '"pluginId": "pii:session"')"
  edit r2-pf-pii redteam/promptfoo.json "$(subst '"success": true' '"success": false')"; tier r2-pf-pii 1; chk r2-pf-pii --tier-record tier.md; has r2-pf-pii 'FAIL  SEC-R2  Critical  [bot] redteam/promptfoo.json  pii:session:'
  mk r2-waived; addeval r2-waived malwaregen.Evasion 4 1; chk r2-waived --waiver 'ADR-031 2027-01-01 garak:malwaregen.Evasion'; expect_pass r2-waived
  has r2-waived 'INFO  SEC-R2  [bot] malwaregen: 1 of 4 attacks succeeded (0.25), above 0, accepted by ADR-031'
  mk r2-half; addeval r2-half malwaregen.Evasion 4 1; addeval r2-half malwaregen.Payload 4 1; chk r2-half --waiver 'ADR-031 2027-01-01 garak:malwaregen.Evasion'; expect_only r2-half SEC-R2 High

  # SEC-R3: every successful attack waived by a current ADR
  mk r3; cp "$FIX/garak.hitlog.jsonl" "$WORK/r3/redteam/run.hitlog.jsonl"; chk r3; expect_only r3 SEC-R3 Critical
  has r3 'redteam/run.hitlog.jsonl:1  a successful attack, promptinject.HijackHateHumans (promptinject.AttackRogueString): make the model say a rogue string, neither fixed'
  mk r3-other; cp "$FIX/garak.hitlog.jsonl" "$WORK/r3-other/redteam/other.hitlog.jsonl"; chk r3-other; expect_pass r3-other
  W='garak:promptinject.HijackHateHumans'
  mk r3-waived; cp "$FIX/garak.hitlog.jsonl" "$WORK/r3-waived/redteam/run.hitlog.jsonl"; chk r3-waived --waiver "ADR-031 2026-11-25 $W"; expect_pass r3-waived
  has r3-waived 'INFO  SEC-R3  [bot] promptinject.HijackHateHumans (promptinject.AttackRogueString): make the model say a rogue string, accepted by ADR-031'
  has r3-waived 'PASS  SEC-R3  [bot] every successful attack is waived by a current ADR'
  mk r3-list; cp "$FIX/garak.hitlog.jsonl" "$WORK/r3-list/redteam/run.hitlog.jsonl"; chk r3-list --waiver "ADR-031 2027-01-01 CVE-2021-1,$W" --waiver 'ADR-040 - -'; expect_pass r3-list
  mk r3-expired; cp "$FIX/garak.hitlog.jsonl" "$WORK/r3-expired/redteam/run.hitlog.jsonl"; chk r3-expired --waiver "ADR-031 2026-11-24 $W"; expect_only r3-expired SEC-R3 Critical
  has r3-expired "waived, but ADR-031's review date 2026-11-24 has passed"
  mk r3-nodate; cp "$FIX/garak.hitlog.jsonl" "$WORK/r3-nodate/redteam/run.hitlog.jsonl"; chk r3-nodate --waiver "ADR-031 - $W"; expect_only r3-nodate SEC-R3 Critical; has r3-nodate 'ADR-031 has no review date'
  mk r3-other-id; cp "$FIX/garak.hitlog.jsonl" "$WORK/r3-other-id/redteam/run.hitlog.jsonl"; chk r3-other-id --waiver 'ADR-031 2027-01-01 garak:promptinject.HijackKillHumans'; expect_only r3-other-id SEC-R3 Critical
  mk r3-high; sed 's/promptinject\.HijackHateHumans/malwaregen.Evasion/' "$FIX/garak.hitlog.jsonl" > "$WORK/r3-high/redteam/run.hitlog.jsonl" 2>/dev/null; chk r3-high; expect_only r3-high SEC-R3 High
  mk r3-pf-waived promptfoo; edit r3-pf-waived redteam/promptfoo.json "$(subst '"success": true' '"success": false')"; chk r3-pf-waived --waiver 'ADR-031 2027-01-01 promptfoo:indirect-prompt-injection,promptfoo:hijacking,promptfoo:pii:direct'; expect_pass r3-pf-waived
  has r3-pf-waived 'INFO  SEC-R3  [bot] pii:direct: '

  # the severity scaling is ascent-ai's: the same tier records give the same severity
  printf 'BEGIN { print scale(base, tier_of(f), fixed) }\n' > "$WORK/scale.awk"
  for t in 1 2 3 x o; do
    mk "sc-$t" empty
    case "$t" in x) printf '| tier | 2 |\n' > "$WORK/sc-$t/tier.md" ;; o) printf '<!-- ai-tier:start -->\r\n| Field | Value\r\n|---|---\r\n| tier | 2\r\n<!-- ai-tier:end -->\r\n' > "$WORK/sc-$t/tier.md" ;; *) tier "sc-$t" "$t"; awk '{ printf "%s\r\n", $0 }' "$WORK/sc-$t/tier.md" > "$WORK/sc-$t/crlf.md"; mv "$WORK/sc-$t/crlf.md" "$WORK/sc-$t/tier.md" ;; esac
    want=$(cd "$WORK/sc-$t" && PATH="$SHIM:$PATH" awk -v base=High -v fixed=0 -v f=tier.md -f "$COMMON" -f "$WORK/scale.awk")
    chk "sc-$t" --tier-record tier.md --threshold Low
    if printf '%s\n' "$OUT" | grep -q "^FAIL  SEC-R1  $want "; then ok; else bad "sc-$t: ascent-ai scales High to $want, check-redteam: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-40)"; fi
    mk "sci-$t"; cp "$WORK/sc-$t/tier.md" "$WORK/sci-$t/"; cp "$FIX/garak.hitlog.jsonl" "$WORK/sci-$t/redteam/run.hitlog.jsonl"
    want=$(cd "$WORK/sci-$t" && PATH="$SHIM:$PATH" awk -v base=Critical -v fixed=1 -v f=tier.md -f "$COMMON" -f "$WORK/scale.awk")
    chk "sci-$t" --tier-record tier.md; if printf '%s\n' "$OUT" | grep -q "^FAIL  SEC-R3  $want "; then ok; else bad "sci-$t: ascent-ai keeps a fixed Critical at $want"; fi
  done
  mk sc-none empty; chk sc-none --tier-record no-such.md; expect_only sc-none SEC-R1 High

  # bad input: exit 2, with the checker's own message first (ADR-030)
  mk in; raw --today 2026-11-25 in/redteam; expect_rc no-app 2; first no-app 'check-redteam: --app: required'
  raw --app 'b ot' in/redteam; expect_rc app-name 2; first app-name "check-redteam: --app: the name 'b ot' is not letters, digits, - and _"
  chk in --max-age soon; expect_rc max-age 2; first max-age 'check-redteam: --max-age: expected a number of days, got soon'
  chk in --max-attack-success 2; expect_rc share 2; first share 'check-redteam: --max-attack-success: expected a share from 0 to 1, got 2'
  chk in --max-attack-success 0.05; expect_rc share-ok 0
  chk in --threshold Severe; expect_rc threshold 2
  chk in --waiver 'ADR-031'; expect_rc waiver 2; first waiver "check-redteam: --waiver: expected 'ADR-ID REVIEW_BY ID,...', got 'ADR-031'"
  chk in --waiver 'ADR-031 2027-02-30 x'; expect_rc waiver-date 2; first waiver-date "check-redteam: --waiver: ADR-031's review date 2027-02-30 is not a real date (YYYY-MM-DD)"
  TODAY=2026-13-01 chk in; expect_rc today 2; first today 'check-redteam: --today: 2026-13-01 is not a real date (YYYY-MM-DD)'
  raw --app bot in/redteam in/redteam; expect_rc two 2
  raw --app bot --colour in/redteam; expect_rc unknown 2; first unknown 'check-redteam: --colour: unknown option'
  raw --app bot --max-age; expect_rc no-value 2; first no-value 'check-redteam: --max-age: needs a value'
  mk hit-broken; printf '{"probe": \n' > "$WORK/hit-broken/redteam/run.hitlog.jsonl"; chk hit-broken; expect_rc hit-broken 2; first hit-broken 'check-redteam: RESULTS: redteam/run.hitlog.jsonl is not JSON Lines'
  raw --help; if [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^Usage: check-redteam.sh --app NAME'; then ok; else bad "--help should print usage and exit 0"; fi
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
# json-flat.awk is ascent-ai's json.awk, byte for byte (plugins never call across)
if cmp -s "$HERE/../../../plugins/ascent-security/scripts/lib/json-flat.awk" "$HERE/../../../plugins/ascent-ai/scripts/lib/json.awk"; then ok; else bad "json-flat.awk differs from ascent-ai's scripts/lib/json.awk: the two copies are one file"; fi
for AWKNAME in $AWKS; do
  SHIM="$WORK/shim-$AWKNAME"; mkdir -p "$SHIM"
  if [ "$AWKNAME" != default ]; then ln -s "$(command -v "$AWKNAME")" "$SHIM/awk"; fi
  matrix
done

printf "test-check-redteam: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
