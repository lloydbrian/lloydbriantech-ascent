#!/usr/bin/env bash
# Behavior test for plugins/ascent-quality/scripts/check-test-evidence.sh.
#
# The good fixture (a k6 script, an Artillery file and a Locust file aligned with a
# 500 ms p95 target and 50 rps; Stryker with a break threshold of 70, run by CI; a
# dated Stryker report scoring 75%) passes all nine checks. Each check then gets
# negative controls: a copy broken in exactly one way fails that check and no
# other. Also covers thresholds on several lines, tagged thresholds, rates per
# minute, Locust users from CI, PIT, gremlins, mutmut and go-mutesting, text
# summaries, report dates, maturity levels and bad input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-test-evidence: N/N PASS" last (make/test-plugins.sh T11
# requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-quality"
CHECK="$PLUGIN/scripts/check-test-evidence.sh"
GOOD="$HERE/fixtures/evidence-good"
for f in "$CHECK" "$GOOD/load/checkout.js" "$GOOD/stryker.conf.json"; do [ -f "$f" ] || { echo "test-check-test-evidence: missing $f"; echo "test-check-test-evidence: 0/1 PASS"; exit 1; }; done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  [%s] %s\n" "$AWKNAME" "$1"; }
# run DIR [OPTIONS] — the check with the fixture's targets, from DIR. OPTS replaces
# the default options.
run() {
  local d="$1"; shift
  # shellcheck disable=SC2086
  (cd "$d" || exit 2; PATH="$SHIM:$PATH" bash "$CHECK" ${OPTS:---p95 500 --rps 50 --min-score 70 --today 2026-11-01} "$@" . </dev/null) >"$WORK/out" 2>"$WORK/err"; RC=$?
  OUT=$(cat "$WORK/out" "$WORK/err")
}
mk() { rm -rf "${WORK:?}/$1"; cp -R "$GOOD" "$WORK/$1"; }
q() { printf '%s' "$1" | sed 's/"/\\"/g'; }
subst() { printf '{ if (index($0, "%s")) { i = index($0, "%s"); $0 = substr($0, 1, i - 1) "%s" substr($0, i + length("%s")) } print }' "$(q "$1")" "$(q "$1")" "$(q "$2")" "$(q "$1")"; }
drop()  { printf 'index($0, "%s") { next } { print }' "$(q "$1")"; }
edit() {
  awk "$3" "$WORK/$1/$2" > "$WORK/edit.tmp"
  if cmp -s "$WORK/$1/$2" "$WORK/edit.tmp"; then bad "$1: edit of $2 changed nothing (stale anchor)"; return 1; fi
  mv "$WORK/edit.tmp" "$WORK/$1/$2"
}
add() { mkdir -p "$(dirname "$WORK/$1/$2")"; printf '%b\n' "$3" > "$WORK/$1/$2"; }
# only NAME KEEP — a copy with one load tool: k6, artillery or locust.
only() {
  mk "$1"
  case "$2" in
    k6) rm -f "$WORK/$1/load/browse.yml" "$WORK/$1/load/locustfile.py" ;;
    artillery) rm -f "$WORK/$1/load/checkout.js" "$WORK/$1/load/locustfile.py" ;;
    locust) rm -f "$WORK/$1/load/checkout.js" "$WORK/$1/load/browse.yml" ;;
  esac
}
expect_only() {  # NAME CHECK [SEVERITY]
  run "$WORK/$1"
  nfail=$(printf '%s\n' "$OUT" | grep -c '^FAIL ' || true)
  nmine=$(printf '%s\n' "$OUT" | grep -c "^FAIL  $2 " || true)
  if [ "$RC" -ne 1 ]; then bad "$1: expected exit 1, got $RC: $(printf '%s\n' "$OUT" | grep -E '^FAIL|check-test-evidence:' | head -3 | tr '\n' ';')"
  elif [ "$nmine" -eq 0 ]; then bad "$1: $2 did not fail: $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"
  elif [ "$nfail" -ne "$nmine" ]; then bad "$1: expected only $2 to fail, got: $(printf '%s\n' "$OUT" | grep '^FAIL' | cut -c1-90 | tr '\n' ';')"
  elif [ -n "${3:-}" ] && ! printf '%s\n' "$OUT" | grep -q "^FAIL  $2 *$3 "; then bad "$1: $2 should be $3: $(printf '%s\n' "$OUT" | grep "^FAIL  $2" | head -1)"
  else ok; fi
}
expect_pass() {  # NAME WHY
  run "$WORK/$1"
  if [ "$RC" -eq 0 ]; then ok; else bad "$1 should pass ($2): $(printf '%s\n' "$OUT" | grep '^FAIL' | head -2 | tr '\n' ';')"; fi
}
expect_rc2() {  # NAME WHY OPTION...
  local n="$1" why="$2"; shift 2
  OPTS="--today 2026-11-01" run "$GOOD" "$@"
  if [ "$RC" -eq 2 ]; then ok; else bad "$n should exit 2 ($why), got $RC"; fi
}
has_line() { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then ok; else bad "$1: output lacks: $2"; fi; }
lacks()    { if printf '%s\n' "$OUT" | grep -qF -- "$2"; then bad "$1: output should not hold: $2"; else ok; fi; }

matrix() {
  run "$GOOD"
  if [ "$RC" -eq 0 ] && [ "$(printf '%s\n' "$OUT" | grep -c '^PASS ')" -eq 9 ]; then ok
  else bad "good fixture should pass all 9: exit $RC $(printf '%s\n' "$OUT" | grep -vE '^PASS' | tr '\n' ';')"; fi
  has_line good 'check-test-evidence: 3 load script(s) (k6 1, Artillery 1, Locust 1), 1 mutation tool(s), 1 report(s), 0 failure(s)'

  # QA-L1 — no load test, with a target
  mk l1;          rm -rf "$WORK/l1/load"; expect_only l1 QA-L1 Medium
  has_line l1 'no load-test script (k6, Artillery or Locust), and the contract sets p95_latency_ms 500 and peak_rps 50'
  mk l1-none;     rm -rf "$WORK/l1-none/load"; OPTS="--min-score 70 --today 2026-11-01" expect_pass l1-none 'no target, so no load test is required'
  has_line l1-none 'N/A   QA-L1   a load test exists for the latency and throughput targets (no p95_latency_ms or peak_rps target given)'
  mk l1-p95;      rm -rf "$WORK/l1-p95/load"; OPTS="--p95 500 --min-score 70 --today 2026-11-01" expect_only l1-p95 QA-L1
  has_line l1-p95 'and the contract sets p95_latency_ms 500'
  # QA-L2 — the p95 threshold
  only l2 k6;     edit l2 load/checkout.js "$(subst "['p(95)<400', 'p(99)<1200']" "['p(95)<900', 'p(99)<1200']")" && expect_only l2 QA-L2 Medium
  has_line l2 'the tightest p95 threshold is 900 ms, looser than p95_latency_ms 500'
  has_line l2 'load/checkout.js:16'
  only l2-tag k6; edit l2-tag load/checkout.js "$(drop "http_req_duration: ['p(95)<400'")" && expect_pass l2-tag 'the tagged threshold (450) is used when no untagged one exists'
  only l2-tagloose k6; edit l2-tagloose load/checkout.js "$(drop "http_req_duration: ['p(95)<400'")" && edit l2-tagloose load/checkout.js "$(subst "['p(95)<450']" "['p(95)<700']")" && expect_only l2-tagloose QA-L2
  has_line l2-tagloose 'the tightest p95 threshold is 700 ms'
  only l2-untag k6; edit l2-untag load/checkout.js "$(subst "['p(95)<400', 'p(99)<1200']" "['p(95)<800']")" && edit l2-untag load/checkout.js "$(subst "['p(95)<450']" "['p(95)<300']")" && expect_only l2-untag QA-L2
  has_line l2-untag 'the tightest p95 threshold is 800 ms'
  only l2-multi k6; edit l2-multi load/checkout.js "$(subst "http_req_duration: ['p(95)<400', 'p(99)<1200']," "http_req_duration: [\n      'p(99)<1200',\n      'p(95)<400',\n    ],")" && edit l2-multi load/checkout.js "$(drop "'http_req_duration{name:pay}'")" && expect_pass l2-multi 'a threshold array over several lines'
  only l2-tags k6; edit l2-tags load/checkout.js "$(drop "http_req_duration: ['p(95)<400'")" && edit l2-tags load/checkout.js "$(subst "    http_req_failed:" "    'http_req_duration{name:browse}': ['p(95)<900'],\n    http_req_failed:")" && expect_only l2-tags QA-L2
  has_line l2-tags 'the tightest p95 threshold is 900 ms'
  only l2-none k6; edit l2-none load/checkout.js "$(drop "p(95)")" && expect_only l2-none QA-L2
  has_line l2-none 'no load test sets a p95 latency threshold, so a slow run passes'
  only l2-art artillery; edit l2-art load/browse.yml "$(subst 'p95: 450' 'p95: 650')" && expect_only l2-art QA-L2
  has_line l2-art 'the tightest p95 threshold is 650 ms'
  only l2-artexpr artillery; edit l2-artexpr load/browse.yml "$(subst '- http.response_time.p95: 450' '- expression: "http.response_time.p95 < 480"')" && expect_pass l2-artexpr 'an Artillery condition expression'
  only l2-loc locust; edit l2-loc load/locustfile.py "$(subst 'get_response_time_percentile(0.95) > 500' 'get_response_time_percentile(0.95) > 1500')" && expect_only l2-loc QA-L2
  has_line l2-loc 'the tightest p95 threshold is 1500 ms'
  mk l2-best;     edit l2-best load/browse.yml "$(subst 'p95: 450' 'p95: 650')" && expect_pass l2-best 'one load test meeting the target is enough'
  # QA-L3 — the request rate
  only l3 k6;     edit l3 load/checkout.js "$(subst 'rate: 60,' 'rate: 30,')" && expect_only l3 QA-L3 Medium
  has_line l3 'the highest request rate is 30/s, below peak_rps 50'
  only l3-min k6; edit l3-min load/checkout.js "$(subst 'rate: 60,' 'rate: 3000,')" && edit l3-min load/checkout.js "$(subst "timeUnit: '1s'" "timeUnit: '1m'")" && expect_pass l3-min '3000 a minute is 50 a second'
  has_line l3-min 'PASS  QA-L3'
  only l3-min2 k6; edit l3-min2 load/checkout.js "$(subst 'rate: 60,' 'rate: 600,')" && edit l3-min2 load/checkout.js "$(subst "timeUnit: '1s'" "timeUnit: '1m'")" && expect_only l3-min2 QA-L3
  has_line l3-min2 'the highest request rate is 10/s'
  only l3-vus k6; edit l3-vus load/checkout.js "$(subst "executor: 'constant-arrival-rate'," "executor: 'constant-vus', vus: 100,")" && expect_pass l3-vus 'virtual users are a NOTE, not a failure'
  has_line l3-vus 'NOTE  QA-L3'
  lacks l3-vus 'PASS  QA-L3'
  only l3-art artillery; edit l3-art load/browse.yml "$(subst 'rampTo: 55' 'rampTo: 45')" && expect_only l3-art QA-L3
  has_line l3-art 'the highest request rate is 45/s'
  only l3-loc locust; edit l3-loc locust.conf "$(subst 'users = 50' 'users = 40')" && expect_only l3-loc QA-L3
  has_line l3-loc 'the highest request rate is 40/s'
  only l3-locci locust; edit l3-locci locust.conf "$(drop 'users = 50')" && edit l3-locci .github/workflows/ci.yml "$(subst '      - run: npm test' '      - run: npm test\n      - run: locust -f load/locustfile.py --headless -u 60 -r 10')" && expect_pass l3-locci 'users from a CI command line'
  has_line l3-locci 'PASS  QA-L3'
  only l3-pace locust; edit l3-pace load/locustfile.py "$(subst 'constant_throughput(1)' 'constant_pacing(0.5)')" && expect_pass l3-pace 'a request every 0.5 s is two a second per user'
  has_line l3-pace 'PASS  QA-L3'
  # QA-L4 — an error-rate threshold
  mk l4;          edit l4 load/checkout.js "$(drop 'http_req_failed')" && edit l4 load/browse.yml "$(drop 'maxErrorRate')" && edit l4 load/locustfile.py "$(subst 'fail_ratio > 0.01' 'avg_response_time > 900')" && expect_only l4 QA-L4 Low
  has_line l4 'no load test sets an error-rate threshold'
  has_line l4 'load/browse.yml:1'
  only l4-checks k6; edit l4-checks load/checkout.js "$(subst "http_req_failed: ['rate<0.01']" "checks: ['rate>0.99']")" && expect_pass l4-checks 'a checks rate threshold'
  # QA-L5 — something runs the load test
  mk l5;          rm -f "$WORK/l5/Makefile" "$WORK/l5/docs/load-tests.md"; expect_only l5 QA-L5 Low
  has_line l5 'no CI step, make target or runbook runs the load test'
  mk l5-doc;      rm -f "$WORK/l5-doc/Makefile"; expect_pass l5-doc 'a runbook runs the load test'
  mk l5-ci;       rm -f "$WORK/l5-ci/Makefile" "$WORK/l5-ci/docs/load-tests.md"; edit l5-ci .github/workflows/ci.yml "$(subst '      - run: npm test' '      - run: npm test\n      - uses: grafana/run-k6-action@v1')" && expect_pass l5-ci 'the k6 GitHub action'
  mk l5-pkg;      rm -f "$WORK/l5-pkg/Makefile" "$WORK/l5-pkg/docs/load-tests.md"; edit l5-pkg package.json "$(subst '"mutate": "stryker run"' '"mutate": "stryker run",\n    "load": "k6 run load/checkout.js"')" && expect_pass l5-pkg 'a package script'
  # QA-M1 — a mutation tool
  mk m1;          rm -f "$WORK/m1/stryker.conf.json"; edit m1 package.json "$(drop '@stryker-mutator/core')" && edit m1 package.json "$(subst '"devDependencies": {' '"devDependencies": {\n    "eslint": "9.0.0"')" && edit m1 .github/workflows/ci.yml "$(drop 'npm run mutate')" && edit m1 package.json "$(subst '"node --test tests/",' '"node --test tests/"')" && edit m1 package.json "$(drop 'stryker run')" && rm -rf "$WORK/m1/reports" && expect_only m1 QA-M1 Medium
  has_line m1 'no mutation tool configured (Stryker, mutmut, PIT, go-mutesting or gremlins)'
  mk m1-src;      rm -rf "$WORK/m1-src/src" "$WORK/m1-src/tests" "$WORK/m1-src/load" "$WORK/m1-src/stryker.conf.json" "$WORK/m1-src/reports" "$WORK/m1-src/package.json" "$WORK/m1-src/.github"; OPTS="--today 2026-11-01" expect_pass m1-src 'no source, no tool needed'
  has_line m1-src 'N/A   QA-M1   a mutation tool is configured (no source or test files)'
  # QA-M2 — the break threshold
  mk m2;          edit m2 stryker.conf.json "$(subst ', "break": 70' '')" && expect_only m2 QA-M2 Medium
  has_line m2 'stryker: no break threshold, so the mutation run passes at any score (min_score 70)'
  mk m2-low;      edit m2-low stryker.conf.json "$(subst '"break": 70' '"break": 50')" && expect_only m2-low QA-M2
  has_line m2-low 'stryker: the break threshold 50 is below min_score 70'
  has_line m2-low 'stryker.conf.json:6'
  # QA-M3 — CI runs the tool
  mk m3;          edit m3 .github/workflows/ci.yml "$(drop 'npm run mutate')" && edit m3 .github/workflows/ci.yml "$(drop 'Mutation testing')" && expect_only m3 QA-M3 Low
  has_line m3 'no CI step runs the mutation tool (stryker)'
  mk m3-make;     edit m3-make .github/workflows/ci.yml "$(drop 'npm run mutate')" && edit m3-make .github/workflows/ci.yml "$(drop 'Mutation testing')" && printf 'mutate:\n\tnpx stryker run\n' >> "$WORK/m3-make/Makefile" && expect_only m3-make QA-M3
  mk m3-viamake;  edit m3-viamake .github/workflows/ci.yml "$(subst 'run: npm run mutate' 'run: make mutate')" && printf 'mutate:\n\tnpx stryker run\n' >> "$WORK/m3-viamake/Makefile" && expect_pass m3-viamake 'CI runs a make target that runs Stryker'
  # QA-M4 — the committed report
  mk m4;          OPTS="--p95 500 --rps 50 --min-score 70 --today 2027-03-01" expect_only m4 QA-M4 Medium
  has_line m4 'the newest report, 2026-10-28, is 124 days old (max_age_days 90)'
  mk m4-age;      OPTS="--p95 500 --rps 50 --min-score 70 --max-age 180 --today 2027-03-01" expect_pass m4-age '--max-age 180'
  mk m4-low;      edit m4-low reports/mutation/2026-10-28-mutation.json "$(subst '"status":"Killed"},{"id":"2"' '"status":"Survived"},{"id":"2"')" && edit m4-low reports/mutation/2026-10-28-mutation.json "$(subst '"status":"Killed"},{"id":"3"' '"status":"Survived"},{"id":"3"')" && expect_only m4-low QA-M4
  has_line m4-low 'the newest report scores 58.3%, below min_score 70'
  mk m4-none;     rm -rf "$WORK/m4-none/reports"; expect_only m4-none QA-M4
  has_line m4-none 'no mutation report in the repository'
  mk m4-undated;  mv "$WORK/m4-undated/reports/mutation/2026-10-28-mutation.json" "$WORK/m4-undated/reports/mutation/mutation.json"; expect_only m4-undated QA-M4
  has_line m4-undated 'the report has no date (none in its path, and it is not committed)'
  # A report with no date in its path is dated by its last commit: a stand-in git
  # answers the read-only git log.
  mk m4-git;      mv "$WORK/m4-git/reports/mutation/2026-10-28-mutation.json" "$WORK/m4-git/reports/mutation/mutation.json"; mkdir -p "$WORK/gitshim"
  printf '#!/bin/sh\necho "$*" >> "%s/gitshim.log"\ncase "$*" in\n  *--is-inside-work-tree*) echo true ;;\n  *--is-shallow-repository*) echo "${SHALLOW_SHIM:-false}" ;;\n  *"log -1 --format=%%as -- "*mutation.json) echo 2026-10-20 ;;\nesac\n' "$WORK" > "$WORK/gitshim/git"; chmod +x "$WORK/gitshim/git"
  PATH="$WORK/gitshim:$PATH" expect_pass m4-git 'the last commit dates the report'
  # git runs with bare-repository discovery and signature checks switched off.
  grep -q 'safe.bareRepository=explicit -c log.showSignature=false' "$WORK/gitshim.log" && ok || bad "m4-git: git ran without its safety options: $(tail -1 "$WORK/gitshim.log")"
  SHALLOW_SHIM=true PATH="$WORK/gitshim:$PATH" expect_only m4-git QA-M4
  has_line m4-git 'the clone is shallow, so no commit dates it'
  mk m4-future;   mv "$WORK/m4-future/reports/mutation/2026-10-28-mutation.json" "$WORK/m4-future/reports/mutation/2026-12-01-mutation.json"; expect_only m4-future QA-M4
  has_line m4-future 'the report is dated 2026-12-01, after today'
  mk m4-feb;      mv "$WORK/m4-feb/reports/mutation/2026-10-28-mutation.json" "$WORK/m4-feb/reports/mutation/2026-02-30-mutation.json"; OPTS="--p95 500 --rps 50 --min-score 70 --today 2026-03-05" expect_only m4-feb QA-M4
  has_line m4-feb 'the report has no date'
  mk m4-dir;      mkdir -p "$WORK/m4-dir/reports/mutation/2026-10-30"; mv "$WORK/m4-dir/reports/mutation/2026-10-28-mutation.json" "$WORK/m4-dir/reports/mutation/2026-10-30/mutation.json"; expect_pass m4-dir 'a date in the directory name'
  mk m4-newest;   add m4-newest reports/mutation/2026-10-01-mutation-score.txt 'Mutation score: 40%'; expect_pass m4-newest 'the newest report counts, not the worst'
  mk m4-newbad;   add m4-newbad reports/mutation/2026-10-31-mutation-score.txt 'Mutation score: 40%'; expect_only m4-newbad QA-M4
  has_line m4-newbad 'the newest report scores 40%'
  mk m4-unread;   add m4-unread reports/mutation/2026-10-31-mutation-score.txt 'killed everything'; expect_pass m4-unread 'an unreadable report beside a usable one is a NOTE'
  has_line m4-unread 'no mutation score can be read from this report; not counted'
  mk m4-flag;     mkdir -p "$WORK/m4-flag/out"; mv "$WORK/m4-flag/reports/mutation/2026-10-28-mutation.json" "$WORK/m4-flag/out/2026-10-28-stryker.json"; expect_only m4-flag QA-M4
  run "$WORK/m4-flag" --report out/2026-10-28-stryker.json; [ "$RC" -eq 0 ] && ok || bad "m4-flag: --report should find the report, got $RC"
  # Other tools
  mk pit;         rm -f "$WORK/pit/stryker.conf.json" "$WORK/pit/reports/mutation/2026-10-28-mutation.json"; edit pit package.json "$(drop '@stryker-mutator/core')" && \
    add pit pom.xml '<project>\n  <build><plugins><plugin>\n    <groupId>org.pitest</groupId>\n    <artifactId>pitest-maven</artifactId>\n    <configuration>\n      <mutationThreshold>80</mutationThreshold>\n    </configuration>\n  </plugin></plugins></build>\n</project>' && \
    add pit reports/mutation/2026-10-29/mutations.xml "<mutations>\n<mutation detected='true' status='KILLED'><mutator>X</mutator></mutation>\n<mutation detected='true' status='KILLED'><mutator>X</mutator></mutation>\n<mutation detected='true' status='TIMED_OUT'><mutator>X</mutator></mutation>\n<mutation detected='true' status='KILLED'><mutator>X</mutator></mutation>\n<mutation detected='false' status='SURVIVED'><mutator>X</mutator></mutation>\n</mutations>" && \
    edit pit .github/workflows/ci.yml "$(subst 'run: npm run mutate' 'run: mvn org.pitest:pitest-maven:mutationCoverage')" && OPTS="--p95 500 --rps 50 --min-score 80 --today 2026-11-01" expect_pass pit 'PIT at 80%, threshold 80'
  has_line pit '1 mutation tool(s), 1 report(s)'
  edit pit pom.xml "$(subst '<mutationThreshold>80' '<mutationThreshold>60')" && OPTS="--p95 500 --rps 50 --min-score 80 --today 2026-11-01" expect_only pit QA-M2
  has_line pit 'pit: the break threshold 60 is below min_score 80'
  edit pit pom.xml "$(subst '<mutationThreshold>60' '<mutationThreshold>85')" && OPTS="--p95 500 --rps 50 --min-score 85 --today 2026-11-01" expect_only pit QA-M4
  has_line pit 'the newest report scores 80%, below min_score 85'
  mk grem;        rm -f "$WORK/grem/stryker.conf.json" "$WORK/grem/reports/mutation/2026-10-28-mutation.json"; edit grem package.json "$(drop '@stryker-mutator/core')" && \
    add grem .gremlins.yaml 'unleash:\n  threshold:\n    efficacy: 75' && add grem reports/mutation/2026-10-30-mutation-score.txt 'Test efficacy: 82.50%\nMutator coverage: 90.00%' && \
    edit grem .github/workflows/ci.yml "$(subst 'run: npm run mutate' 'run: gremlins unleash')" && expect_pass grem 'gremlins at 82.5%, efficacy threshold 75'
  rm -f "$WORK/grem/.gremlins.yaml"; edit grem .github/workflows/ci.yml "$(subst 'run: gremlins unleash' 'run: gremlins unleash --threshold-efficacy 75')" && expect_pass grem 'the efficacy threshold on the command line'
  mk mutmut;      rm -f "$WORK/mutmut/stryker.conf.json"; edit mutmut package.json "$(drop '@stryker-mutator/core')" && add mutmut setup.cfg '[mutmut]\npaths_to_mutate = src/' && \
    edit mutmut .github/workflows/ci.yml "$(subst 'run: npm run mutate' 'run: mutmut run')" && expect_pass mutmut 'mutmut has no threshold: a NOTE'
  has_line mutmut 'NOTE  QA-M2'
  has_line mutmut 'mutmut has no break threshold'
  mk gomut;       rm -f "$WORK/gomut/stryker.conf.json" "$WORK/gomut/reports/mutation/2026-10-28-mutation.json"; edit gomut package.json "$(drop '@stryker-mutator/core')" && \
    edit gomut .github/workflows/ci.yml "$(subst 'run: npm run mutate' 'run: go-mutesting ./...')" && add gomut reports/mutation/2026-10-30-mutation-score.txt 'The mutation score is 0.750000 (30 passed, 10 failed, 0 duplicated, 0 skipped, total is 40)' && expect_pass gomut 'go-mutesting run from CI, 75%'
  has_line gomut '1 mutation tool(s), 1 report(s)'
  # Review fixes (v0.4.13): k6 scenarios read one by one, comments, one-line
  # thresholds, installs, Locust users, report names, dates and unusable reports.
  K6H="import http from 'k6/http';\nexport const options = {\n"
  K6P="  scenarios: {\n    peak: {\n      executor: 'constant-arrival-rate',\n      rate: 60,\n      timeUnit: '1s',\n      duration: '5m',\n      preAllocatedVUs: 100,\n    },\n  },\n"
  K6T="};\nexport default function () { http.get('https://example.test/'); }"
  K6OK="  thresholds: {\n    http_req_duration: ['p(95)<400'],\n    http_req_failed: ['rate<0.01'],\n  },\n"
  only l3-mix k6; add l3-mix load/checkout.js "$K6H  scenarios: {\n    soak: {\n      executor: 'ramping-vus',\n      stages: [{ duration: '5m', target: 2000 }],\n    },\n    probe: {\n      executor: 'constant-arrival-rate',\n      rate: 10,\n      timeUnit: '1s',\n      duration: '5m',\n      preAllocatedVUs: 20,\n    },\n  },\n$K6OK$K6T" && expect_only l3-mix QA-L3
  has_line l3-mix 'the highest request rate is 10/s'
  has_line l3-mix 'load/checkout.js:10'
  only l3-units k6; add l3-units load/checkout.js "$K6H  scenarios: {\n    warm: { executor: 'constant-arrival-rate', rate: 5, timeUnit: '1s', duration: '1m', preAllocatedVUs: 5 },\n    peak: {\n      executor: 'constant-arrival-rate',\n      rate: 6000,\n      timeUnit: '1m',\n      duration: '5m',\n      preAllocatedVUs: 200,\n    },\n  },\n$K6OK$K6T" && OPTS="--p95 500 --rps 150 --min-score 70 --today 2026-11-01" expect_only l3-units QA-L3
  has_line l3-units 'the highest request rate is 100/s'
  only l3-ramp k6; add l3-ramp load/checkout.js "$K6H  scenarios: {\n    ramp: {\n      executor: 'ramping-arrival-rate',\n      startRate: 10,\n      timeUnit: '1s',\n      preAllocatedVUs: 100,\n      stages: [{ target: 20, duration: '1m' }, { target: 80, duration: '5m' }],\n    },\n  },\n$K6OK$K6T" && expect_pass l3-ramp 'ramping-arrival-rate stage targets are rates'
  has_line l3-ramp 'PASS  QA-L3'
  only l3-hour k6; edit l3-hour load/checkout.js "$(subst 'rate: 60,' 'rate: 144000,')" && edit l3-hour load/checkout.js "$(subst "timeUnit: '1s'" "timeUnit: '1h'")" && expect_only l3-hour QA-L3
  has_line l3-hour 'the highest request rate is 40/s'
  only l3-docker locust; edit l3-docker locust.conf "$(drop 'users = 50')" && edit l3-docker .github/workflows/ci.yml "$(subst '      - run: npm test' '      - run: npm test\n      - run: docker run -u 1000:1000 -v /src:/w locustio/locust -f /w/load/locustfile.py --headless -u 20')" && expect_only l3-docker QA-L3
  has_line l3-docker 'the highest request rate is 20/s'
  only l2-oneline k6; add l2-oneline load/checkout.js "$K6H$K6P  thresholds: { http_req_failed: ['rate<0.01'], http_req_duration: ['p(95)<400'] },\n$K6T" && expect_pass l2-oneline 'two thresholds on one line'
  only l2-oneline2 k6; add l2-oneline2 load/checkout.js "$K6H$K6P  thresholds: { http_req_duration: ['p(95)<400'], http_req_failed: ['rate<0.01'] },\n$K6T" && expect_pass l2-oneline2 'two thresholds on one line, the other order'
  only l2-twice k6; add l2-twice load/checkout.js "$K6H$K6P  thresholds: { http_req_duration: ['p(95)<900', 'p(95)<400'], http_req_failed: ['rate<0.01'] },\n$K6T" && expect_pass l2-twice 'the tightest untagged threshold counts'
  only l2-block k6; add l2-block load/checkout.js "$K6H$K6P  /* old:\n  thresholds: { http_req_duration: ['p(95)<100'] },\n  */\n  thresholds: { http_req_duration: ['p(95)<2000'], http_req_failed: ['rate<0.01'] },\n$K6T" && expect_only l2-block QA-L2
  has_line l2-block 'the tightest p95 threshold is 2000 ms'
  only l2-linecom k6; add l2-linecom load/checkout.js "$K6H$K6P  // http_req_duration: ['p(95)<100'],\n  thresholds: { http_req_duration: ['p(95)<2000'], http_req_failed: ['rate<0.01'] },\n$K6T" && expect_only l2-linecom QA-L2
  only l4-errurl artillery; edit l4-errurl load/browse.yml "$(drop 'maxErrorRate')" && edit l4-errurl load/browse.yml "$(subst 'url: "/products"' 'url: "/api/errors.json"\n      - log: "errors.json saved"')" && expect_only l4-errurl QA-L4
  only l4-vusers artillery; edit l4-vusers load/browse.yml "$(subst '    maxErrorRate: 1' '    conditions:\n      - expression: vusers.failed == 0')" && expect_pass l4-vusers 'an Artillery condition on vusers.failed'
  only l4-numfail locust; edit l4-numfail load/locustfile.py "$(subst 'fail_ratio > 0.01' 'num_failures > 10')" && expect_pass l4-numfail 'a Locust num_failures threshold'
  mk l5-install;  rm -f "$WORK/l5-install/Makefile" "$WORK/l5-install/docs/load-tests.md"; edit l5-install .github/workflows/ci.yml "$(subst '      - run: npm test' '      - run: npm test\n      - run: pip install -r requirements.txt pytest locust')" && expect_only l5-install QA-L5
  mk l5-prose;    rm -f "$WORK/l5-prose/Makefile"; add l5-prose docs/load-tests.md '# Load tests\n\nThe load test uses locust and artillery, but nobody runs it yet.' && expect_only l5-prose QA-L5
  mk l5-make;     rm -f "$WORK/l5-make/docs/load-tests.md"; expect_pass l5-make 'a make recipe runs the load test'
  mk art-noscen;  add art-noscen load/settings.yml 'config:\n  target: "https://example.test"' && expect_pass art-noscen 'YAML with config: and no scenarios: is not a load test'
  has_line art-noscen '3 load script(s) (k6 1, Artillery 1, Locust 1)'
  # Mutation configuration comments, tools found one way only, installs
  mk m2-comment;  rm -f "$WORK/m2-comment/stryker.conf.json"; add m2-comment stryker.config.mjs 'export default {\n  // Was: thresholds: { high: 80, low: 60, break: 75 },\n  thresholds: { high: 80, low: 60, break: null },\n};' && expect_only m2-comment QA-M2
  has_line m2-comment 'stryker: no break threshold'
  mk m2-pkg;      rm -f "$WORK/m2-pkg/stryker.conf.json"; expect_only m2-pkg QA-M2
  has_line m2-pkg 'package.json'
  mk m3-install;  edit m3-install .github/workflows/ci.yml "$(drop 'npm run mutate')" && edit m3-install .github/workflows/ci.yml "$(drop 'Mutation testing')" && \
    edit m3-install .github/workflows/ci.yml "$(subst '      - run: npm test' '      - run: npm test\n      - run: go install github.com/avito-tech/go-mutesting/cmd/go-mutesting@latest\n      - name: stryker run smoke\n        run: echo skipped')" && expect_only m3-install QA-M3
  has_line m3-install '1 mutation tool(s)'
  mk mutmut-cfg;  rm -f "$WORK/mutmut-cfg/stryker.conf.json"; edit mutmut-cfg package.json "$(drop '@stryker-mutator/core')" && add mutmut-cfg setup.cfg '[mutmut]\npaths_to_mutate = src/' && \
    edit mutmut-cfg .github/workflows/ci.yml "$(drop 'npm run mutate')" && edit mutmut-cfg .github/workflows/ci.yml "$(drop 'Mutation testing')" && expect_only mutmut-cfg QA-M3
  has_line mutmut-cfg 'no CI step runs the mutation tool (mutmut)'
  mk grem2;       rm -f "$WORK/grem2/stryker.conf.json" "$WORK/grem2/reports/mutation/2026-10-28-mutation.json"; edit grem2 package.json "$(drop '@stryker-mutator/core')" && \
    add grem2 .gremlins.yaml '# efficacy: 80\nunleash:\n  threshold:\n    efficacy: 30' && add grem2 reports/mutation/2026-10-30-mutation-score.txt 'Test efficacy: 82.50%' && \
    edit grem2 .github/workflows/ci.yml "$(subst 'run: npm run mutate' 'run: gremlins unleash')" && expect_only grem2 QA-M2
  has_line grem2 'gremlins: the break threshold 30 is below min_score 70'
  mk pit2;        rm -f "$WORK/pit2/stryker.conf.json" "$WORK/pit2/reports/mutation/2026-10-28-mutation.json"; edit pit2 package.json "$(drop '@stryker-mutator/core')" && \
    add pit2 pom.xml '<project>\n  <build><plugins><plugin>\n    <artifactId>pitest-maven</artifactId>\n    <configuration>\n      <!--\n      <mutationThreshold>80</mutationThreshold>\n      -->\n    </configuration>\n  </plugin></plugins></build>\n</project>' && \
    add pit2 reports/mutation/2026-10-29/mutations.xml "<mutations>\n<mutation detected='true' status='KILLED'><mutator>X</mutator></mutation>\n</mutations>" && \
    edit pit2 .github/workflows/ci.yml "$(subst 'run: npm run mutate' 'run: mvn org.pitest:pitest-maven:mutationCoverage')" && expect_only pit2 QA-M2
  has_line pit2 'pit: no break threshold'
  mk gradle;      rm -f "$WORK/gradle/stryker.conf.json" "$WORK/gradle/reports/mutation/2026-10-28-mutation.json"; edit gradle package.json "$(drop '@stryker-mutator/core')" && \
    add gradle build.gradle "plugins {\n  id 'info.solidsoft.pitest' version '1.15.0'\n}\npitest {\n  mutationThreshold = 80\n}" && \
    add gradle reports/mutation/2026-10-29/mutations.xml "<mutations>\n<mutation detected='true' status='KILLED'><mutator>X</mutator></mutation>\n<mutation detected='true' status='KILLED'><mutator>X</mutator></mutation>\n<mutation detected='true' status='KILLED'><mutator>X</mutator></mutation>\n<mutation detected='true' status='KILLED'><mutator>X</mutator></mutation>\n<mutation detected='false' status='NO_COVERAGE'><mutator>X</mutator></mutation>\n</mutations>" && \
    edit gradle .github/workflows/ci.yml "$(subst 'run: npm run mutate' 'run: ./gradlew pitest')" && OPTS="--p95 500 --rps 50 --min-score 80 --today 2026-11-01" expect_pass gradle 'PIT through Gradle at 80%'
  OPTS="--p95 500 --rps 50 --min-score 90 --today 2026-11-01" run "$WORK/gradle"
  has_line gradle 'pit: the break threshold 80 is below min_score 90'
  mkdir -p "$WORK/java"; add java pom.xml '<project></project>'; add java src/main/java/A.java 'class A {}'; OPTS="--today 2026-11-01" expect_only java QA-M1
  # Reports: names, unusable reports beside a usable one, targets in summaries
  mk m4-srcname;  add m4-srcname src/mutation-score.js 'export const s = 1;' && add m4-srcname tests/mutation-score.test.js "import { s } from '../src/mutation-score.js';\ntest('s', () => { if (s !== 1) throw new Error('s'); });" && expect_pass m4-srcname 'a code file named like a report is code'
  has_line m4-srcname '1 report(s)'
  mk m4-stray;    cp "$WORK/m4-stray/reports/mutation/2026-10-28-mutation.json" "$WORK/m4-stray/reports/mutation/mutation.json"; expect_pass m4-stray 'a local undated report beside a dated one'
  has_line m4-stray 'NOTE  QA-M4'
  has_line m4-stray 'it is not committed); not counted'
  mk m4-unreadonly; rm -f "$WORK/m4-unreadonly/reports/mutation/2026-10-28-mutation.json"; add m4-unreadonly reports/mutation/2026-10-31-mutation-score.txt 'killed everything' && expect_only m4-unreadonly QA-M4
  has_line m4-unreadonly 'no mutation score can be read from this report'
  mk m4-target;   add m4-target reports/mutation/2026-10-31-mutation-report.md 'Minimum mutation score: 80%\nMutation score: 45.2%' && expect_only m4-target QA-M4
  has_line m4-target 'the newest report scores 45.2%'
  mk m4-notool;   rm -f "$WORK/m4-notool/stryker.conf.json"; edit m4-notool package.json "$(drop '@stryker-mutator/core')" && edit m4-notool .github/workflows/ci.yml "$(drop 'npm run mutate')" && edit m4-notool package.json "$(subst '"node --test tests/",' '"node --test tests/"')" && edit m4-notool package.json "$(drop 'stryker run')" && expect_only m4-notool QA-M1
  has_line m4-notool 'PASS  QA-M4'
  mk m4-leap;     mv "$WORK/m4-leap/reports/mutation/2026-10-28-mutation.json" "$WORK/m4-leap/reports/mutation/2028-02-29-mutation.json"; OPTS="--p95 500 --rps 50 --min-score 70 --today 2028-03-01" expect_pass m4-leap '29 February 2028 is a date'
  # --report stays inside the repository
  run "$GOOD" --report ../evidence-good/package.json; [ "$RC" -eq 2 ] && ok || bad "a --report path with .. should exit 2, got $RC"
  has_line report-up 'must be a path inside the repository'
  run "$GOOD" --report /etc/hosts; [ "$RC" -eq 2 ] && ok || bad "an absolute --report path should exit 2, got $RC"
  mk report-link; ln -s 2026-10-28-mutation.json "$WORK/report-link/reports/mutation/link.json"; run "$WORK/report-link" --report reports/mutation/link.json; [ "$RC" -eq 2 ] && ok || bad "a symlinked --report should exit 2, got $RC"
  has_line report-link 'must not be a symbolic link'
  # Nothing to read: an empty directory
  mkdir -p "$WORK/empty"; OPTS="--today 2026-11-01" run "$WORK/empty"; [ "$RC" -eq 0 ] && ok || bad "an empty directory should exit 0, got $RC"
  has_line empty 'check-test-evidence: 0 load script(s) (k6 0, Artillery 0, Locust 0), 0 mutation tool(s), 0 report(s), 0 failure(s)'
  # Maturity
  mk mat-std;     edit mat-std .github/workflows/ci.yml "$(drop 'npm run mutate')" && edit mat-std .github/workflows/ci.yml "$(drop 'Mutation testing')" && OPTS="--p95 500 --rps 50 --min-score 70 --maturity standard --today 2026-11-01" expect_pass mat-std 'QA-M3 is not required at standard'
  has_line mat-std 'N/A   QA-M3   CI runs the mutation tool (not required at standard)'
  mk mat-std2;    rm -rf "$WORK/mat-std2/load"; OPTS="--p95 500 --rps 50 --maturity standard --today 2026-11-01" run "$WORK/mat-std2"; printf '%s\n' "$OUT" | grep -q '^FAIL  QA-L1 ' && ok || bad "mat-std2: QA-L1 is required at standard"
  OPTS="--p95 100 --rps 50 --min-score 70 --maturity standard --today 2026-11-01" run "$GOOD"; printf '%s\n' "$OUT" | grep -q '^FAIL  QA-L2 ' && ok || bad "mat-std-l2: QA-L2 is required at standard"
  OPTS="--maturity standard --today 2026-11-01" run "$WORK/m1"; printf '%s\n' "$OUT" | grep -q '^FAIL  QA-M1 ' && ok || bad "mat-std-m1: QA-M1 is required at standard"
  mk mat-proto;   rm -rf "$WORK/mat-proto/load" "$WORK/mat-proto/stryker.conf.json" "$WORK/mat-proto/reports"; OPTS="--p95 500 --rps 50 --maturity prototype --today 2026-11-01" expect_pass mat-proto 'prototype requires none'
  [ "$(printf '%s\n' "$OUT" | grep -c 'not required at prototype')" -eq 9 ] && ok || bad "mat-proto: all nine should be N/A at prototype"
  # Bad input
  expect_rc2 bad-p95 'a non-number' --p95 500ms
  expect_rc2 bad-rps 'a non-number' --rps fifty
  expect_rc2 bad-min 'over 100' --min-score 101
  expect_rc2 bad-age 'a non-number' --max-age 3m
  expect_rc2 bad-mat 'an unknown level' --maturity gold
  expect_rc2 bad-today 'not a calendar date' --today 2026-02-30
  expect_rc2 bad-report 'a missing report' --report no-such.json
  has_line bad-report 'no such report: no-such.json'
  expect_rc2 bad-opt 'an unknown option' --junk
  (cd "$GOOD" && PATH="$SHIM:$PATH" bash "$CHECK" --today 2026-11-01 --p95 >"$WORK/out" 2>&1); RC=$?; OUT=$(cat "$WORK/out")
  [ "$RC" -eq 2 ] && ok || bad "bad-val: a missing value should exit 2, got $RC"
  has_line bad-val 'Usage: check-test-evidence.sh'
  OPTS="--today 2028-02-29" run "$GOOD"; [ "$RC" -ne 2 ] && ok || bad "--today 2028-02-29 is a leap day"
  OPTS="--today 2026-11-01" run "$GOOD" --min-score 100; [ "$RC" -ne 2 ] && ok || bad "--min-score 100 is allowed"
  (cd "$GOOD" && PATH="$SHIM:$PATH" bash "$CHECK" >/dev/null 2>&1); [ $? -eq 2 ] && ok || bad "no PATH should exit 2"
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

printf "test-check-test-evidence: %s/%s PASS (awk: %s)\n" "$PASS" "$((PASS + FAIL))" "$AWKS"
[ "$FAIL" -eq 0 ]
