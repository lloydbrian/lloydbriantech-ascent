#!/usr/bin/env bash
# Behavior test for plugins/ascent-ai/scripts/check-ai-evidence: an AI
# application's result files against its targets (AI-G, AI-E, AI-R, AI-L;
# ADR-031).
#
# The good fixture is py-agent: a golden set with the four slices and VERSION
# 7, a Promptfoo result built from a real Promptfoo output file
# (references/evidence-formats.md), a self-reported ascent-evidence-v1 result,
# retrieval results, a sources table and review notes. Each rule then gets
# negative controls: a copy broken in exactly one way fails that rule and no
# other, at the severity its tier gives it. Also covers errors counted as
# failures, git dates, a JSON file on one line, escaped strings, CRLF, and bad
# input.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-check-ai-evidence: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
NAME=test-check-ai-evidence
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
CHECK="$PLUGIN/scripts/check-ai-evidence.sh"
need "$CHECK" "$FIX/py-agent/evidence/evals/latest.json"
R=evidence/evals/latest.json; GS=tests/evals/golden/cases.yaml; PT=docs/governance/ai-tier/support-assistant.md
EV="--app support-assistant --golden tests/evals/golden --prompts prompts --results $R --format promptfoo --pass-rate 0.90 --attack-pass-rate 1.0 --max-age 14 --tier-record $PT"
ev() { local n="$1"; shift; run "$n" $EV --today 2026-11-25 "$@" .; }
evedit() { mk "$1" py-agent; edit "$1" "$2" "$(subst "$3" "$4")"; }   # COPY FILE FROM TO
row() { printf '/"id": "row-%s"/ { f = 1 } f && (i = index($0, "%s")) { $0 = substr($0, 1, i - 1) "%s" substr($0, i + length("%s")); f = 0 } { print }' "$1" "$(q "$2")" "$(q "$3")" "$(q "$2")"; }   # ROW FROM TO: the first FROM after the row's id
RET="--retrieval evidence/retrieval/ragas.json --retrieval-target faithfulness=0.90 --retrieval-target context_recall=0.85"
matrix() {
  mk good py-agent; ev good; expect_pass good
  has good 'PASS  AI-E3  [support-assistant] pass rate 1.00 (4 of 4 rows; errors count as failures), attack slice 1.00 (1 of 1)'
  has good 'PASS  AI-G1  [support-assistant] typical 1, edge 1, attack 1, regression 1; version 7'
  has good 'N/A   AI-R1  [support-assistant] no retrieval results given'; has good 'N/A   AI-L2  [support-assistant] no review notes given'
  has good 'check-ai-evidence: [support-assistant] 0 finding(s)'
  mk self py-agent; ev self --results evidence/evals/self.json --format ascent-evidence-v1; expect_only self AI-E5 Low; expect_rc self 0
  has self 'self-reported by deepeval 3.4.0'; has self 'PASS  AI-E3  [support-assistant] pass rate 0.90 (271 of 300'

  # AI-G1: the golden set
  evedit g1 "$GS" 'slice: attack' 'slice: typical'; ev g1; expect_only g1 AI-G1 High; has g1 'attack 0'
  mk g1-version py-agent; rm -f "$WORK/g1-version/tests/evals/golden/VERSION"; ev g1-version; expect_only g1-version AI-G1 High; has g1-version 'no VERSION'
  run g1-version --app support-assistant --golden tests/evals/golden/ --today 2026-11-25 --no-git .; has g1-version '[support-assistant] tests/evals/golden/VERSION  the golden set has no VERSION'
  mk g1-none py-agent; run g1-none ${EV/tests\/evals\/golden/tests/evals/none} --today 2026-11-25 .; expect_only g1-none AI-G1 High
  mk g1-crlf py-agent; edit g1-crlf "$GS" '{ printf "%s\r\n", $0 }'; edit g1-crlf tests/evals/golden/VERSION '{ printf "%s\r\n", $0 }'; ev g1-crlf; expect_pass g1-crlf

  # AI-E1: the result file
  mk e1 py-agent; ev e1 --results evidence/evals/none.json; expect_only e1 AI-E1 High; has e1 'evidence/evals/none.json does not exist'
  mk e1-none py-agent; run e1-none --app support-assistant --golden tests/evals/golden --today 2026-11-25 .; expect_only e1-none AI-E1 High; has e1-none 'no eval result file given'
  mk e1-shape py-agent; ev e1-shape --results "$GS"; expect_rc e1-shape 2; first e1-shape "check-ai-evidence: --results: $GS is not a promptfoo file"
  mk e1-other py-agent; ev e1-other --results evidence/evals/self.json; expect_rc e1-other 2; first e1-other 'check-ai-evidence: --results: evidence/evals/self.json is not a promptfoo file'
  mk e1-v1 py-agent; ev e1-v1 --format ascent-evidence-v1; expect_rc e1-v1 2; first e1-v1 "check-ai-evidence: --results: $R is not a ascent-evidence-v1 file"

  # AI-E2: fresh, by age and by git dates
  mk e2 py-agent; run e2 $EV --today 2026-12-10 .; expect_only e2 AI-E2 High; has e2 '20 days old'
  mk e2-edge py-agent; run e2-edge $EV --today 2026-12-04 .; expect_pass e2-edge
  mk e2-v1 py-agent; run e2-v1 $EV --results evidence/evals/self.json --format ascent-evidence-v1 --today 2026-12-10 .; has e2-v1 'FAIL  AI-E2  High'
  mk e2-git py-agent; G e2-git init -q; G e2-git add -A; GD 2026-11-19 e2-git commit -qm one
  printf 'Reply in one paragraph.\n' >> "$WORK/e2-git/prompts/reply.txt"; G e2-git add -A; GD 2026-11-22 e2-git commit -qm two
  ev e2-git; expect_only e2-git AI-E2 High; has e2-git 'older than the last change to a prompt or the golden set (2026-11-22)'
  ev e2-git --no-git; expect_pass e2-git
  mk e2-golden py-agent; G e2-golden init -q; G e2-golden add -A; GD 2026-11-19 e2-golden commit -qm one
  printf '# one more\n' >> "$WORK/e2-golden/$GS"; G e2-golden add -A; GD 2026-11-21 e2-golden commit -qm two
  ev e2-golden; expect_only e2-golden AI-E2 High
  mk e2-other py-agent; G e2-other init -q; G e2-other add -A; GD 2026-11-19 e2-other commit -qm one
  printf 'x\n' >> "$WORK/e2-other/agent/config.py"; G e2-other add -A; GD 2026-11-22 e2-other commit -qm two
  ev e2-other; expect_pass e2-other
  mk e2-zone py-agent; G e2-zone init -q; G e2-zone add -A; GD 2026-11-19 e2-zone commit -qm one
  printf 'x\n' >> "$WORK/e2-zone/prompts/reply.txt"; G e2-zone add -A
  GIT_AUTHOR_DATE="2026-11-20 14:30:00 +0100" GIT_COMMITTER_DATE="2026-11-20 14:30:00 +0100" G e2-zone commit -qm two
  ev e2-zone; expect_pass e2-zone   # 13:30 UTC, before the results' 14:02 UTC
  # a prompt and its results committed together, or a rebase that moves commit dates: the order of commits decides, not the clock
  mk e2-together py-agent; G e2-together init -q; G e2-together add -A; GD 2026-11-22 e2-together commit -qm one
  ev e2-together; expect_pass e2-together
  mk e2-rebased py-agent; G e2-rebased init -q; G e2-rebased add -A
  GIT_AUTHOR_DATE="2026-11-19 12:00:00 +0000" GIT_COMMITTER_DATE="2026-11-24 12:00:00 +0000" G e2-rebased commit -qm one
  ev e2-rebased; expect_pass e2-rebased
  mk e2-rebased2 py-agent; G e2-rebased2 init -q; G e2-rebased2 add -A; GD 2026-11-19 e2-rebased2 commit -qm one
  printf 'x\n' >> "$WORK/e2-rebased2/prompts/reply.txt"; G e2-rebased2 add -A
  GIT_AUTHOR_DATE="2026-11-20 13:30:00 +0000" GIT_COMMITTER_DATE="2026-11-24 12:00:00 +0000" G e2-rebased2 commit -qm two
  ev e2-rebased2; expect_pass e2-rebased2   # written before the 14:02 run, rebased after it
  mk e2-after py-agent; G e2-after init -q; G e2-after add -A; GD 2026-11-22 e2-after commit -qm one
  printf 'Reply in one paragraph.\n' >> "$WORK/e2-after/prompts/reply.txt"; G e2-after add -A; GD 2026-11-23 e2-after commit -qm two
  ev e2-after; expect_only e2-after AI-E2 High; has e2-after '(2026-11-23)'
  # results the repository does not track: only the clock can tell, by the prompt commit's author date
  mk e2-untracked py-agent; G e2-untracked init -q; G e2-untracked add -A; G e2-untracked rm -q --cached evidence/evals/latest.json; GD 2026-11-19 e2-untracked commit -qm one
  printf 'x\n' >> "$WORK/e2-untracked/prompts/reply.txt"; G e2-untracked add prompts; GIT_AUTHOR_DATE="2026-11-22 12:00:00 +0000" GIT_COMMITTER_DATE="2026-11-19 12:00:00 +0000" G e2-untracked commit -qm two
  ev e2-untracked; expect_only e2-untracked AI-E2 High

  # AI-E3: the pass rate, errors as failures, the attack slice
  mk e3 py-agent; edit e3 "$R" "$(subst '"successes": 4' '"successes": 3')"; edit e3 "$R" "$(subst '"failures": 0' '"failures": 1')"
  ev e3; expect_only e3 AI-E3 High; has e3 'pass rate 0.75 (3 of 4 rows'
  mk e3-errors py-agent; edit e3-errors "$R" "$(subst '"successes": 4' '"successes": 95')"; edit e3-errors "$R" "$(subst '"errors": 0' '"errors": 12')"
  ev e3-errors; expect_only e3-errors AI-E3 High; has e3-errors '95 of 107'
  mk e3-errors-ok py-agent; edit e3-errors-ok "$R" "$(subst '"successes": 4' '"successes": 95')"; edit e3-errors-ok "$R" "$(subst '"errors": 0' '"errors": 10')"
  ev e3-errors-ok; expect_pass e3-errors-ok
  mk e3-attack py-agent; edit e3-attack "$R" "$(row 2 '"success": true' '"success": false')"; ev e3-attack; expect_only e3-attack AI-E3 Critical
  has e3-attack 'attack slice 0.00 (0 of 1)'
  mk e3-tier1 py-agent; edit e3-tier1 "$R" "$(row 2 '"success": true' '"success": false')"; edit e3-tier1 "$PT" "$(subst '| tier | 3 |' '| tier | 1 |')"
  ev e3-tier1; expect_only e3-tier1 AI-E3 Critical
  mk e3-tier2 py-agent; edit e3-tier2 "$R" "$(subst '"successes": 4' '"successes": 3')"; edit e3-tier2 "$R" "$(subst '"failures": 0' '"failures": 1')"
  edit e3-tier2 "$PT" "$(subst '| tier | 3 |' '| tier | 2 |')"; ev e3-tier2; expect_only e3-tier2 AI-E3 Medium; expect_rc e3-tier2 0
  mk e3-noattack py-agent; edit e3-noattack "$R" "$(row 2 '"slice": "attack"' '"slice": "edge"')"; ev e3-noattack; expect_only e3-noattack AI-E3 Critical
  has e3-noattack 'no row of the attack slice'
  mk e3-target py-agent; edit e3-target "$R" "$(subst '"successes": 4' '"successes": 3')"; edit e3-target "$R" "$(subst '"failures": 0' '"failures": 1')"
  ev e3-target --pass-rate 0.75; expect_pass e3-target
  mk e3-v1 py-agent; ev e3-v1 --results evidence/evals/self.json --format ascent-evidence-v1 --pass-rate 0.95; has e3-v1 'FAIL  AI-E3  High'
  mk e3-v1-attack py-agent; edit e3-v1-attack evidence/evals/self.json "$(subst '"passed": 40' '"passed": 39')"
  ev e3-v1-attack --results evidence/evals/self.json --format ascent-evidence-v1; has e3-v1-attack 'FAIL  AI-E3  Critical'

  # AI-E4: the golden-set version
  mk e4 py-agent; edit e4 "$R" '{ gsub(/"golden_version": "7"/, "\"golden_version\": \"6\""); print }'; ev e4; expect_only e4 AI-E4 Medium; expect_rc e4 0
  has e4 'results say golden set 6, the golden set is 7'
  mk e4-none py-agent; edit e4-none "$R" "$(drop '"golden_version": "7",')"; ev e4-none; expect_only e4-none AI-E4 Medium; has e4-none 'carry no golden_version'
  mk e4-v1 py-agent; edit e4-v1 evidence/evals/self.json "$(subst '"version": "7"' '"version": "5"')"
  ev e4-v1 --results evidence/evals/self.json --format ascent-evidence-v1; has e4-v1 'FAIL  AI-E4  Medium'

  # AI-R1: retrieval
  mk r1 py-agent; ev r1 $RET; expect_pass r1; has r1 'PASS  AI-R1  [support-assistant] faithfulness 0.93 (target 0.90), context_recall 0.88 (target 0.85)'
  mk r1-low py-agent; ev r1-low $RET --retrieval-target faithfulness=0.95; expect_only r1-low AI-R1 High; has r1-low 'faithfulness 0.93 is below its target 0.95'
  mk r1-metric py-agent; ev r1-metric $RET --retrieval-target answer_relevancy=0.8; expect_only r1-metric AI-R1 High; has r1-metric 'has no metric answer_relevancy'
  mk r1-stale py-agent; edit r1-stale evidence/retrieval/ragas.json "$(subst '2026-11-20T15:10:00+01:00' '2026-11-01T09:00:00Z')"; ev r1-stale $RET
  expect_only r1-stale AI-R1 High; has r1-stale '24 days old'
  mk r1-zone py-agent; edit r1-zone evidence/retrieval/ragas.json "$(subst '2026-11-20T15:10:00+01:00' '2026-11-20T00:30:00+01:00')"
  run r1-zone $EV $RET --today 2026-12-04 .; expect_only r1-zone AI-R1 High; has r1-zone '15 days old (2026-11-19)'
  mk r1-missing py-agent; ev r1-missing --retrieval evidence/retrieval/none.json --retrieval-target faithfulness=0.9; expect_only r1-missing AI-R1 High
  mk r1-notarget py-agent; ev r1-notarget --retrieval evidence/retrieval/ragas.json; expect_only r1-notarget AI-R1 High; has r1-notarget 'no retrieval target'
  mk r1-shape py-agent; ev r1-shape --retrieval "$R" --retrieval-target faithfulness=0.9; expect_rc r1-shape 2
  first r1-shape "check-ai-evidence: --retrieval: $R is not a ascent-evidence-v1 file"

  # AI-R2: sources
  mk r2 py-agent; ev r2 --sources docs/ai/sources.md; expect_pass r2
  evedit r2-owner docs/ai/sources.md '| refund policy | finance-ops |' '| refund policy |  |'; ev r2-owner --sources docs/ai/sources.md
  expect_only r2-owner AI-R2 Medium; has r2-owner 'refund policy has no owner'
  evedit r2-past docs/ai/sources.md '| 2027-01-15 |' '| 2026-11-01 |'; ev r2-past --sources docs/ai/sources.md; expect_only r2-past AI-R2 Medium
  has r2-past 'help-centre articles was due for review on 2026-11-01'
  mk r2-missing py-agent; ev r2-missing --sources docs/ai/none.md; expect_only r2-missing AI-R2 Medium
  mk r2-empty py-agent; edit r2-empty docs/ai/sources.md "$(drop '| 20')"; ev r2-empty --sources docs/ai/sources.md; expect_only r2-empty AI-R2 Medium

  # AI-L1 and AI-L2: the review
  mk l1 py-agent; ev l1 --review-by 2026-11-01; expect_only l1 AI-L1 Medium; expect_rc l1 0
  mk l1-ok py-agent; ev l1-ok --review-by 2027-02-01; expect_pass l1-ok; has l1-ok 'PASS  AI-L1  [support-assistant] review by 2027-02-01'
  mk l2-ok py-agent; ev l2-ok --review-notes docs/ai/reviews.md; expect_pass l2-ok
  evedit l2 docs/ai/reviews.md '| 2026-08-01 | 0 | 1 |' '| 2026-08-01 | 1 | 1 |'; ev l2 --review-notes docs/ai/reviews.md; expect_only l2 AI-L2 Low
  has l2 'the regression slice has 1 case(s), as at the review of 2026-08-01'
  evedit l2-none docs/ai/reviews.md '| 2026-08-01 | 0 | 1 |' '| 2026-08-01 | 1 | 0 |'; ev l2-none --review-notes docs/ai/reviews.md; expect_pass l2-none
  mk l2-latest py-agent; edit l2-latest docs/ai/reviews.md "$(subst '<!-- ai-reviews:end -->' '| 2026-11-01 | 1 | 2 | two found in production |\n<!-- ai-reviews:end -->')"
  ev l2-latest --review-notes docs/ai/reviews.md; expect_only l2-latest AI-L2 Low; has l2-latest 'review of 2026-11-01'
  mk l2-missing py-agent; ev l2-missing --review-notes docs/ai/none.md; expect_only l2-missing AI-L2 Low

  # JSON read the same on one line, with escapes, and with CRLF
  mk oneline py-agent; edit oneline "$R" '{ printf "%s", $0 }'; ev oneline; expect_pass oneline
  mk escapes py-agent; edit escapes "$R" "$(subst '"output": "draft reply 0"' '"output": "draft \\"reply\\" {0} [x] \\\\"')"; ev escapes; expect_pass escapes
  mk jcrlf py-agent; edit jcrlf "$R" '{ printf "%s\r\n", $0 }'; ev jcrlf; expect_pass jcrlf
  mk broken py-agent; edit broken "$R" "$(subst '"successes": 4,' '"successes": 4,,')"; ev broken; expect_rc broken 2; first broken "check-ai-evidence: --results: $R is not a promptfoo file"

  # bad input
  mk bad py-agent
  run bad --golden tests/evals/golden .; expect_rc bad 2; first bad 'check-ai-evidence: --app: required'
  run bad --app support-assistant .; expect_rc bad 2; first bad 'check-ai-evidence: --golden: required'
  run bad $EV --format csv .; expect_rc bad 2; first bad 'check-ai-evidence: --format: expected promptfoo or ascent-evidence-v1, got csv'
  run bad $EV --pass-rate 1.5 .; expect_rc bad 2; first bad 'check-ai-evidence: --pass-rate: expected a number from 0 to 1, got 1.5'
  run bad $EV --attack-pass-rate all .; expect_rc bad 2; first bad 'check-ai-evidence: --attack-pass-rate: expected a number from 0 to 1, got all'
  run bad $EV --max-age 0 .; expect_rc bad 2; first bad 'check-ai-evidence: --max-age: expected a whole number of days, got 0'
  run bad $EV --retrieval-target faithfulness .; expect_rc bad 2; first bad 'check-ai-evidence: --retrieval-target: expected NAME=VALUE, got faithfulness'
  run bad $EV --review-by 2026-02-30 .; expect_rc bad 2; first bad 'check-ai-evidence: --review-by: 2026-02-30 is not a real date (YYYY-MM-DD)'
  run bad $EV --today soon .; expect_rc bad 2; first bad 'check-ai-evidence: --today: soon is not a real date (YYYY-MM-DD)'
  run bad $EV --threshold Severe .; expect_rc bad 2; first bad 'check-ai-evidence: --threshold: expected Critical, High, Medium or Low, got Severe'
  run bad $EV --frobnicate .; expect_rc bad 2; first bad 'check-ai-evidence: --frobnicate: unknown option'
  run bad --help; expect_rc bad 0; has bad 'Usage: check-ai-evidence.sh --app NAME --golden DIR'
}
run_matrix
