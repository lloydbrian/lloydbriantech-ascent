#!/usr/bin/env bash
# Behavior test for the adapters of plugins/ascent-governance/scripts/check-audit.sh:
# how each check's options and inputs are worked out from the contract
# (scripts/lib/adapters.tsv).
#
# The other plugins' checkers take options and do not read the contract. For each
# of the nine checks check-audit.sh can run, a contract with every mapped key set
# (fixtures/contracts/adapters-full.yml) must reach the checker as the options
# its own skill documents, and a contract without the section must reach it as
# the defaults only. The checkers are stand-ins that log their arguments. Also
# covers: every option in the table is one the real checker's usage names (so a
# renamed option fails here, not in a project's CI), acceptance records checked
# one by one since the last signed launch, an entry with a field missing, a
# positional value that starts with "-", and the good fixture run through the
# real checkers with no usage error.
#
# Runs with the default awk and every other awk found (mawk, gawk, BWK awk).
# Prints "test-adapters: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u
NAME=test-adapters
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib.sh"
CHECK="$PLUGIN/scripts/check-audit.sh"
TABLE="$PLUGIN/scripts/lib/adapters.tsv"
REAL="$HERE/../../../plugins"
need "$CHECK" "$TABLE" "$FIX/contracts/adapters-full.yml" "$FIX/audit-good/.ascent/contract.yml" "$FIX/stub-checker.sh"
TAB="$(printf '\t')"

line_of() { grep "^$(printf '%s' "$1" | sed 's|/|__|')\( \|$\)" "$WORK/log" | tail -1; }
# arg NAME CHECK ARG... — the checker's logged run has these arguments, next to each other
arg() {
  local n="$1" c="$2" want="" a; shift 2
  for a in "$@"; do want="$want | $a"; done
  case "$(line_of "$c") |" in *"$want |"*) ok ;; *) bad "$n: $c was not given:$want — it got: $(line_of "$c" | cut -c1-300)" ;; esac
}
noarg() { case "$(line_of "$2") |" in *" | $3 |"*) bad "$1: $2 must not be given $3: $(line_of "$2" | cut -c1-200)" ;; *) ok ;; esac; }
exact() { if [ "$(line_of "$2")" = "$(printf '%s' "$2" | sed 's|/|__|')$3" ]; then ok; else bad "$1: $2 expected exactly '$3', got: $(line_of "$2" | cut -c1-300)"; fi; }
runs() { n=$(grep -c "^$(printf '%s' "$2" | sed 's|/|__|')\( \|$\)" "$WORK/log" || true); if [ "$n" -eq "$3" ]; then ok; else bad "$1: $2 ran $n time(s), expected $3"; fi; }
record() { mkdir -p "$WORK/$1/$(dirname "$2")"; printf '# Acceptance: scores\n\n| # | Criterion | Evidence | Accepted by | Accepted on |\n|---|---|---|---|---|\n| 1 | A score can be entered | manual: entered a score on beta | ana-lopez | 2026-01-15 |\n' > "$WORK/$1/$2"; }
realfiles() {  # NAME — the files the full contract names, so the real checkers have something to read
  local d="$WORK/$1" f
  mkdir -p "$d/app/public" "$d/admin" "$d/site" "$d/infra" "$d/deploy" "$d/reports" "$d/docs/decisions" "$d/guide" "$d/records/drills"
  for f in index score confirm login reset; do printf '<!doctype html><html lang="en"><head><title>%s</title></head><body><a href="index.html">Home</a></body></html>\n' "$f" > "$d/app/public/$f.html"; done
  cp "$d/app/public/index.html" "$d/admin/index.html"; cp "$d/app/public/index.html" "$d/site/index.html"
  printf 'resource "x" "y" {}\n' > "$d/deploy/main.tf"; printf 'x: 1\n' > "$d/infra/main.yml"
  printf '{}\n' > "$d/reports/mutation.json"; printf '{}\n' > "$d/reports/stryker.json"
  printf '# Decisions\n' > "$d/docs/decisions/INDEX.md"; printf '# Dev\n' > "$d/guide/dev.md"; printf '# Ops\n' > "$d/guide/ops.md"
  printf '.env\n.env.*\n' > "$d/.dockerignore"     # without git, this is the one thing check-env can check
}
launch() {  # COPY FILE SIGNER DATE [VERDICT]
  mkdir -p "$WORK/$1/$(dirname "$2")"
  printf '# Launch\n\n**Verdict:** %s\n\n## Evidence\n\n**Signed:** %s\n**Date:** %s\n' "${5:-GO}" "$3" "$4" > "$WORK/$1/$2"
}
full() {  # NAME — a copy of the good fixture under the full contract
  stubs; mk "$1"; cp "$FIX/contracts/adapters-full.yml" "$WORK/$1/$CON"; mkdir -p "$WORK/$1/docs/decisions"
  for a in ADR-021 ADR-022; do printf '# %s: A waiver\n\n**Status:** Accepted\n' "$a" > "$WORK/$1/docs/decisions/$a-a-waiver.md"; done
  record "$1" records/acceptance/2026-11-20-scores.md
}

matrix() {
  # --- every mapped key reaches its checker ---------------------------------
  full all; printf 'services: {}\n' > "$WORK/all/compose.yaml"; chk all; expect_pass all

  c=ascent-security/check-env
  exact all $c ' | --no-git | .'

  c=ascent-security/check-dependencies
  arg all $c --maturity standard; arg all $c --pinning minor; arg all $c --lockfile-required no
  arg all $c --registry https://registry.example.test/npm/ --registry https://pypi.example.test/simple/
  arg all $c --deny GPL-3.0,AGPL-3.0; arg all $c --waived GHSA-35jh-r3h4-6jhm,CVE-2021-23337,CVE-2024-0001
  arg all $c --today 2026-12-02 .

  c=ascent-security/check-threat-model
  arg all $c --adr-dir docs/decisions/; arg all $c --max-age 120; arg all $c --maturity standard
  arg all $c --endpoint 'GET,DELETE /api/items/{id} required write' --endpoint 'GET /api/catalog none -'
  arg all $c --today 2026-12-02 docs/sec/TM.md

  c=ascent-ux/check-flow-integrity
  arg all $c --core app/public/score.html --core app/public/login.html --core app/public/reset.html
  arg all $c --flow enter-score=app/public/index.html,app/public/score.html,app/public/confirm.html --flow sign-in=app/public/login.html,app/public/index.html
  arg all $c --browsers last-2-evergreen,ios-safari-17 app/public admin site/index.html

  c=ascent-docs/check-docs
  arg all $c --path README.md --path guide/; arg all $c --exclude guide/old/
  arg all $c --persona Developer=guide/dev.md --persona Operator=guide/ops.md
  arg all $c --max-clicks 4; arg all $c --marker-days 45; arg all $c --lag-days 200; arg all $c --maturity prototype
  arg all $c --today 2026-12-02 --no-git .

  c=ascent-delivery/check-acceptance
  exact all $c ' | --root | . | --acceptor | ana-lopez | --acceptor | Sam Roe | records/acceptance/2026-11-20-scores.md'

  c=ascent-ops/check-drills
  arg all $c --repo .; arg all $c --maturity enterprise; arg all $c --max-age 60; arg all $c --rto 4h; arg all $c --rpo 15m
  arg all $c --ready-path /-/ready2; arg all $c --manual docs/ops/MO.md
  arg all $c --path orders-db:restore:docs/ops/restore.md
  arg all $c --alert ready-failing:docs/ops/ready.md:page --alert disk-full:docs/ops/disk.md
  arg all $c --iac infra/ --iac deploy/main.tf --iac compose.yaml --today 2026-12-02 records/drills/

  c=ascent-quality/check-test-evidence
  arg all $c --p95 300; arg all $c --rps 50; arg all $c --min-score 70; arg all $c --max-age 80
  arg all $c --report reports/mutation.json --report reports/stryker.json; arg all $c --maturity standard
  arg all $c --today 2026-12-02 .

  c=ascent-adr/check-adrs
  arg all $c --dir docs/decisions/; arg all $c --style madr; arg all $c --maturity standard; arg all $c --index docs/decisions/INDEX.md
  arg all $c --acknowledge ADR-009=0ac9d34 --acknowledge ADR-011=abc1234
  arg all $c --today 2026-12-02 --no-git .

  # --- a contract with only the governance section: the defaults ------------
  full bare; awk '/^architecture:/ { exit } { print }' "$FIX/contracts/adapters-full.yml" > "$WORK/bare/$CON"
  record bare docs/delivery/acceptance/2026-11-20-scores.md; chk bare; expect_only bare GOV-L2 Low
  exact bare ascent-security/check-env ' | --no-git | .'
  exact bare ascent-security/check-dependencies ' | --today | 2026-12-02 | .'
  exact bare ascent-security/check-threat-model ' | --today | 2026-12-02 | docs/security/THREAT-MODEL.md'
  # with no ux.pages nothing says which files are the pages: unmeasured, never a scan of everything
  runs bare ascent-ux/check-flow-integrity 0
  has bare 'FAIL  GOV-L2  Low    ascent-ux/check-flow-integrity  ascent-ux/check-flow-integrity is unmeasured: the contract has no ux.pages, so which files are the pages is not known'
  has bare 'GO WITH CONDITIONS'; lacks bare 'NO-GO'
  exact bare ascent-docs/check-docs ' | --today | 2026-12-02 | --no-git | .'
  exact bare ascent-delivery/check-acceptance ' | --root | . | docs/delivery/acceptance/2026-11-20-scores.md'
  exact bare ascent-ops/check-drills ' | --repo | . | --today | 2026-12-02 | docs/operations/drills/'
  exact bare ascent-quality/check-test-evidence ' | --today | 2026-12-02 | .'
  exact bare ascent-adr/check-adrs ' | --today | 2026-12-02 | --no-git | .'
  : > "$WORK/log"; GIT=1 chk bare; noarg bare-git ascent-docs/check-docs --no-git; noarg bare-git ascent-adr/check-adrs --no-git; noarg bare-git ascent-security/check-env --no-git

  # --- ascent-ai: once for each application, every key of the item ---------
  stubs; mk ai ai-tier-multi; cp "$FIX/contracts/adapters-ai.yml" "$WORK/ai/$CON"; mkdir -p "$WORK/ai/records/tiers"
  # the fixture's second waiver has no review_by on purpose: check-redteam is given "-", and governance flags it (GOV-W3)
  cp "$WORK/ai/docs/governance/ai-tier/"*.md "$WORK/ai/records/tiers/"; chk ai --env prod; expect_only ai GOV-W3 Medium
  app_line() { grep "^$(printf '%s' "$1" | sed 's|/|__|') | --app | $2 |" "$WORK/log" | tail -1; }
  app_exact() { if [ "$(app_line "$2" "$3")" = "$(printf '%s' "$2" | sed 's|/|__|') | --app | $3$4" ]; then ok; else bad "$1: $2 [$3] expected exactly '$4', got: $(app_line "$2" "$3" | cut -c1-400)"; fi; }
  app_exact ai ascent-ai/check-ai-design support-assistant ' | --root | services/support/ | --design | services/support/docs/ai/design-record.md | --tier-record | records/tiers/support-assistant.md | --prompts | services/support/prompts/ | --golden | services/support/tests/evals/golden/ | --pilot | services/support/docs/ai/pilot.md | --selection | services/support/docs/ai/model-bake-off.md | --fine-tune-runbook | docs/operations/fine-tune.md | --env | prod | --prod-env | prod | --app-root | screening-tool=services/screening/ | --today | 2026-12-02 | --threshold | Low | .'
  app_exact ai ascent-ai/check-ai-design screening-tool ' | --root | services/screening/ | --design | services/screening/docs/ai/design.md | --tier-record | records/tiers/screening-tool.md | --env | prod | --prod-env | prod | --app-root | support-assistant=services/support/ | --today | 2026-12-02 | --threshold | Low | .'
  app_exact ai ascent-ai/check-ai-evidence support-assistant ' | --golden | services/support/tests/evals/golden/ | --results | evidence/support-assistant/evals/latest.json | --format | promptfoo | --pass-rate | 0.90 | --attack-pass-rate | 1.0 | --max-age | 14 | --prompts | services/support/prompts/ | --retrieval | evidence/support-assistant/retrieval/latest.json | --retrieval-target | faithfulness=0.90 | --retrieval-target | context_recall=0.85 | --sources | services/support/docs/ai/sources.md | --review-by | 2027-02-01 | --review-notes | services/support/docs/ai/reviews.md | --tier-record | records/tiers/support-assistant.md | --today | 2026-12-02 | --no-git | --threshold | Low | .'
  app_exact ai ascent-ai/check-ai-evidence screening-tool ' | --golden | services/screening/tests/evals/golden/ | --tier-record | records/tiers/screening-tool.md | --today | 2026-12-02 | --no-git | --threshold | Low | .'
  app_exact ai ascent-ai/check-ai-runtime support-assistant ' | --root | services/support/ | --design | services/support/docs/ai/design-record.md | --capture-policy | services/support/docs/ai/capture-policy.md | --gateway-policy | deploy/gateway/policy.yaml | --tier-record | records/tiers/support-assistant.md | --app-root | screening-tool=services/screening/ | --threshold | Low | .'
  app_exact ai ascent-ai/check-ai-runtime screening-tool ' | --root | services/screening/ | --design | services/screening/docs/ai/design.md | --tier-record | records/tiers/screening-tool.md | --app-root | support-assistant=services/support/ | --threshold | Low | .'
  W=' | --waiver | ADR-031 2027-01-15 garak:dan.DanInTheWild,promptfoo:hijacking | --waiver | ADR-032 - GHSA-35jh-r3h4-6jhm'
  app_exact ai ascent-security/check-redteam support-assistant " | --max-age | 21 | --max-attack-success | 0.05 | --tier-record | records/tiers/support-assistant.md$W | --today | 2026-12-02 | --threshold | Low | evidence/support-assistant/redteam/"
  app_exact ai ascent-security/check-redteam screening-tool " | --max-age | 21 | --max-attack-success | 0.05 | --tier-record | records/tiers/screening-tool.md$W | --today | 2026-12-02 | --threshold | Low | evidence/screening-tool/redteam/"
  # the threat model is checked for the AI threats when there is an AI application, and only then
  arg ai ascent-security/check-threat-model --ai
  # with no ai_tier_dir, the default folder
  stubs; edit ai $CON "$(drop 'ai_tier_dir:')"; chk ai --env prod
  case "$(app_line ascent-ai/check-ai-design screening-tool)" in *"| --tier-record | docs/governance/ai-tier/screening-tool.md |"*) ok ;; *) bad "ai-tier-default: $(app_line ascent-ai/check-ai-design screening-tool | cut -c1-200)" ;; esac

  # --- every option in the table is one the real checker names --------------
  rows=0
  while IFS="$TAB" read -r chkname flag kind path def; do
    case "$chkname" in ''|'#'*) continue ;; esac
    rows=$((rows + 1))
    real="$REAL/${chkname%/*}/scripts/${chkname#*/}.sh"
    if [ ! -f "$real" ]; then bad "usage-drift: $chkname has no checker at $real"; continue; fi
    case "$kind" in scalar|list|csv|fmt|const|today|nogit|files|pos|posdir|each|item|itemfmt|others|words|env|toprung|when) ok ;; *) bad "usage-drift: $chkname has an unknown kind '$kind'" ;; esac
    [ "$flag" = - ] && continue
    if sed -n '1,/^set -/p' "$real" | grep '^# Usage:' | grep -qE -- "(\\[| )$flag( |\\]|$)"; then ok; else bad "usage-drift: $chkname is given $flag, which its usage line does not name"; fi
  done < "$TABLE"
  if [ "$rows" -ge 50 ]; then ok; else bad "usage-drift: only $rows adapter rows were read"; fi
  for c in $STUBS; do if grep -q "^$c$TAB" "$TABLE"; then ok; else bad "usage-drift: $c has no adapter row"; fi; done

  # --- every checker the table names refuses an unknown option in its own name ---
  # check-audit.sh reads an exit 2 as a usage error only when the first line is the
  # checker's own message (ADR-030); the list comes from the table, so a checker
  # added to it is held to that from the start
  mkdir -p "$WORK/usage-empty"; n=0
  for c in $(awk -F'\t' '$1 != "" && $1 !~ /^#/ { print $1 }' "$TABLE" | LC_ALL=C sort -u); do
    n=$((n + 1)); real="$REAL/${c%/*}/scripts/${c#*/}.sh"; name="${c#*/}"; rc=0
    bash "$real" --no-such-option "$WORK/usage-empty" > "$WORK/usage.out" 2>&1 </dev/null || rc=$?
    first=$(head -1 "$WORK/usage.out")
    if [ "$rc" -ne 2 ]; then bad "usage-first-line: $c exited $rc on an unknown option, not 2"
    else case "$first" in "$name: "*|"Usage: $name.sh"*) ok ;; *) bad "usage-first-line: $c's first line on an unknown option is not its own message: $first" ;; esac; fi
  done
  if [ "$n" -ge 9 ]; then ok; else bad "usage-first-line: only $n checkers were read from the table"; fi
  # ... and a bad value for each option the table gives it: a bad contract value is
  # the usage error GOV-S2 is for; an option that takes any value exits 0 or 1
  n=0
  while IFS="$TAB" read -r chkname flag kind path def; do
    case "$chkname" in ''|'#'*) continue ;; esac
    case "$flag:$kind" in -:*|*:nogit) continue ;; esac
    real="$REAL/${chkname%/*}/scripts/${chkname#*/}.sh"; name="${chkname#*/}"; rc=0
    bash "$real" "$flag" 'x!' "$WORK/usage-empty" > "$WORK/usage.out" 2>&1 </dev/null || rc=$?
    [ "$rc" -eq 2 ] || continue
    n=$((n + 1)); first=$(head -1 "$WORK/usage.out")
    case "$first" in "$name: "*|"Usage: $name.sh"*) ok ;; *) bad "usage-first-line: $chkname's first line on a bad $flag value is not its own message: $first" ;; esac
  done < "$TABLE"
  if [ "$n" -ge 40 ]; then ok; else bad "usage-first-line: only $n bad option values exited 2"; fi

  # --- acceptance records, one run each, since the last signed launch -------
  full acc; record acc records/acceptance/2026-10-01-old.md; record acc records/acceptance/2026-11-28-new.md
  printf '# Acceptance records\n' > "$WORK/acc/records/acceptance/README.md"
  chk acc; runs acc-all ascent-delivery/check-acceptance 3; has acc-all 'ascent-delivery/check-acceptance passes (3 records)'
  launch acc docs/governance/launches/2026-11-10-local.md 'Ana Lopez' 2026-11-10
  launch acc docs/governance/launches/2026-11-25-local.md '' 2026-11-25                      # not signed
  launch acc docs/governance/launches/2026-11-26-local.md 'Ana Lopez' 2026-11-26 NO-GO        # signed, but a NO-GO
  launch acc docs/governance/launches/2026-11-27-prod.md 'Ana Lopez' 2026-11-27               # another environment
  launch acc docs/governance/launches/2026-12-25-local.md 'Ana Lopez' 2026-12-25              # dated after today
  launch acc docs/governance/launches/2026-11-24-local.md 'Ana Lopez' 2026-11-31              # not a real date
  launch acc docs/governance/launches/2026-11-29-local.md 'Ana Lopez' 2026-12-25              # signed with a date after today
  launch acc docs/governance/launches/2026-09-01-local.md 'Ana Lopez' 2026-09-01              # an older launch
  : > "$WORK/log"; chk acc; runs acc-since ascent-delivery/check-acceptance 2; has acc-since 'since the launch signed on 2026-11-10'
  if grep -q '2026-10-01-old' "$WORK/log"; then bad "acc-since: the record from before the launch was checked"; else ok; fi
  : > "$WORK/log"; stub_rc ascent-delivery/check-acceptance 1; chk acc; expect_only acc-fail GOV-L1 High; has acc-fail 'records/acceptance/2026-11-20-scores.md'
  : > "$WORK/log"; stub_rc ascent-delivery/check-acceptance 2; chk acc; expect_only acc-usage GOV-S2 Medium; has acc-usage 'records/acceptance/2026-11-'
  full acc-same-day; launch acc-same-day docs/governance/launches/2026-11-20-local.md 'Ana Lopez' 2026-11-20
  chk acc-same-day; runs acc-same-day ascent-delivery/check-acceptance 1
  full acc-none-since; launch acc-none-since docs/governance/launches/2026-11-30-local.md 'Ana Lopez' 2026-11-30
  chk acc-none-since; expect_pass acc-none-since; runs acc-none-since ascent-delivery/check-acceptance 0
  has acc-none-since 'N/A   GOV-L1  ascent-delivery/check-acceptance: no acceptance record since the launch signed on 2026-11-30'
  full acc-none; rm -rf "${WORK:?}/acc-none/records"; chk acc-none; expect_only acc-none GOV-L2 Low
  runs acc-none ascent-delivery/check-acceptance 0; has acc-none 'no acceptance record in records/acceptance/'
  full acc-space; mkdir -p "$WORK/acc-space/my records"; cp "$WORK/acc-space/records/acceptance/2026-11-20-scores.md" "$WORK/acc-space/my records/"
  edit acc-space $CON "$(subst 'acceptance_dir: records/acceptance/' 'acceptance_dir: "my records"')" && chk acc-space && expect_pass acc-space
  arg acc-space ascent-delivery/check-acceptance 'my records/2026-11-20-scores.md'

  # --- entries the table cannot turn into a value ---------------------------
  full fmt-missing; edit fmt-missing $CON "$(drop '      auth: none')" && chk fmt-missing && expect_only fmt-missing GOV-S2 Medium
  has fmt-missing 'security.endpoints[1]'; has fmt-missing 'auth'
  arg fmt-missing ascent-security/check-threat-model --endpoint 'GET,DELETE /api/items/{id} required write' --today
  full fmt-no-steps; edit fmt-no-steps $CON "$(drop '      steps: [app/public/login.html, app/public/index.html]')" && chk fmt-no-steps && expect_only fmt-no-steps GOV-S2 Medium
  has fmt-no-steps 'ux.core_flows[1]'
  full pos-dash; edit pos-dash $CON "$(subst 'path: docs/sec/TM.md' 'path: --repo')" && chk pos-dash && arg pos-dash ascent-security/check-threat-model --today 2026-12-02 ./--repo
  full posdir-root; edit posdir-root $CON "$(subst '"app/public/**/*.html", "admin/*.html", "site/index.html"' '"*.html", "**/*.htm", "src/pa*/x.html", "lib/page?.html"')" && chk posdir-root
  arg posdir-root ascent-ux/check-flow-integrity --browsers last-2-evergreen,ios-safari-17 . src lib
  full empty-values; edit empty-values $CON "$(subst 'index: docs/decisions/INDEX.md' 'index: ""')" && chk empty-values && noarg empty-values ascent-adr/check-adrs --index

  # one record fails and another cannot be read: both are reported, in either order, and the failure decides
  for order in '1 2' '2 1'; do
    full acc-mixed; record acc-mixed records/acceptance/2026-11-28-new.md
    echo "${order% *}" > "$WORK/ctl/ascent-delivery__check-acceptance.rc.2026-11-20-scores.md"; echo "${order#* }" > "$WORK/ctl/ascent-delivery__check-acceptance.rc.2026-11-28-new.md"
    chk acc-mixed; expect_rc "acc-mixed ($order)" 1; has "acc-mixed ($order)" 'FAIL  GOV-L1  High   ascent-delivery/check-acceptance'; has "acc-mixed ($order)" 'FAIL  GOV-S2  Medium ascent-delivery/check-acceptance'
  done
  full acc-crash; echo 134 > "$WORK/ctl/ascent-delivery__check-acceptance.rc.2026-11-20-scores.md"; chk acc-crash; expect_only acc-crash GOV-L1 High; has acc-crash 'exited 134'
  # the most severe finding across every record is GOV-L1's severity, and the message
  # cites the first record that has it (ADR-029); a record whose checker stops is High
  acc_sev() {  # NAME RC-A LINES-A RC-B LINES-B — record A (2026-11-20) and B (2026-11-28)
    local k=ascent-delivery__check-acceptance ra=2026-11-20-scores.md rb=2026-11-28-new.md
    full "$1"; record "$1" "records/acceptance/$rb"
    echo "$2" > "$WORK/ctl/$k.rc.$ra"; printf "$3" > "$WORK/ctl/$k.out.$ra"
    echo "$4" > "$WORK/ctl/$k.rc.$rb"; printf "$5" > "$WORK/ctl/$k.out.$rb"
    chk "$1"
  }
  acc_sev acc-low-medium 1 'FAIL  DEL-A3  Low    a.md:5  low one\n' 1 'FAIL  DEL-A2  Medium b.md:5  medium one\n'
  expect_only acc-low-medium GOV-L1 Medium; has acc-low-medium '2026-11-28-new.md: DEL-A2 Medium b.md:5 medium one'; lacks acc-low-medium 'low one'
  acc_sev acc-medium-low 1 'FAIL  DEL-A2  Medium a.md:5  medium one\n' 1 'FAIL  DEL-A3  Low    b.md:5  low one\n'
  expect_only acc-medium-low GOV-L1 Medium; has acc-medium-low '2026-11-20-scores.md: DEL-A2 Medium a.md:5 medium one'; lacks acc-medium-low 'low one'
  acc_sev acc-low-crash 1 'FAIL  DEL-A3  Low    a.md:5  low one\n' 139 ''
  expect_only acc-low-crash GOV-L1 High; has acc-low-crash 'exited 139'
  # an exit 2 without the checker's own message is a crash on that record (ADR-030),
  # and a real usage error on another record is still reported beside it
  acc_sev acc-crash-2 0 '' 2 'awk: run time error\n'
  expect_only acc-crash-2 GOV-L1 High; has acc-crash-2 '2026-11-28-new.md: its checker exited 2 without finishing'
  acc_sev acc-usage-and-crash-2 2 'Usage: check-acceptance.sh [--root DIR] RECORD\n' 2 'awk: run time error\n'
  expect_rc acc-usage-and-crash-2 1; has acc-usage-and-crash-2 'FAIL  GOV-L1  High   ascent-delivery/check-acceptance'
  has acc-usage-and-crash-2 'FAIL  GOV-S2  Medium ascent-delivery/check-acceptance'; has acc-usage-and-crash-2 '2026-11-20-scores.md: Usage: check-acceptance.sh'

  # --- the good fixture through the real checkers: no usage error -----------
  mk real; realfiles real
  PLUGINS_DIR="$REAL" chk real --env prod; lacks real 'GOV-S2'
  # the fixture has no dependency manifest and its contract names no drill: those two checks have nothing to check, which is unmeasured, never a pass
  l2=$(printf '%s\n' "$OUT" | grep -c 'GOV-L2' || true); if [ "$l2" -eq 2 ]; then ok; else bad "real: expected 2 unmeasured checks, got $l2"; fi
  has real 'ascent-security/check-dependencies is unmeasured: it had nothing it could check here (SEC-D1,'; has real 'ascent-ops/check-drills is unmeasured: it had nothing it could check here (OPS-R1,'
  for c in $STUBS; do case "$c" in ascent-ai/*|ascent-security/check-redteam) continue ;; esac; has real "$c"; done
  has real 'PASS  GOV-L1  ascent-delivery/check-acceptance passes (1 record since the launch signed on 2026-01-05)'; has real 'PASS  GOV-L3'; has real 'PASS  GOV-L1  ascent-security/check-env passes (not checked here: SEC-E1, SEC-E2)'
  cp "$FIX/contracts/adapters-full.yml" "$WORK/real/$CON"; record real records/acceptance/2026-11-20-scores.md
  PLUGINS_DIR="$REAL" chk real; lacks real-full 'GOV-S2'
  l2=$(printf '%s\n' "$OUT" | grep -c 'GOV-L2' || true); if [ "$l2" -eq 1 ]; then ok; else bad "real-full: expected 1 unmeasured check, got $l2"; fi
  for c in $STUBS; do case "$c" in ascent-ai/*|ascent-security/check-redteam) continue ;; esac; has real-full "$c"; done
  has real-full 'OPS-R1 Medium absent orders-db (restore): runbook docs/ops/restore.md not found'
  # ascent-ai's real checkers, once for each application of the two-application fixture: no usage error, no crash
  mk real-ai ai-tier-multi; cp "$FIX/contracts/adapters-ai.yml" "$WORK/real-ai/$CON"; mkdir -p "$WORK/real-ai/records/tiers"; cp "$WORK/real-ai/docs/governance/ai-tier/"*.md "$WORK/real-ai/records/tiers/"; mkdir -p "$WORK/real-ai/services/support" "$WORK/real-ai/services/screening"
  PLUGINS_DIR="$REAL" chk real-ai --env prod; lacks real-ai 'GOV-S2'; lacks real-ai 'without finishing'
  for c in ascent-ai/check-ai-design ascent-ai/check-ai-evidence ascent-ai/check-ai-runtime ascent-security/check-redteam; do for a in support-assistant screening-tool; do has real-ai "$c [$a] "; done; done
  has real-ai 'ascent-security/check-redteam [support-assistant] failed: SEC-R1 Medium'; has real-ai 'ascent-security/check-redteam [screening-tool] failed: SEC-R1 High'; has real-ai 'ascent-security/check-threat-model failed: SEC-T1'
}
run_matrix
