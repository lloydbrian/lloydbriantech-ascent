#!/usr/bin/env bash
# Rule test for the ascent-delivery skill, references and hook (v0.4.7). Lessons
# from shipping this framework are pinned so they cannot silently go away:
#   D1  the runbook template tells the writer how to handle a stacked pull request:
#       retarget before the base merges, reopen to start CI, and replay with
#       `git rebase --onto` after a squash merge, flagging the force push
#   D2  the operator-boundary hook states why it is exempt from ascent-ops OPS-Z2 and OPS-Z3
#   D3  every references/<file> the skill links to exists, in the skill or the plugin
#   0.2.0 (ADR-024):
#   D4  only a person accepts: Claude never fills "Accepted by" or "Accepted on"
#   D5  the definition of done checks the record's evidence (--draft), and a failing
#       record stops prod, in the skill and in the prod runbook's first step
#   D6  the contract is the delivery: section of .ascent/contract.yml (or
#       .claude/contract.yml); .delivery-loop.yml still works; the hook blocks both
#   D7  every runbook step is labelled [C] (read-only) or [O] (writes, deploys)
#   D8  the acceptance template's columns are the ones check-acceptance.sh reads
#
# Prints "test-delivery-rules: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-delivery"
SKILL="$PLUGIN/skills/delivery-loop/SKILL.md"
TEMPLATE="$PLUGIN/skills/delivery-loop/references/runbook-template.md"
HOOK="$PLUGIN/hooks/operator-boundary.sh"
ACCEPT="$PLUGIN/skills/delivery-loop/references/acceptance-template.md"
CONTRACT="$PLUGIN/references/contract-template.yml"
for f in "$SKILL" "$TEMPLATE" "$HOOK" "$ACCEPT" "$CONTRACT"; do
  [ -f "$f" ] || { echo "test-delivery-rules: missing $f"; echo "test-delivery-rules: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
has() {  # ID FILE FIXED-STRING
  if grep -qF -- "$3" "$2"; then ok; else bad "$1 ${2#"$PLUGIN"/} does not contain: $3"; fi
}

# D1 — stacked pull requests
has D1 "$TEMPLATE" '- **Stacked pull requests.**'
has D1 "$TEMPLATE" 'before its base PR merges, because that merge deletes the base branch.'
has D1 "$TEMPLATE" 'Retargeting does not start CI. Close and reopen the pull request'
has D1 "$TEMPLATE" 'git rebase --onto origin/main <old base tip> <branch>'
has D1 "$TEMPLATE" 'Flag the force push as destructive in the runbook.'

# D2 — the hook's OPS-Z2/Z3 exemption is stated, and the hook still runs with set -u
has D2 "$HOOK" '# Exempt from ascent-ops OPS-Z2 and OPS-Z3 on purpose'
if grep -qx 'set -u' "$HOOK"; then ok; else bad "D2 hooks/operator-boundary.sh no longer runs with 'set -u'"; fi

# D3 — linked references exist
NREF=0
for r in $(grep -oE '\(references/[A-Za-z0-9._-]+\)' "$SKILL" | tr -d '()' | LC_ALL=C sort -u); do
  NREF=$((NREF + 1))
  if [ -f "$PLUGIN/skills/delivery-loop/$r" ]; then ok; else bad "D3 skills/delivery-loop/SKILL.md links $r, which does not exist"; fi
done
for r in $(grep -oE '\(\.\./\.\./references/[A-Za-z0-9._-]+\)' "$SKILL" | tr -d '()' | LC_ALL=C sort -u); do
  NREF=$((NREF + 1))
  if [ -f "$PLUGIN/skills/delivery-loop/$r" ]; then ok; else bad "D3 skills/delivery-loop/SKILL.md links $r, which does not exist"; fi
done
[ "$NREF" -gt 0 ] || bad "D3 no references/ links found in the skill"

# D4 — only a person accepts
has D4 "$SKILL" 'Claude never fills either column, even when asked: say who must, and why.'
has D4 "$SKILL" '- Fill in "Accepted by" or "Accepted on", or accept a criterion on anyone'"'"'s behalf.'
has D4 "$ACCEPT" '**Only a person fills in "Accepted by" and "Accepted on"**'
has D4 "$TEMPLATE" 'fill in "Accepted by" and "Accepted on" in `<acceptance record>` themselves. Claude never fills them in.'

# D5 — the record is checked at done, and before prod
has D5 "$SKILL" 'bash "$PLUGIN_ROOT/scripts/check-acceptance.sh" --draft --root .'
has D5 "$SKILL" 'stops prod. The prod runbook'"'"'s first step runs the same check, labelled C'
has D5 "$SKILL" '- the acceptance record fails `check-acceptance.sh`: with `--draft` in Step 5, in full before prod (Step 7);'
has D5 "$TEMPLATE" '### P1. [C] The acceptance record passes'
has D5 "$TEMPLATE" '**Stop if** any line starts `FAIL`. Prod does not run'

# D6 — the contract: the delivery: section, the older file, the union in the hook
has D6 "$SKILL" 'Read the `delivery:` section of `.ascent/contract.yml`'
has D6 "$SKILL" 'read it when there is no `delivery:` section'
has D6 "$SKILL" 'Until then the hook blocks the deploy commands of both.'
has D6 "$HOOK" 'section of .ascent/contract.yml and of .claude/contract.yml'
if [ "$(sed -n 's/^\([a-z_][a-z0-9_]*\):.*/\1/p' "$CONTRACT" | tr '\n' ' ')" = "version delivery " ]; then ok; else bad "D6 references/contract-template.yml declares more than version and delivery:"; fi
for k in gate fast_gate deploy_beta deploy_prod acceptance_dir acceptors; do
  if grep -q "^  $k:" "$CONTRACT"; then ok; else bad "D6 references/contract-template.yml has no delivery.$k"; fi
done

# D7 — every runbook step says who runs it
has D7 "$SKILL" '**Label every step C or O.**'
NSTEP=0
while IFS= read -r h; do
  NSTEP=$((NSTEP + 1))
  case "$h" in *"[C]"*|*"[O]"*) ok ;; *) bad "D7 runbook-template.md step without [C] or [O]: $h" ;; esac
done <<EOF_STEPS
$(grep -E '^### (P?[0-9]+)\. ' "$TEMPLATE")
EOF_STEPS
[ "$NSTEP" -ge 8 ] || bad "D7 expected at least 8 numbered steps in runbook-template.md, found $NSTEP"

# D8 — the template's table is the one the check reads
has D8 "$ACCEPT" '| # | Criterion | Evidence | Accepted by | Accepted on |'

# D9 — launch evidence before prod (ADR-028): only with a governance section, labelled C,
# NO-GO stops prod, and a missing plugin is said and skipped
has D9 "$SKILL" '- **Launch evidence.** When the contract has a `governance` section, the prod runbook'"'"'s second step runs'
has D9 "$SKILL" 'check-audit.sh --env prod .`'
has D9 "$SKILL" 'labelled C; its **Stop if** is `NO-GO`, or any exit other than 0 (the script exits 2, with no verdict, when it cannot read what it was given).'
has D9 "$SKILL" 'When `ascent-governance` isn'"'"'t available, say so and skip it'
has D9 "$SKILL" '$PLUGIN_ROOT/../ascent-governance/scripts/check-audit.sh'
has D9 "$SKILL" '- the launch evidence check prints `NO-GO`, or exits with anything but 0 (Step 7);'
if [ -f "$PLUGIN/../ascent-governance/scripts/check-audit.sh" ]; then ok; else bad "D9 the path the skill names for check-audit.sh does not exist in a checkout"; fi

printf "test-delivery-rules: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
