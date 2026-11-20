#!/usr/bin/env bash
# Rule test for the ascent-adr skills, agent and references (ADR-027):
#   R1  every $PLUGIN_ROOT/<path> a skill names exists
#   R2  every rule id a script prints is in the severity table at the severity the
#       script's header gives it, and in references/decision-rules.md at the same
#       severity; the table and the reference name no id the scripts do not print
#   R3  adr-check, decision-drift and the agent route off-table concerns to "Other
#       observations (unrated)", and never judge whether a decision is right
#   R4  every decisions.<key> a skill or the agent names is a key of the contract
#       template, and every template key is used by a skill
#   R5  every "<skill> Step N" a skill or the agent cites names a skill and a
#       "### Step N" heading that exist
#   R6  adr-write writes only after approval and only the ADR, its index row and an
#       old ADR's status line; it never edits an accepted body and never commits
#   R7  the agent reports DEC-S8 as not assessed, and the skills never propose an
#       acknowledgement on their own
#   R8  every script parses and runs under the system /bin/bash (3.2 on macOS) with
#       the same result as the bash on PATH
#   R9  the README and decision-rules.md name the same rule ids as the scripts
#
# Prints "test-adr-rules: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../../.."
PLUGIN="$ROOT/plugins/ascent-adr"
CHECKS="$PLUGIN/skills/adr-check/SKILL.md"
WRITE="$PLUGIN/skills/adr-write/SKILL.md"
DRIFT="$PLUGIN/skills/decision-drift/SKILL.md"
AGENT="$PLUGIN/agents/decision-reviewer.md"
TEMPLATE="$PLUGIN/references/contract-template.yml"
RULES="$PLUGIN/references/decision-rules.md"
README="$PLUGIN/README.md"
SCRIPTS="$PLUGIN/scripts/check-adrs.sh $PLUGIN/scripts/check-decision-drift.sh"
for f in "$CHECKS" "$WRITE" "$DRIFT" "$AGENT" "$TEMPLATE" "$RULES" "$README" $SCRIPTS; do
  [ -f "$f" ] || { echo "FAIL  test-adr-rules: missing $f"; echo "test-adr-rules: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
has() { if grep -qF -- "$3" "$2"; then ok; else bad "$1 ${2#"$ROOT"/} does not contain: $3"; fi; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

# R1 — named plugin paths exist
for f in "$CHECKS" "$WRITE" "$DRIFT"; do
  for p in $(grep -o '\$PLUGIN_ROOT/[A-Za-z0-9_./-]*' "$f" | sed 's/^\$PLUGIN_ROOT\///' | LC_ALL=C sort -u); do
    if [ -e "$PLUGIN/$p" ]; then ok; else bad "R1 ${f#"$ROOT"/} names \$PLUGIN_ROOT/$p, which does not exist"; fi
  done
done

# R2 — script ids, the severity table and the reference agree
table() { awk '/<!-- dec-severity:start/{on=1; next} /<!-- dec-severity:end/{on=0} on' "$CHECKS"; }
for s in $SCRIPTS; do
  sed -n '/^# Checks/,/^# At prototype/p' "$s" | grep -Eo 'DEC-[SC][0-9]+  (Medium|Low|High)' > "$WORK/ids" || true
  [ -s "$WORK/ids" ] || bad "R2 ${s#"$ROOT"/}: no rule ids in its header"
  while read -r id sev; do
    k=${id#DEC-}
    cat "$s" "$PLUGIN/scripts/lib/check-adrs.awk" | grep -qE "fail\(\"$k\", \"$sev\"|fail $k $sev " || bad "R2 $id: no fail() in ${s#"$ROOT"/} or its awk reports it at $sev"
    row=$(table | grep "($id)" || true)
    case "$row" in *"| $sev |") ok ;; "") bad "R2 $id is not in the dec-severity table" ;; *) bad "R2 $id is $sev in ${s#"$ROOT"/} but the table says: $row" ;; esac
    if grep -q "^| $id | $sev |" "$RULES"; then ok; else bad "R2 $id is not $sev in references/decision-rules.md"; fi
  done < "$WORK/ids"
done
cat $SCRIPTS | sed -n '/^# Checks/,/^# At prototype/p' | grep -Eo 'DEC-[SC][0-9]+' | LC_ALL=C sort -u > "$WORK/script-ids"
table | grep -Eo 'DEC-[SC][0-9]+' | LC_ALL=C sort -u > "$WORK/table-ids"
grep -Eo '^\| DEC-[SC][0-9]+' "$RULES" | sed 's/^| //' | LC_ALL=C sort -u > "$WORK/rule-ids"
if cmp -s "$WORK/script-ids" "$WORK/table-ids"; then ok; else bad "R2 the severity table and the scripts name different ids: $(diff "$WORK/script-ids" "$WORK/table-ids" | grep '^[<>]' | tr '\n' ' ')"; fi
if cmp -s "$WORK/script-ids" "$WORK/rule-ids"; then ok; else bad "R2 decision-rules.md and the scripts name different ids: $(diff "$WORK/script-ids" "$WORK/rule-ids" | grep '^[<>]' | tr '\n' ' ')"; fi

# R3 — off-table concerns are unrated; a decision is never judged right or wrong
for f in "$CHECKS" "$DRIFT" "$AGENT"; do has R3 "$f" 'Other observations (unrated)'; done
has R3 "$CHECKS" 'Never judge whether a decision is right'
has R3 "$AGENT" 'including a decision you think is wrong'

# R4 — contract keys
awk '/^decisions:/{on=1; next} on && /^[^ #]/{on=0} on && /^  [a-z_]+:/{k=$1; sub(/:$/, "", k); print k}' "$TEMPLATE" | LC_ALL=C sort -u > "$WORK/keys"
[ -s "$WORK/keys" ] || bad "R4 no keys under decisions: in the contract template"
cat "$CHECKS" "$WRITE" "$DRIFT" "$AGENT" | grep -o 'decisions\.[a-z_]*' | sed 's/^decisions\.//' | LC_ALL=C sort -u > "$WORK/used"
while read -r k; do if grep -qx "$k" "$WORK/keys"; then ok; else bad "R4 decisions.$k is named but is not a key of the contract template"; fi; done < "$WORK/used"
for k in $(cat "$WORK/keys"); do
  if cat "$CHECKS" "$WRITE" "$DRIFT" | grep -qE "(decisions\.|\`)$k\b|$k\`"; then ok; else bad "R4 contract key decisions.$k is used by no skill"; fi
done

# R5 — cited steps exist
for f in "$CHECKS" "$WRITE" "$DRIFT" "$AGENT"; do
  grep -oE '(adr-check|adr-write|decision-drift) Steps? [0-9]+' "$f" | LC_ALL=C sort -u | while read -r sk _ n; do
    t="$PLUGIN/skills/$sk/SKILL.md"
    if [ -f "$t" ] && grep -q "^### Step $n " "$t"; then echo ok; else echo "bad R5 ${f#"$ROOT"/} cites $sk Step $n, which does not exist"; fi
  done
done > "$WORK/r5"
while read -r l; do case "$l" in ok) ok ;; *) bad "${l#bad }" ;; esac; done < "$WORK/r5"

# R6 — adr-write's write boundary
has R6 "$WRITE" 'Write only after approval, and only these files'
has R6 "$WRITE" "Never edit an accepted ADR's body"
has R6 "$WRITE" 'Never commit'
has R6 "$WRITE" 'After confirmation only'

# R7 — DEC-S8 and acknowledgements
has R7 "$AGENT" 'Not assessed: DEC-S8'
has R7 "$CHECKS" 'Never propose an acknowledgement on your own'
has R7 "$TEMPLATE" 'Add one only after a person has read the change'

# R8 — /bin/bash gives the same result as bash on PATH
run_both() {  # SCRIPT ARGS — the fixture, under each bash
  (cd "$HERE/fixtures/adr-ascent" && bash "$@" >"$WORK/out-path" 2>&1; echo "exit $?" >>"$WORK/out-path")
  (cd "$HERE/fixtures/adr-ascent" && /bin/bash "$@" >"$WORK/out-sys" 2>&1; echo "exit $?" >>"$WORK/out-sys")
}
if [ -x /bin/bash ]; then
  run_both "$PLUGIN/scripts/check-adrs.sh" --no-git --today 2026-11-20
  if grep -q '^exit 0$' "$WORK/out-path" && cmp -s "$WORK/out-path" "$WORK/out-sys"; then ok; else bad "R8 check-adrs.sh: /bin/bash differs or fails: $(diff "$WORK/out-path" "$WORK/out-sys" | head -3 | tr '\n' ' ')$(tail -2 "$WORK/out-path" | tr '\n' ' ')"; fi
  run_both "$PLUGIN/scripts/check-decision-drift.sh" --forbid ADR-3 mysql --under src/ --require ADR-2 infra/cloudformation/
  if grep -q '^exit 0$' "$WORK/out-path" && cmp -s "$WORK/out-path" "$WORK/out-sys"; then ok; else bad "R8 check-decision-drift.sh: /bin/bash differs or fails: $(diff "$WORK/out-path" "$WORK/out-sys" | head -3 | tr '\n' ' ')$(tail -2 "$WORK/out-path" | tr '\n' ' ')"; fi
fi

# R9 — the README and the reference name the scripts' rule families
for fam in DEC-S1 DEC-S8 DEC-C1 DEC-C3; do has R9 "$README" "${fam%[0-9]}"; done
for id in $(cat "$WORK/script-ids"); do if grep -q "| $id |" "$RULES"; then ok; else bad "R9 $id is not in references/decision-rules.md"; fi; done

# NEXT — the missing-plugin sentence (ADR-028): every hand-written skill whose
# Output has a "Recommended next:" line carries it, exactly once, with a
# link to the generated copy of the registry's signals table
NEXT='Also name any plugin in `references/plugin-signals.md` whose signal this repository shows and whose skills are not available in this session, with its reason.'
SIGNALS="$PLUGIN/references/plugin-signals.md"
if [ -f "$SIGNALS" ] && grep -q '^<!-- GENERATED by make plugins' "$SIGNALS" && grep -q '^| .* | `ascent-governance` | ' "$SIGNALS"; then ok; else bad "NEXT references/plugin-signals.md is missing, is not generated, or has no signals table"; fi
NNEXT=0
for f in "$PLUGIN"/skills/*/SKILL.md; do
  grep -q '^Recommended next: <' "$f" || continue
  grep -q '^<!-- GENERATED by make plugins' "$f" && continue
  NNEXT=$((NNEXT + 1))
  if [ "$(grep -cF -- "$NEXT" "$f")" -eq 1 ]; then ok; else bad "NEXT ${f#"$PLUGIN"/} does not carry the missing-plugin sentence exactly once"; fi
  if grep -F -- "$NEXT" "$f" | grep -qF '](../../references/plugin-signals.md)'; then ok; else bad "NEXT ${f#"$PLUGIN"/} does not link references/plugin-signals.md beside the sentence"; fi
done
[ "$NNEXT" -ge 1 ] && ok || bad "NEXT no hand-written skill of this plugin has a Recommended next: line"

echo "test-adr-rules: $PASS/$((PASS + FAIL)) PASS"
[ "$FAIL" -eq 0 ]
