#!/usr/bin/env bash
# Rule test for the ascent-delivery skill, references and hook (v0.4.7). Lessons
# from shipping this framework are pinned so they cannot silently go away:
#   D1  the runbook template tells the writer how to handle a stacked pull request:
#       retarget before the base merges, reopen to start CI, and replay with
#       `git rebase --onto` after a squash merge, flagging the force push
#   D2  the operator-boundary hook states why it is exempt from ascent-ops Z2 and Z3
#   D3  every references/<file> the skill links to exists
#
# Prints "test-delivery-rules: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-delivery"
SKILL="$PLUGIN/skills/delivery-loop/SKILL.md"
TEMPLATE="$PLUGIN/skills/delivery-loop/references/runbook-template.md"
HOOK="$PLUGIN/hooks/operator-boundary.sh"
for f in "$SKILL" "$TEMPLATE" "$HOOK"; do
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

# D2 — the hook's Z2/Z3 exemption is stated, and the hook still runs with set -u
has D2 "$HOOK" '# Exempt from ascent-ops Z2 and Z3 on purpose'
if grep -qx 'set -u' "$HOOK"; then ok; else bad "D2 hooks/operator-boundary.sh no longer runs with 'set -u'"; fi

# D3 — linked references exist
NREF=0
for r in $(grep -oE '\(references/[A-Za-z0-9._-]+\)' "$SKILL" | tr -d '()' | LC_ALL=C sort -u); do
  NREF=$((NREF + 1))
  if [ -f "$PLUGIN/skills/delivery-loop/$r" ]; then ok; else bad "D3 skills/delivery-loop/SKILL.md links $r, which does not exist"; fi
done
[ "$NREF" -gt 0 ] || bad "D3 no references/ links found in the skill"

printf "test-delivery-rules: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
