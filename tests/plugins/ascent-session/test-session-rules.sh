#!/usr/bin/env bash
# Rule test for the ascent-session skills and references (ADR-027):
#   R1  every $PLUGIN_ROOT/<path> a skill names exists
#   R2  every rule id the script prints is in the severity table at the severity the
#       script's header gives it, and in references/session-rules.md at the same
#       severity; the table and the reference name no id the script does not print
#   R3  session-resume routes off-table concerns to "Other observations (unrated)"
#       and cites or says "not recorded"
#   R4  every session.<key> a skill names is a key of the contract template, and
#       every template key is used by a skill
#   R5  every "<skill> Step N" a skill cites names a skill and a "### Step N"
#       heading that exist
#   R6  session-capture and handoff write only after approval and only their own
#       files, never change a working-memory entry and never commit
#   R7  session-resume never proposes memory_since on its own
#   R8  the script runs under the system /bin/bash (3.2 on macOS) with the same
#       result as the bash on PATH
#   R9  the README and session-rules.md name the same rule ids as the script
#
# Prints "test-session-rules: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../../.."
PLUGIN="$ROOT/plugins/ascent-session"
RESUME="$PLUGIN/skills/session-resume/SKILL.md"
CAPTURE="$PLUGIN/skills/session-capture/SKILL.md"
HANDOFF="$PLUGIN/skills/handoff/SKILL.md"
TEMPLATE="$PLUGIN/references/contract-template.yml"
RULES="$PLUGIN/references/session-rules.md"
README="$PLUGIN/README.md"
SCRIPT="$PLUGIN/scripts/check-session.sh"
AWKF="$PLUGIN/scripts/lib/check-session.awk"
for f in "$RESUME" "$CAPTURE" "$HANDOFF" "$TEMPLATE" "$RULES" "$README" "$SCRIPT" "$AWKF"; do
  [ -f "$f" ] || { echo "FAIL  test-session-rules: missing $f"; echo "test-session-rules: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
has() { if grep -qF -- "$3" "$2"; then ok; else bad "$1 ${2#"$ROOT"/} does not contain: $3"; fi; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

# R1 — named plugin paths exist
for f in "$RESUME" "$CAPTURE" "$HANDOFF"; do
  for p in $(grep -o '\$PLUGIN_ROOT/[A-Za-z0-9_./-]*' "$f" | sed 's/^\$PLUGIN_ROOT\///' | LC_ALL=C sort -u); do
    if [ -e "$PLUGIN/$p" ]; then ok; else bad "R1 ${f#"$ROOT"/} names \$PLUGIN_ROOT/$p, which does not exist"; fi
  done
done

# R2 — script ids, the severity table and the reference agree
table() { awk '/<!-- ses-severity:start/{on=1; next} /<!-- ses-severity:end/{on=0} on' "$RESUME"; }
sed -n '/^# Checks/,/^# At prototype/p' "$SCRIPT" | grep -Eo 'SES-S[0-9]+  (Medium|Low|High)' > "$WORK/ids" || true
[ -s "$WORK/ids" ] || bad "R2 check-session.sh: no rule ids in its header"
while read -r id sev; do
  k=${id#SES-}
  grep -qE "fail\(\"$k\", \"$sev\"" "$AWKF" || bad "R2 $id: check-session.awk does not report it at $sev"
  if grep -E "fail\(\"$k\", \"" "$AWKF" | grep -vq "fail(\"$k\", \"$sev\""; then bad "R2 $id: check-session.awk also reports it at another severity"; else ok; fi
  row=$(table | grep "($id)" || true)
  case "$row" in *"| $sev |") ok ;; "") bad "R2 $id is not in the ses-severity table" ;; *) bad "R2 $id is $sev in check-session.sh but the table says: $row" ;; esac
  if grep -q "^| $id | $sev |" "$RULES"; then ok; else bad "R2 $id is not $sev in references/session-rules.md"; fi
done < "$WORK/ids"
sed -n '/^# Checks/,/^# At prototype/p' "$SCRIPT" | grep -Eo 'SES-S[0-9]+' | LC_ALL=C sort -u > "$WORK/script-ids"
table | grep -Eo 'SES-S[0-9]+' | LC_ALL=C sort -u > "$WORK/table-ids"
grep -Eo '^\| SES-S[0-9]+' "$RULES" | sed 's/^| //' | LC_ALL=C sort -u > "$WORK/rule-ids"
if cmp -s "$WORK/script-ids" "$WORK/table-ids"; then ok; else bad "R2 the severity table and the script name different ids: $(diff "$WORK/script-ids" "$WORK/table-ids" | grep '^[<>]' | tr '\n' ' ')"; fi
if cmp -s "$WORK/script-ids" "$WORK/rule-ids"; then ok; else bad "R2 session-rules.md and the script name different ids: $(diff "$WORK/script-ids" "$WORK/rule-ids" | grep '^[<>]' | tr '\n' ' ')"; fi

# R3 — unrated route, citations
has R3 "$RESUME" 'Other observations (unrated)'
has R3 "$RESUME" 'Cite or say "not recorded".'
has R3 "$HANDOFF" 'From the records, cited.'

# R4 — contract keys
awk '/^session:/{on=1; next} on && /^[^ #]/{on=0} on && /^  [a-z_]+:/{k=$1; sub(/:$/, "", k); print k}' "$TEMPLATE" | LC_ALL=C sort -u > "$WORK/keys"
[ -s "$WORK/keys" ] || bad "R4 no keys under session: in the contract template"
cat "$RESUME" "$CAPTURE" "$HANDOFF" | grep -oE '(^|[^a-z-])session\.[a-z_]+' | sed 's/^.*session\.//' | LC_ALL=C sort -u > "$WORK/used"
while read -r k; do if grep -qx "$k" "$WORK/keys"; then ok; else bad "R4 session.$k is named but is not a key of the contract template"; fi; done < "$WORK/used"
for k in $(cat "$WORK/keys"); do
  if cat "$RESUME" "$CAPTURE" "$HANDOFF" | grep -qE "(session\.|\`)$k\b|$k\`"; then ok; else bad "R4 contract key session.$k is used by no skill"; fi
done

# R5 — cited steps exist
for f in "$RESUME" "$CAPTURE" "$HANDOFF"; do
  grep -oE '(session-resume|session-capture|handoff) Steps? [0-9]+' "$f" | LC_ALL=C sort -u | while read -r sk _ n; do
    t="$PLUGIN/skills/$sk/SKILL.md"
    if [ -f "$t" ] && grep -q "^### Step $n " "$t"; then echo ok; else echo "bad R5 ${f#"$ROOT"/} cites $sk Step $n, which does not exist"; fi
  done
done > "$WORK/r5"
[ -s "$WORK/r5" ] || bad "R5 no skill cites another's step"
while read -r l; do case "$l" in ok) ok ;; *) bad "${l#bad }" ;; esac; done < "$WORK/r5"

# R6 — write boundaries
has R6 "$CAPTURE" 'Write only after approval, and only these files'
has R6 "$CAPTURE" 'Never change or remove a working-memory entry.'
has R6 "$CAPTURE" 'Never commit.'
has R6 "$CAPTURE" '### Step 5 — After confirmation only'
has R6 "$HANDOFF" 'Write only after approval, and only the handoff file.'
has R6 "$HANDOFF" 'Never commit.'
has R6 "$HANDOFF" 'After confirmation only'
has R6 "$RESUME" '**Read-only.**'

# R7 — memory_since is a person's call
has R7 "$RESUME" 'Never propose `memory_since` on your own'
has R7 "$TEMPLATE" 'only after a person has read an earlier rewrite'

# R8 — /bin/bash gives the same result as bash on PATH
if [ -x /bin/bash ]; then
  (cd "$HERE/fixtures/session-good" && bash "$SCRIPT" --no-git --today 2026-11-20 >"$WORK/out-path" 2>&1; echo "exit $?" >>"$WORK/out-path")
  (cd "$HERE/fixtures/session-good" && /bin/bash "$SCRIPT" --no-git --today 2026-11-20 >"$WORK/out-sys" 2>&1; echo "exit $?" >>"$WORK/out-sys")
  if grep -q '^exit 0$' "$WORK/out-path" && cmp -s "$WORK/out-path" "$WORK/out-sys"; then ok; else bad "R8 check-session.sh: /bin/bash differs or fails: $(diff "$WORK/out-path" "$WORK/out-sys" | head -3 | tr '\n' ' ')$(tail -2 "$WORK/out-path" | tr '\n' ' ')"; fi
fi

# R9 — the README and the reference name the rule ids
has R9 "$README" 'SES-S1–S6'
for id in $(cat "$WORK/script-ids"); do if grep -q "| $id |" "$RULES"; then ok; else bad "R9 $id is not in references/session-rules.md"; fi; done

echo "test-session-rules: $PASS/$((PASS + FAIL)) PASS"
[ "$FAIL" -eq 0 ]
