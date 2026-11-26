#!/usr/bin/env bash
# Behavior test for the AI risk-tier record in plugins/ascent-governance/scripts/
# check-audit.sh (GOV-A1–A5, ADR-031).
#
# The good fixture (fixtures/ai-tier-good: audit-good with one AI application,
# support-assistant, and its signed tier-2 record) is GO at beta. Each rule then
# gets negative controls: a copy broken in exactly one way fails that rule and no
# other. Also covers two applications (fixtures/ai-tier-multi), CRLF records,
# default floors, the lowest rung, and a contract with no AI application.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-ai-tier: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
NAME=test-ai-tier
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
CHECK="$PLUGIN/scripts/check-audit.sh"
REC=docs/governance/ai-tier/support-assistant.md
need "$CHECK" "$FIX/ai-tier-good/$REC" "$FIX/ai-tier-multi/docs/governance/ai-tier/screening-tool.md" "$FIX/stub-checker.sh"
tier() {  # NAME FROM TO — a copy of the good fixture with one cell of the record changed, run at beta
  stubs; mk "$1" ai-tier-good; edit "$1" "$REC" "$(subst "$2" "$3")"; chk "$1" --env beta
}
matrix() {
  stubs; mk good ai-tier-good; chk good --env beta; expect_pass good
  has good 'PASS  GOV-A1  support-assistant: tier 2, decided by ana-lopez on 2026-11-20, review by 2027-05-20'
  has good 'check-audit: beta: GO, '
  stubs; mk good-prod ai-tier-good; chk good-prod --env prod; has good-prod 'PASS  GOV-A1  support-assistant'

  # GOV-A1: every AI application has a record
  stubs; mk a1 ai-tier-good; rm -f "$WORK/a1/$REC"; chk a1 --env beta; expect_only a1 GOV-A1 High
  has a1 'support-assistant has no AI risk-tier record (docs/governance/ai-tier/support-assistant.md)'

  # GOV-A2: every field, a tier of 1 to 3, the fixed values, the name
  stubs; mk a2-missing ai-tier-good; edit a2-missing "$REC" "$(drop '| personal_data |')"; chk a2-missing --env beta
  expect_only a2-missing GOV-A2 High; has a2-missing 'has no personal_data'
  tier a2-tier4 '| tier | 2 |' '| tier | 4 |'; expect_only a2-tier4 GOV-A2 High; has a2-tier4 "tier is '4'"
  tier a2-actions '| actions | reversible |' '| actions | maybe |'; expect_only a2-actions GOV-A2 High
  has a2-actions "actions is 'maybe'; it is none, reversible, irreversible or financial"
  tier a2-name '| application | support-assistant |' '| application | support-bot |'; expect_only a2-name GOV-A2 High
  has a2-name "names the application 'support-bot', and its file name says 'support-assistant'"
  stubs; mk a2-table ai-tier-good; edit a2-table "$REC" "$(subst '<!-- ai-tier:start -->' '<!-- tier -->')"; chk a2-table --env beta
  expect_only a2-table GOV-A2 High; has a2-table 'has no ai-tier table'
  tier a2-review '| review_by | 2027-05-20 |' '| review_by | someday |'; expect_only a2-review GOV-A2 High
  stubs; mk a2-crlf ai-tier-good; edit a2-crlf "$REC" '{ printf "%s\r\n", $0 }'; chk a2-crlf --env beta; expect_pass a2-crlf
  stubs; mk a2-crlf-open ai-tier-good; edit a2-crlf-open "$REC" '{ sub(/ \|[^|]*\|$/, ""); printf "%s\r\n", $0 }'; chk a2-crlf-open --env beta; expect_pass a2-crlf-open
  has a2-crlf 'PASS  GOV-A1  support-assistant: tier 2'

  # GOV-A3: a person in approvers decided, on a date
  tier a3-signer '| decided_by | ana-lopez |' '| decided_by | bob |'; expect_only a3-signer GOV-A3 High
  has a3-signer 'bob decided the tier and is not in governance.approvers (ana-lopez)'
  stubs; mk a3-any ai-tier-good; edit a3-any "$REC" "$(subst '| decided_by | ana-lopez |' '| decided_by | bob |')"
  edit a3-any "$CON" "$(subst 'approvers: [ana-lopez]' 'approvers: []')"; chk a3-any --env beta; expect_pass a3-any
  tier a3-unsigned '| decided_by | ana-lopez |' '| decided_by | |'; expect_only a3-unsigned GOV-A3 High
  has a3-unsigned 'no person has decided it yet'
  tier a3-date '| decided_on | 2026-11-20 |' '| decided_on | soon |'; expect_only a3-date GOV-A3 High; has a3-date "decided_on is 'soon', which is not a real date"
  tier a3-future '| decided_on | 2026-11-20 |' '| decided_on | 2026-12-09 |'; expect_only a3-future GOV-A3 High

  # GOV-A4: review_by is not past
  tier a4 '| review_by | 2027-05-20 |' '| review_by | 2026-12-01 |'; expect_only a4 GOV-A4 Medium
  has a4 'check-audit: beta: GO WITH CONDITIONS, '

  # GOV-A5: the tier is not below the floor its own reasons imply
  tier a5-irrev '| actions | reversible |' '| actions | irreversible |'; expect_only a5-irrev GOV-A5 High
  has a5-irrev 'tier 2 is below tier 3, which its reasons imply (actions: irreversible)'
  tier a5-fin '| actions | reversible |' '| actions | financial |'; expect_only a5-fin GOV-A5 High
  tier a5-people '| decisions_about_people | no |' '| decisions_about_people | yes |'; expect_only a5-people GOV-A5 High
  tier a5-external '| tier | 2 |' '| tier | 1 |'; expect_only a5-external GOV-A5 High
  has a5-external 'tier 1 is below tier 2, which its reasons imply (audience: external'
  stubs; mk a5-reversible ai-tier-good; edit a5-reversible "$REC" "$(subst '| tier | 2 |' '| tier | 1 |')"
  edit a5-reversible "$REC" "$(subst '| audience | external |' '| audience | internal |')"; chk a5-reversible --env beta
  expect_only a5-reversible GOV-A5 High; has a5-reversible '(actions: reversible)'
  stubs; mk a5-above ai-tier-good; edit a5-above "$REC" "$(subst '| tier | 2 |' '| tier | 3 |')"
  edit a5-above "$REC" "$(subst '| audience | external |' '| audience | internal |')"
  edit a5-above "$REC" "$(subst '| actions | reversible |' '| actions | none |')"; chk a5-above --env beta; expect_pass a5-above
  stubs; mk a5-one ai-tier-good; edit a5-one "$REC" "$(subst '| tier | 2 |' '| tier | 1 |')"
  edit a5-one "$REC" "$(subst '| audience | external |' '| audience | internal |')"
  edit a5-one "$REC" "$(subst '| actions | reversible |' '| actions | none |')"; chk a5-one --env beta; expect_pass a5-one

  # two applications: each has its own record
  stubs; mk multi ai-tier-multi; chk multi --env beta; expect_pass multi
  has multi 'PASS  GOV-A1  screening-tool: tier 3'; has multi 'PASS  GOV-A1  support-assistant: tier 2'
  stubs; mk multi-one ai-tier-multi; rm -f "$WORK/multi-one/docs/governance/ai-tier/screening-tool.md"; chk multi-one --env beta
  expect_only multi-one GOV-A1 High; has multi-one 'screening-tool has no AI risk-tier record'; lacks multi-one 'support-assistant has no'
  stubs; mk multi-bad ai-tier-multi; edit multi-bad "$CON" "$(subst '- name: screening-tool' '- name: screening tool')"; chk multi-bad --env beta
  expect_only multi-bad GOV-A2 High; has multi-bad "'screening tool' is not letters, digits, - and _"

  # GOV-A1: AI code outside every declared application belongs to none
  stubs; mk orphan ai-tier-multi; mkdir -p "$WORK/orphan/tools" "$WORK/orphan/services/support"
  printf 'import anthropic\n' > "$WORK/orphan/tools/bot.py"; printf 'from openai import OpenAI\n' > "$WORK/orphan/services/support/agent.py"
  chk orphan --env beta; expect_only orphan GOV-A1 High
  has orphan 'AI code outside every application ai.applications declares: tools/bot.py'; lacks orphan 'services/support/agent.py;'
  has orphan 'PASS  GOV-A1  support-assistant: tier 2'
  stubs; chk orphan --env local; expect_pass orphan-local; lacks orphan-local 'GOV-A1'
  stubs; no_ai; chk orphan --env beta; expect_pass orphan-no-ai; lacks orphan-no-ai 'tools/bot.py'
  # GOV-A1: AI code and no ai.applications is one application, named after the folder, that needs a record
  stubs; mk implicit audit-good; mkdir -p "$WORK/implicit/src"; printf 'from openai import OpenAI\n' > "$WORK/implicit/src/ask.py"
  chk implicit --env beta; expect_only implicit GOV-A1 High
  has implicit 'implicit has no AI risk-tier record (docs/governance/ai-tier/implicit.md)'
  mkdir -p "$WORK/implicit/docs/governance/ai-tier"; awk '{ gsub(/support-assistant/, "implicit"); print }' "$FIX/ai-tier-good/$REC" > "$WORK/implicit/docs/governance/ai-tier/implicit.md"
  stubs; chk implicit --env beta; expect_pass implicit-record; has implicit-record 'PASS  GOV-A1  implicit: tier 2'

  # GOV-A runs whatever the floors say: with default floors too
  stubs; mk defaults ai-tier-good; rm -f "$WORK/defaults/$REC"
  edit defaults "$CON" 'index($0, "  floors:") { skip = 1; next } skip && index($0, "  approvers:") { skip = 0 } !skip { print }'
  chk defaults --env beta; has defaults 'FAIL  GOV-A1  High'; expect_rc defaults 1
  # not on the lowest rung
  stubs; mk lowest ai-tier-good; rm -f "$WORK/lowest/$REC"; chk lowest --env local; expect_pass lowest; lacks lowest 'GOV-A'
  # no AI application: nothing reported
  stubs; mk none audit-good; chk none --env beta; expect_pass none; lacks none 'GOV-A'

  # GOV-S1: ai_tier_dir is a path inside the repository
  stubs; mk s1 ai-tier-good; edit s1 "$CON" "$(subst 'ai_tier_dir: docs/governance/ai-tier/' 'ai_tier_dir: /etc/ai-tier')"; chk s1 --env beta
  expect_only s1 GOV-S1 High; has s1 "governance.ai_tier_dir is '/etc/ai-tier'; it is a path inside the repository"
  stubs; mk s1-up ai-tier-good; edit s1-up "$CON" "$(subst 'ai_tier_dir: docs/governance/ai-tier/' 'ai_tier_dir: ../tiers/')"; chk s1-up --env beta
  expect_only s1-up GOV-S1 High
  # a custom folder
  stubs; mk dir ai-tier-good; mkdir -p "$WORK/dir/records/tiers"; mv "$WORK/dir/$REC" "$WORK/dir/records/tiers/"
  edit dir "$CON" "$(subst 'ai_tier_dir: docs/governance/ai-tier/' 'ai_tier_dir: records/tiers')"; chk dir --env beta; expect_pass dir
}
run_matrix
