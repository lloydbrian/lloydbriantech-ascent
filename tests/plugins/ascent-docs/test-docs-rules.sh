#!/usr/bin/env bash
# Rule test for the ascent-docs skills, agent and references (ADR-027):
#   R1  every $PLUGIN_ROOT/<path> a skill names exists
#   R2  every rule id a script prints is in the severity table at the severity the
#       script's header gives it, and in references/docs-rules.md at the same
#       severity; the table and the reference name no id the scripts do not print
#   R3  docs-review, doc-drift and the agent route off-table concerns to "Other
#       observations (unrated)"; onboard cites or says "not documented"
#   R4  every docs.<key> a skill or the agent names is a key of the contract
#       template, and every template key is used by a skill
#   R5  every "<skill> Step N" a skill or the agent cites names a skill and a
#       "### Step N" heading that exist
#   R6  doc-drift and doc-stub write only after approval and only documents, never
#       overwrite and never commit; docs-review and onboard are read-only
#   R7  the agent reports DOC-L3 and DOC-L4 as not assessed, and doc-drift never
#       adds to docs.ignore on its own
#   R8  every script runs under the system /bin/bash (3.2 on macOS) with the same
#       result as the bash on PATH
#   R9  the README and docs-rules.md name the same rule ids as the scripts
#
# Prints "test-docs-rules: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../../.."
PLUGIN="$ROOT/plugins/ascent-docs"
REVIEW="$PLUGIN/skills/docs-review/SKILL.md"
DRIFT="$PLUGIN/skills/doc-drift/SKILL.md"
STUB="$PLUGIN/skills/doc-stub/SKILL.md"
ONBOARD="$PLUGIN/skills/onboard/SKILL.md"
AGENT="$PLUGIN/agents/docs-reviewer.md"
TEMPLATE="$PLUGIN/references/contract-template.yml"
RULES="$PLUGIN/references/docs-rules.md"
README="$PLUGIN/README.md"
SCRIPTS="$PLUGIN/scripts/check-docs.sh $PLUGIN/scripts/check-doc-drift.sh"
AWKS="$PLUGIN/scripts/lib/check-docs.awk $PLUGIN/scripts/lib/check-doc-drift.awk"
SKILLS="$REVIEW $DRIFT $STUB $ONBOARD"
for f in $SKILLS "$AGENT" "$TEMPLATE" "$RULES" "$README" $SCRIPTS $AWKS "$PLUGIN/scripts/doc-stub.sh"; do
  [ -f "$f" ] || { echo "FAIL  test-docs-rules: missing $f"; echo "test-docs-rules: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
has() { if grep -qF -- "$3" "$2"; then ok; else bad "$1 ${2#"$ROOT"/} does not contain: $3"; fi; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM

# R1 — named plugin paths exist
for f in $SKILLS; do
  for p in $(grep -o '\$PLUGIN_ROOT/[A-Za-z0-9_./-]*' "$f" | sed 's/^\$PLUGIN_ROOT\///' | LC_ALL=C sort -u); do
    if [ -e "$PLUGIN/$p" ]; then ok; else bad "R1 ${f#"$ROOT"/} names \$PLUGIN_ROOT/$p, which does not exist"; fi
  done
done

# R2 — script ids, the severity table and the reference agree
table() { awk '/<!-- doc-severity:start/{on=1; next} /<!-- doc-severity:end/{on=0} on' "$REVIEW"; }
for s in $SCRIPTS; do
  sed -n '/^# Checks/,/^# At prototype/p' "$s" | grep -Eo 'DOC-[LPR][0-9]+  (Medium|Low|High)' > "$WORK/ids" || true
  [ -s "$WORK/ids" ] || bad "R2 ${s#"$ROOT"/}: no rule ids in its header"
  while read -r id sev; do
    k=${id#DOC-}
    if cat $AWKS | grep -qE "fail\(\"$k\", \"$sev\""; then ok; else bad "R2 $id: no fail() reports it at $sev"; fi
    if cat $AWKS | grep -E "fail\(\"$k\", \"" | grep -vq "fail(\"$k\", \"$sev\""; then bad "R2 $id: also reported at another severity"; else ok; fi
    row=$(table | grep "($id)" || true)
    case "$row" in *"| $sev |") ok ;; "") bad "R2 $id is not in the doc-severity table" ;; *) bad "R2 $id is $sev in ${s#"$ROOT"/} but the table says: $row" ;; esac
    if grep -q "^| $id | $sev |" "$RULES"; then ok; else bad "R2 $id is not $sev in references/docs-rules.md"; fi
  done < "$WORK/ids"
done
cat $SCRIPTS | sed -n '/^# Checks/,/^# At prototype/p' | grep -Eo 'DOC-[LPR][0-9]+' | LC_ALL=C sort -u > "$WORK/script-ids"
table | grep -Eo 'DOC-[LPR][0-9]+' | LC_ALL=C sort -u > "$WORK/table-ids"
grep -Eo '^\| DOC-[LPR][0-9]+' "$RULES" | sed 's/^| //' | LC_ALL=C sort -u > "$WORK/rule-ids"
if cmp -s "$WORK/script-ids" "$WORK/table-ids"; then ok; else bad "R2 the severity table and the scripts name different ids: $(diff "$WORK/script-ids" "$WORK/table-ids" | grep '^[<>]' | tr '\n' ' ')"; fi
if cmp -s "$WORK/script-ids" "$WORK/rule-ids"; then ok; else bad "R2 docs-rules.md and the scripts name different ids: $(diff "$WORK/script-ids" "$WORK/rule-ids" | grep '^[<>]' | tr '\n' ' ')"; fi

# R3 — unrated route, citations
for f in "$REVIEW" "$AGENT"; do has R3 "$f" 'Other observations (unrated)'; done
has R3 "$REVIEW" 'Never judge a description right or wrong as a finding.'
has R3 "$AGENT" 'including a description you think is wrong'
has R3 "$ONBOARD" 'From the documents, cited.'
has R3 "$ONBOARD" 'not documented'

# R4 — contract keys
awk '/^docs:/{on=1; next} on && /^[^ #]/{on=0} on && /^  [a-z_]+:/{k=$1; sub(/:$/, "", k); print k}' "$TEMPLATE" | LC_ALL=C sort -u > "$WORK/keys"
[ -s "$WORK/keys" ] || bad "R4 no keys under docs: in the contract template"
cat $SKILLS "$AGENT" | grep -oE '(^|[^a-z-])docs\.[a-z_]+' | sed 's/^.*docs\.//' | grep -vx 'md' | LC_ALL=C sort -u > "$WORK/used"
while read -r k; do if grep -qx "$k" "$WORK/keys"; then ok; else bad "R4 docs.$k is named but is not a key of the contract template"; fi; done < "$WORK/used"
for k in $(cat "$WORK/keys"); do
  if cat $SKILLS | grep -qE "(docs\.|\`)$k\b|$k\`"; then ok; else bad "R4 contract key docs.$k is used by no skill"; fi
done

# R9 — no regex intervals ({n}, {n,m}) in the awk programs: some awks lack them
for f in "$ROOT"/plugins/ascent-docs/scripts/lib/*.awk "$ROOT"/plugins/ascent-adr/scripts/lib/*.awk "$ROOT"/plugins/ascent-session/scripts/lib/*.awk; do
  [ -f "$f" ] || continue
  if grep -nE '(^|[^\\])\{[0-9]+(,[0-9]*)?\}' "$f" | grep -v '^[0-9]*: *#' >/dev/null; then bad "R9 ${f#"$ROOT"/} uses a regex interval: $(grep -nE '(^|[^\\])\{[0-9]+(,[0-9]*)?\}' "$f" | head -1 | cut -c1-80)"; else ok; fi
done

# R5 — cited steps exist
for f in $SKILLS "$AGENT"; do
  grep -oE '(docs-review|doc-drift|doc-stub|onboard) Steps? [0-9]+' "$f" | LC_ALL=C sort -u | while read -r sk _ n; do
    t="$PLUGIN/skills/$sk/SKILL.md"
    if [ -f "$t" ] && grep -q "^### Step $n " "$t"; then echo ok; else echo "bad R5 ${f#"$ROOT"/} cites $sk Step $n, which does not exist"; fi
  done
done > "$WORK/r5"
[ -s "$WORK/r5" ] || bad "R5 no skill cites another's step"
while read -r l; do case "$l" in ok) ok ;; *) bad "${l#bad }" ;; esac; done < "$WORK/r5"

# R6 — write boundaries
has R6 "$DRIFT" 'Write only after approval, and only documents'
has R6 "$DRIFT" 'Never commit.'
has R6 "$DRIFT" '### Step 4 — After confirmation only'
has R6 "$STUB" 'Write only after approval, and only two files'
has R6 "$STUB" 'Never overwrite a document'
has R6 "$STUB" 'Never commit.'
has R6 "$STUB" '--dry-run'
has R6 "$REVIEW" '**Read-only.**'
has R6 "$ONBOARD" '**Read-only.**'
has R6 "$PLUGIN/scripts/doc-stub.sh" 'set -C'

# R7 — what reading cannot do, and the ignore list
has R7 "$AGENT" 'Not assessed: DOC-L3, DOC-L4'
has R7 "$DRIFT" 'Never add to `docs.ignore` on your own.'
has R7 "$TEMPLATE" 'Add one only after a person has confirmed it is not drift.'

# R8 — /bin/bash gives the same result as bash on PATH
if [ -x /bin/bash ]; then
  for s in $SCRIPTS; do
    (cd "$HERE/fixtures/docs-good" && bash "$s" --no-git >"$WORK/out-path" 2>&1; echo "exit $?" >>"$WORK/out-path")
    (cd "$HERE/fixtures/docs-good" && /bin/bash "$s" --no-git >"$WORK/out-sys" 2>&1; echo "exit $?" >>"$WORK/out-sys")
    if grep -q '^exit 0$' "$WORK/out-path" && cmp -s "$WORK/out-path" "$WORK/out-sys"; then ok; else bad "R8 ${s#"$ROOT"/}: /bin/bash differs or fails: $(diff "$WORK/out-path" "$WORK/out-sys" | head -3 | tr '\n' ' ')$(tail -2 "$WORK/out-path" | tr '\n' ' ')"; fi
  done
fi

# R9 — the README and the reference name the rule ids
for fam in DOC-L1 DOC-P1 DOC-R1; do has R9 "$README" "$fam"; done
for id in $(cat "$WORK/script-ids"); do if grep -q "| $id |" "$RULES"; then ok; else bad "R9 $id is not in references/docs-rules.md"; fi; done

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

echo "test-docs-rules: $PASS/$((PASS + FAIL)) PASS"
[ "$FAIL" -eq 0 ]
