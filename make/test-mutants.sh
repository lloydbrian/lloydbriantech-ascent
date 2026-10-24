#!/usr/bin/env bash
# Negative-control harness for the embedded-skill tests (ADR-008).
#
# A test that has never failed proves nothing. For every row in make/mutants.tsv
# this script:
#   1. copies a freshly rendered project,
#   2. applies the mutant's sed expression and confirms it changed the file
#      (a stale anchor is reported as ANCHOR MISS, never as a pass),
#   3. runs the named test and expects it to FAIL ("killed").
# Before any mutant runs, every named test must pass on the unmutated project,
# so a kill always means the mutation was detected, not that the test was broken.
#
# Portable: GNU/Linux and BSD/macOS, bash 3.2+.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MUTANTS="$REPO_ROOT/make/mutants.tsv"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT INT TERM

bash "$REPO_ROOT/make/render-template.sh" "$WORK/base" >/dev/null

# Control run: each named test passes unmutated.
tests_named=$(grep -v '^#' "$MUTANTS" | awk -F'\t' 'NF>=4 {print $4}' | LC_ALL=C sort -u)
for t in $tests_named; do
  if ! (cd "$WORK/base" && bash "tests/skills/$t" </dev/null >/dev/null 2>&1); then
    echo "test-mutants: control run failed — $t does not pass on the unmutated project:"
    (cd "$WORK/base" && bash "tests/skills/$t" </dev/null) || true
    exit 1
  fi
done

killed=0; survived=0; missed=0; total=0
expected_rows=$(grep -v '^#' "$MUTANTS" | grep -c . || true)
while IFS="$(printf '\t')" read -r id file expr test desc; do
  case "$id" in ''|\#*) continue ;; esac
  total=$((total + 1))
  rm -rf "$WORK/m"
  cp -R "$WORK/base" "$WORK/m"
  target="$WORK/m/$file"
  if [ ! -f "$target" ]; then
    printf "  ANCHOR MISS  %-28s %s not found\n" "$id" "$file"
    missed=$((missed + 1)); continue
  fi
  cp "$target" "$WORK/before"
  sed -i.mut-bak -e "$expr" "$target" && rm -f "$target.mut-bak"
  if cmp -s "$WORK/before" "$target"; then
    printf "  ANCHOR MISS  %-28s sed changed nothing in %s\n" "$id" "$file"
    missed=$((missed + 1)); continue
  fi
  if (cd "$WORK/m" && bash "tests/skills/$test" </dev/null >/dev/null 2>&1); then
    printf "  SURVIVED     %-28s %s — %s still passes\n" "$id" "$desc" "$test"
    survived=$((survived + 1))
  else
    printf "  killed       %-28s by %s\n" "$id" "$test"
    killed=$((killed + 1))
  fi
done < "$MUTANTS"
mutant_rows=$total

if [ "$mutant_rows" -ne "$expected_rows" ]; then
  echo "test-mutants: ran $mutant_rows of $expected_rows mutant rows — a row was skipped or malformed"
  exit 1
fi

# Validator controls: qa-skill-frontmatter must reject each broken SKILL.md
# and accept the well-formed one.
write_skill() {  # DIR NAME DESCRIPTION
  mkdir -p "$1"
  printf -- '---\nname: %s\ndescription: >-\n  %s\nversion: 0.0.0\nallowed-tools:\n  - Read\n---\n# body\n' "$2" "$3" > "$1/SKILL.md"
}
validator_case() {  # ID EXPECT(pass|fail) NAME DIRNAME DESCRIPTION
  local root="$WORK/v-$1"
  rm -rf "$root"
  write_skill "$root/$4" "$3" "$5"
  total=$((total + 1))
  if bash "$REPO_ROOT/make/qa-skill-frontmatter.sh" "$root" >/dev/null 2>&1; then got=pass; else got=fail; fi
  if [ "$got" = "$2" ]; then
    printf "  confirmed    %-28s validator answered %s\n" "$1" "$got"
    killed=$((killed + 1))
  else
    printf "  SURVIVED     %-28s validator answered %s, expected %s\n" "$1" "$got" "$2"
    survived=$((survived + 1))
  fi
}
validator_case V00-wellformed pass ascent-x ascent-x "Use when asked to do x. Does x."
validator_case V01-no-trigger fail ascent-x ascent-x "Does x for the project."
validator_case V02-placeholder fail ascent-x ascent-x "Use when asked to do x for <<PROJECT_TITLE>>."
validator_case V03-name-mismatch fail ascent-y ascent-x "Use when asked to do x. Does x."

# Plugin controls (ADR-009): make/test-plugins.sh must fail on each broken copy
# of the repository, and fail with the check named in EXPECT, so a control
# cannot pass because some other check happened to break. A baseline copy with
# no change must pass first, or every control below would be meaningless.
plugin_copy() {  # DIR — fresh copy of the repository without .git
  rm -rf "$1"; mkdir -p "$1"
  (cd "$REPO_ROOT" && tar --exclude ./.git -cf - .) | (cd "$1" && tar -xf -)
}
plugin_gate() {  # DIR — run test-plugins on a copy; output to $WORK/plugin-out
  ASCENT_SKIP_CLAUDE_CLI=1 ASCENT_HOOK_TEST_ONE_AWK=1 bash "$1/make/test-plugins.sh" "$1" </dev/null >"$WORK/plugin-out" 2>&1
}
plugin_copy "$WORK/p-baseline"
total=$((total + 1))
if plugin_gate "$WORK/p-baseline"; then
  printf "  control      %-28s unmodified copy passes test-plugins\n" "P00-baseline"
  killed=$((killed + 1))
else
  printf "  CONTROL FAIL %-28s unmodified copy fails test-plugins:\n" "P00-baseline"
  grep '^FAIL' "$WORK/plugin-out" | sed 's/^/                 /'
  survived=$((survived + 1))
fi

plugin_case() {  # ID EXPECT-LABEL FILE(relative to repo) SED-EXPRESSION [rebuild]
  local copy="$WORK/p-$1"
  plugin_copy "$copy"
  total=$((total + 1))
  cp "$copy/$3" "$WORK/before"
  sed -i.mut-bak -e "$4" "$copy/$3" && rm -f "$copy/$3.mut-bak"
  if cmp -s "$WORK/before" "$copy/$3"; then
    printf "  ANCHOR MISS  %-28s sed changed nothing in %s\n" "$1" "$3"
    missed=$((missed + 1)); return 0
  fi
  if [ "${5:-}" = rebuild ] && ! bash "$copy/make/build-plugins.sh" >/dev/null 2>&1; then
    printf "  SURVIVED     %-28s rebuild failed before the gate ran\n" "$1"
    survived=$((survived + 1)); return 0
  fi
  plugin_judge "$1" "$2" "$copy"
}
plugin_judge() {  # ID EXPECT-LABEL COPY — run the gate and classify the result
  if plugin_gate "$3"; then
    printf "  SURVIVED     %-28s test-plugins still passes\n" "$1"
    survived=$((survived + 1))
  elif grep -q "^FAIL  test-plugins: $2 " "$WORK/plugin-out"; then
    printf "  killed       %-28s by test-plugins %s\n" "$1" "$2"
    killed=$((killed + 1))
  else
    printf "  SURVIVED     %-28s failed, but not on %s: %s\n" "$1" "$2" \
      "$(grep '^FAIL' "$WORK/plugin-out" | sed 's/^FAIL  test-plugins: //' | cut -c1-60 | tr '\n' ';')"
    survived=$((survived + 1))
  fi
}
plugin_case_rm() {  # ID EXPECT-LABEL PATH(relative to repo) — the control deletes PATH
  local copy="$WORK/p-$1"
  plugin_copy "$copy"
  total=$((total + 1))
  if [ ! -e "$copy/$3" ]; then
    printf "  ANCHOR MISS  %-28s %s not found\n" "$1" "$3"
    missed=$((missed + 1)); return 0
  fi
  rm -rf "${copy:?}/$3"
  plugin_judge "$1" "$2" "$copy"
}
SEC=plugins/ascent-security
TPL=skills/lloydbriantech-ascent/assets/template/.claude/skills
AGENT="$SEC/agents/security-auditor.md"
plugin_case P01-hand-edited-skill T1 "$SEC/skills/env-audit/SKILL.md" '$a\
Hand edit that bypasses the template source.'
plugin_case P02-agent-can-write T4 "$AGENT" 's/^tools: Read, Grep, Glob$/tools: Read, Grep, Glob, Write/'
plugin_case P03-severity-drift T5 "$TPL/ascent-sec-posture/SKILL.md" 's/| No `.env.example` (no secrets inventory) | Low |/| No `.env.example` (no secrets inventory) | Medium |/' rebuild
plugin_case P04-version-mismatch T3 .claude-plugin/marketplace.json 's/"version": "0.1.1"/"version": "0.1.2"/'
plugin_case P05-agent-links-template T6 "$AGENT" '$a\
See [sec-posture](../skills/ascent-sec-posture/SKILL.md).'
plugin_case P06-source-not-rebuilt T1 "$TPL/ascent-env-audit/SKILL.md" 's/never echo the value/never print the value/'
plugin_case P07-agent-cites-missing-step T9 "$AGENT" 's/(security-audit Step 4)/(security-audit Step 9)/'
plugin_case P08-agent-extra-key T4 "$AGENT" 's/^model: inherit$/model: inherit\
permissionMode: bypassPermissions/'
plugin_case P09-skill-wide-tools T4b "$TPL/ascent-security-audit/SKILL.md" 's/^  - Glob$/  - Glob\
  - Bash/' rebuild
plugin_case P10-marketplace-bad-source T3 .claude-plugin/marketplace.json 's|"source": "./plugins/ascent-security"|"source": "./plugins/ascent-securty"|'
plugin_case P11-agent-cites-unknown-skill T9 "$AGENT" 's/(security-audit Step 5)/(secrets-audit Step 5)/'
plugin_case P12-agent-cites-nothing T9 "$AGENT" 's/Step/Stage/g'
plugin_case P13-severity-table-removed T5 "$TPL/ascent-sec-posture/SKILL.md" '/severity-table:start/d' rebuild
plugin_case P14-content-changed-no-bump T10 "$AGENT" '$a\
A line added without bumping the plugin version.'
DEL=plugins/ascent-delivery
HOOK="$DEL/hooks/operator-boundary.sh"
VERIFIER="$DEL/agents/finding-verifier.md"
plugin_case P15-hook-allows-git-push T11 "$HOOK" 's/GIT_READ = " status /GIT_READ = " push status /'
plugin_case P16-hook-ignores-contract T11 "$HOOK" 's/cur = (key == "deploy_beta" || key == "deploy_prod") ? key : ""/cur = ""/'
plugin_case P17-hook-test-emptied T11 tests/plugins/ascent-delivery/test-operator-boundary.sh '1,$d'
plugin_case_rm P18-hook-tests-removed T11 tests/plugins/ascent-delivery
plugin_case P19-verifier-can-write T4 "$VERIFIER" 's/^tools: Read, Grep, Glob$/tools: Read, Grep, Glob, Write/'
plugin_case P20-skill-links-missing-ref T6 "$DEL/skills/delivery-loop/SKILL.md" 's|(references/review-lenses.md)|(references/review-lens.md)|'
plugin_case P21-hooks-json-missing-script T11 "$DEL/hooks/hooks.json" 's|hooks/operator-boundary.sh|hooks/operator-guard.sh|'
plugin_case P22-verifier-cites-missing-step T9 "$VERIFIER" 's/(delivery-loop Step 4)/(delivery-loop Step 9)/'
plugin_case P23-hook-skips-substitutions T11 "$HOOK" 's/for (k = 1; k <= NSUB; k++) enqueue(SUBS\[k\])/k = 0/'
plugin_case P24-hook-skips-git-global-opts T11 "$HOOK" 's/if (has(" -C -c --git-dir --work-tree --namespace --super-prefix --config-env --attr-source ", SW\[j\])) j += 2; else j++/j++/'
plugin_case P25-hook-heredoc-in-substitution T11 "$HOOK" 's/if (!arith \&\& c == "<" \&\& A\[i + 1\] == "<") {/if (0) {/'
plugin_case P26-hook-no-size-guard T11 "$HOOK" 's/if (nb > MAXB) {/if (0) {/'
plugin_case P27-hook-ignores-stdin-shells T11 "$HOOK" 's/if (j > SN) { STDIN_SHELL = 1; return 0 }/if (j > SN) return 0/'
plugin_case P28-hook-skips-unquoted-heredocs T11 "$HOOK" 's/if (!HQ\[k\]) scan_subs(b, HDBEND, 0)/if (0) scan_subs(b, HDBEND, 0)/'
plugin_case P29-contract-denies-whole-chain T11 "$HOOK" 's/if (SN > 0 \&\& !inpipe) { dn = SN;/if (SN > 0 \&\& !inpipe \&\& dn == 0) { dn = SN;/'
ARC=plugins/ascent-architecture
ARC_AGENT="$ARC/agents/architecture-reviewer.md"
EST="$ARC/scripts/estimate-cost.sh"
CFN="$ARC/scripts/check-cfn-static-site.sh"
BPT="$ARC/blueprints/static-site-serverless-aws"
plugin_case P30-arch-agent-can-write T4 "$ARC_AGENT" 's/^tools: Read, Grep, Glob$/tools: Read, Grep, Glob, Edit/'
plugin_case P31-arch-agent-cites-missing-step T9 "$ARC_AGENT" 's/(architecture-review Step 4)/(architecture-review Step 9)/'
plugin_case P32-estimate-ignores-free-tier T11 "$EST" 's/^      f = fr\[k\] + 0$/      f = 0/'
plugin_case P33-estimate-drops-unknown-key T11 "$EST" 's/if (!(k in per)) fail("unknown usage key/if (!(k in per)) next; if (0) fail("unknown usage key/'
plugin_case P34-estimate-no-stale-warning T11 "$EST" 's/if (age > 90) printf/if (age > 900) printf/'
plugin_case P35-cfn-allows-http T11 "$CFN" 's/allow-all") || !has(r, "ViewerProtocolPolicy:")) f3/never-matches") || !has(r, "ViewerProtocolPolicy:")) f3/'
plugin_case P36-cfn-reads-comments T11 "$CFN" 's/^  if (line ~ \/\^ \*#\/) line = ""$//;s/^  sub(\/ +#\.\*\$\/, "", line)$//'
plugin_case P37-cfn-pitr-not-required T11 "$CFN" 's/if (ty == "AWS::DynamoDB::Table" \&\& !has(r, "PointInTimeRecoveryEnabled/if (0 \&\& !has(r, "PointInTimeRecoveryEnabled/'
plugin_case P38-blueprint-public-bucket T11 "$BPT/template.yaml" 's/RestrictPublicBuckets: true/RestrictPublicBuckets: false/'
plugin_case P39-blueprint-data-not-retained T11 "$BPT/template.yaml" '/^    DeletionPolicy: Retain$/d'
plugin_case P40-blueprint-readme-cost-drift T11 "$BPT/README.md" 's/\*\*0\.86 USD\*\*/**0.80 USD**/'
plugin_case P41-pricing-changed-no-bump T10 "$ARC/pricing/aws-us-east-1.tsv" 's/^\(lambda_requests.\{1,20\}\)0\.20/\10.25/'
plugin_case_rm P42-arch-tests-removed T11 tests/plugins/ascent-architecture
plugin_case P43-arch-skill-links-missing-ref T6 "$ARC/skills/architecture-review/SKILL.md" 's|(../../references/architecture-principles.md)|(../../references/architecture-principle.md)|'
plugin_case P44-cfn-severity-drift T11 "$CFN" 's/^#   C8  High /#   C8  Medium /'
plugin_case P45-estimate-ignores-pools T11 "$EST" 's/if (pool\[k\] != "") { if (f > left\[pool\[k\]\]) f = left\[pool\[k\]\] }/if (0) f = 0/'
plugin_case P46-estimate-ignores-plan-needs T11 "$EST" 's/if (pr\[col\[nl\[j\]\]\] != "yes") fits = 0/if (0) fits = 0/'
plugin_case P47-cfn-one-oac-hides-another T11 "$CFN" 's/nbad = s3_without_oac(r)/nbad = ncfg - noac/'
plugin_case P48-cfn-skips-flow-resources T11 "$CFN" 's/if (line !~ \/\^ \*\[A-Za-z0-9\]+: \*\$\/) die(/if (0) die(/'
plugin_case P49-arch-severity-copy-drift T5 "$ARC_AGENT" 's/| Log groups without retention, or no access logs at the CDN | Low |/| Log groups without retention, or no access logs at the CDN | Medium |/'
REVIEW="$ARC/skills/architecture-review/SKILL.md"
DEPLOY="$ARC/skills/deployment-options/SKILL.md"
plugin_case P50-arch-new-row-drift T5 "$ARC_AGENT" 's/leaves partial state (section 4, API design) | Medium |/leaves partial state (section 4, API design) | Low |/'
plugin_case P51-review-pricing-path-wrong T11 "$REVIEW" 's|\$PLUGIN_ROOT/pricing/aws-us-east-1.tsv|$PLUGIN_ROOT/references/aws-us-east-1.tsv|g'
plugin_case P52-review-invents-maturity-value T11 "$REVIEW" 's/is one of enterprise, standard or prototype/is one of enterprise, standard or club-static/'
plugin_case P53-agent-rates-off-table T11 "$ARC_AGENT" 's/goes under \*\*Other observations (unrated)\*\*/gets the nearest severity/'
plugin_case P54-unset-target-rated-met T11 "$REVIEW" 's/unmeasured, never met/unmeasured or met/'
plugin_case P55-review-carries-findings-over T11 "$REVIEW" '/^- \*\*Fresh evidence\.\*\*/d'
plugin_case P56-deploy-report-path-only T11 "$DEPLOY" '/^- \*\*Everything in the report\.\*\*/d'
plugin_case P57-deploy-cites-missing-step T11 "$DEPLOY" 's/architecture-review Step 0/architecture-review Step 9/'
plugin_case P58-review-skips-client-secrets T11 "$REVIEW" 's/, and secrets in client code: search the served HTML and JavaScript and the templates for credential-like assignments/, and secrets in templates/'
plugin_case P59-agent-secrets-only-when-published T11 "$ARC_AGENT" 's/a hit is High whether or not the page is published yet/a hit is High once the page is published/'
plugin_case P60-review-drops-security-referral T11 "$REVIEW" 's/ Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`\.//'
plugin_case P61-agent-at-risk-rule-removed T11 "$ARC_AGENT" 's/; it is at risk instead when the evidence shows a gap\././'

printf "\ntest-mutants: %s mutants — %s killed, %s survived, %s anchor misses\n" \
  "$total" "$killed" "$survived" "$missed"
[ "$survived" -eq 0 ] && [ "$missed" -eq 0 ] && [ "$total" -gt 0 ]
