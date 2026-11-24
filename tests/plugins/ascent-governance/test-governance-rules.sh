#!/usr/bin/env bash
# Rule test for the ascent-governance skills, agent and references (ADR-028):
#   R1  every $PLUGIN_ROOT/<path> a skill names exists
#   R2  every rule id check-audit.sh's header lists is in the gov-severity table and
#       in references/governance-rules.md at the same severity; every rule and
#       severity the code can report has a row in the table; the table and the
#       reference name no id the script does not list
#   R3  the gov-severity table is the same in launch-readiness and the agent
#   R4  every option a skill or the agent names for check-audit.sh is one its usage
#       line lists
#   R5  the agent's tools are exactly Read, Grep, Glob, and it never runs or signs
#   R6  nothing tells Claude to sign: every line that names "Signed:" says who does
#   R7  only launch-readiness and review-record write the review log; governance-
#       review and the agent write nothing; nothing commits
#   R8  the README's CI example pins a release tag and fetches the full history,
#       and fails the job only on a check that fails with a High finding or stops
#       without finishing (ADR-029)
#   R9  every governance.<key> a skill names is a key of the contract template, and
#       every template key is used
#   R10 every "<skill> Step N" a skill cites names a skill and a "### Step N"
#       heading that exist
#   R11 every review the default floors name is in the reference's review table,
#       and the skill it names exists in its plugin
#   R12 the script runs under the system /bin/bash (3.2 on macOS) with the same
#       result as the bash on PATH
#   R13 every skill's Output ends with a "Recommended next:" line, and the README
#       and the reference name the rule ids
#
# Prints "test-governance-rules: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../../.."
PLUGINS="$HERE/../../../plugins"
PLUGIN="$PLUGINS/ascent-governance"
LAUNCH="$PLUGIN/skills/launch-readiness/SKILL.md"
REVIEW="$PLUGIN/skills/governance-review/SKILL.md"
RECORD="$PLUGIN/skills/review-record/SKILL.md"
AGENT="$PLUGIN/agents/governance-conductor.md"
TEMPLATE="$PLUGIN/references/contract-template.yml"
RULES="$PLUGIN/references/governance-rules.md"
README="$PLUGIN/README.md"
SCRIPT="$PLUGIN/scripts/check-audit.sh"
AWKF="$PLUGIN/scripts/lib/audit.awk"
for f in "$LAUNCH" "$REVIEW" "$RECORD" "$AGENT" "$TEMPLATE" "$RULES" "$README" "$SCRIPT" "$AWKF"; do
  [ -f "$f" ] || { echo "FAIL  test-governance-rules: missing $f"; echo "test-governance-rules: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
rel() { printf '%s' "${1#"$PLUGINS"/}"; }
has() { if grep -qF -- "$3" "$2"; then ok; else bad "$1 $(rel "$2") does not contain: $3"; fi; }
lacks() { if grep -qiF -- "$3" "$2"; then bad "$1 $(rel "$2") must not contain: $3"; else ok; fi; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
SKILLS="$LAUNCH $REVIEW $RECORD"

# R1 — named plugin paths exist
for f in $SKILLS; do
  for p in $(grep -o '\$PLUGIN_ROOT/[A-Za-z0-9_./-]*' "$f" | sed 's/^\$PLUGIN_ROOT\///' | LC_ALL=C sort -u); do
    if [ -e "$PLUGIN/$p" ]; then ok; else bad "R1 $(rel "$f") names \$PLUGIN_ROOT/$p, which does not exist"; fi
  done
done

# R2 — the script's ids, the severity table and the reference agree
table() { awk '/<!-- gov-severity:start/{on=1; next} /<!-- gov-severity:end/{on=0} on' "$1"; }
awk 'NR > 1 && !/^#/ { exit } { print }' "$SCRIPT" | grep -Eo 'GOV-[SLWR][0-9]+  (High|Medium|Low)' > "$WORK/ids" || true
[ "$(wc -l < "$WORK/ids" | tr -d ' ')" -ge 15 ] || bad "R2 check-audit.sh: fewer than 15 rule ids in its header"
while read -r id sev; do
  if table "$LAUNCH" | grep -E "\\($id[ )]" | grep -q "| $sev |\$"; then ok; else bad "R2 $id is not $sev in the gov-severity table"; fi
  if grep -q "^| $id | $sev |" "$RULES"; then ok; else bad "R2 $id is not $sev in references/governance-rules.md"; fi
done < "$WORK/ids"
# what the code can report: item ... GOV-Xn fail|due|unmeasured SEV, fail(n, "SEV" (GOV-W), rfail(n, ..., "SEV" (GOV-R)
{ grep -Eo 'item [a-z]+ GOV-[SLWR][0-9]+ (fail|due|unmeasured) (High|Medium|Low)' "$SCRIPT" | awk '{ print $3, $5 }'
  grep -Eo '[^r]fail\([0-9], "(High|Medium|Low)"' "$AWKF" | sed -E 's/.*fail\(([0-9]), "([A-Za-z]+)"/GOV-W\1 \2/'
  grep -Eo 'rfail\([0-9], "fail", "(High|Medium|Low)"' "$AWKF" | sed -E 's/rfail\(([0-9]), "fail", "([A-Za-z]+)"/GOV-R\1 \2/'
  grep -q 'sev = launch ? "High" : "Medium"' "$AWKF" && printf 'GOV-R1 High\nGOV-R1 Medium\n'
  # GOV-L1 takes the most severe finding of the check that failed (ADR-029)
  grep -q 'item check GOV-L1 fail "\$(sev_of ' "$SCRIPT" && printf 'GOV-L1 High\nGOV-L1 Medium\nGOV-L1 Low\n'
} | LC_ALL=C sort -u > "$WORK/code"
[ "$(wc -l < "$WORK/code" | tr -d ' ')" -ge 17 ] || bad "R2 fewer than 17 rule and severity pairs found in the code: $(tr '\n' ';' < "$WORK/code")"
while read -r id sev; do
  if table "$LAUNCH" | grep -E "\\($id[ )]" | grep -q "| $sev |\$"; then ok; else bad "R2 the code reports $id at $sev, which the gov-severity table does not list"; fi
done < "$WORK/code"
cut -d' ' -f1 "$WORK/ids" | LC_ALL=C sort -u > "$WORK/script-ids"
table "$LAUNCH" | grep -Eo 'GOV-[SLWR][0-9]+' | LC_ALL=C sort -u > "$WORK/table-ids"
grep -Eo '^\| GOV-[SLWR][0-9]+' "$RULES" | sed 's/^| //' | LC_ALL=C sort -u > "$WORK/rule-ids"
cut -d' ' -f1 "$WORK/code" | LC_ALL=C sort -u > "$WORK/code-ids"
if cmp -s "$WORK/script-ids" "$WORK/table-ids"; then ok; else bad "R2 the severity table and the script name different ids: $(diff "$WORK/script-ids" "$WORK/table-ids" | grep '^[<>]' | tr '\n' ' ')"; fi
if cmp -s "$WORK/script-ids" "$WORK/rule-ids"; then ok; else bad "R2 governance-rules.md and the script name different ids: $(diff "$WORK/script-ids" "$WORK/rule-ids" | grep '^[<>]' | tr '\n' ' ')"; fi
if cmp -s "$WORK/script-ids" "$WORK/code-ids"; then ok; else bad "R2 the script's header and its code name different ids: $(diff "$WORK/script-ids" "$WORK/code-ids" | grep '^[<>]' | tr '\n' ' ')"; fi
has R2 "$LAUNCH" '**Verdict:** NO-GO: any High. GO WITH CONDITIONS: no High, and any Medium, Low or unmeasured item. GO: none of them.'
has R2 "$LAUNCH" 'Rate only with the severity table below.'
has R2 "$LAUNCH" 'Other observations (unrated)'
has R2 "$RULES" 'A refusal is an exit 2 whose first line is the checker'"'"'s own message (ADR-030)'
has R2 "$RULES" 'An exit 2 without the checker'"'"'s own message is a checker that stopped without finishing (ADR-030).'

# R3 — one table
table "$LAUNCH" > "$WORK/t1"; table "$AGENT" > "$WORK/t2"
if [ -s "$WORK/t1" ] && cmp -s "$WORK/t1" "$WORK/t2"; then ok; else bad "R3 the gov-severity table differs between launch-readiness and governance-conductor"; fi

# R4 — options exist
bash "$SCRIPT" --help 2>/dev/null | head -1 | grep -Eo -- '--[a-z][a-z-]*' | LC_ALL=C sort -u > "$WORK/opts"
[ "$(wc -l < "$WORK/opts" | tr -d ' ')" -ge 9 ] || bad "R4 check-audit.sh --help lists fewer than 9 options"
for f in $SKILLS "$AGENT" "$README" "$RULES"; do
  { grep -F 'check-audit.sh' "$f" | grep -Eo -- '--[a-z][a-z-]*'; grep -Eo -- '`--[a-z][a-z-]*' "$f" | tr -d '`'; } | grep -vx -- '--branch\|--quiet\|--depth' | LC_ALL=C sort -u > "$WORK/used" || true
  while read -r o; do
    [ -n "$o" ] || continue
    if grep -qx -- "$o" "$WORK/opts"; then ok; else bad "R4 $(rel "$f") names $o, which check-audit.sh does not take"; fi
  done < "$WORK/used"
done
has R4 "$LAUNCH" 'check-audit.sh" --env '"'"'<environment>'"'"' --launch .'
has R4 "$LAUNCH" "--record '<governance.launch_dir>/<today>-<environment>.md' ."
has R4 "$REVIEW" 'check-audit.sh" --env '"'"'<environment>'"'"' .'
if grep -F 'check-audit.sh"' "$REVIEW" | grep -q -- '--launch\|--record'; then bad "R4 governance-review asks the launch question or writes a record"; else ok; fi

# R5 — the agent reads only
if [ "$(grep -c '^tools: Read, Grep, Glob$' "$AGENT")" -eq 1 ] && [ "$(grep -c '^tools:' "$AGENT")" -eq 1 ]; then ok; else bad "R5 governance-conductor's tools are not exactly Read, Grep, Glob"; fi
has R5 "$AGENT" 'You have no shell'
has R5 "$AGENT" 'Read-only: never edit, never propose to run a command yourself.'
has R5 "$AGENT" 'Never say GO'
has R5 "$AGENT" 'Not assessed: GOV-L1, GOV-L2 and GOV-S2 (need the checkers), GOV-L5 and GOV-R4 (need git history)'
for f in $SKILLS; do
  if grep -q '^allowed-tools: Read, Grep, Glob, Bash(git ls-files:\*), Bash(git log:\*)$' "$f"; then ok; else bad "R5 $(rel "$f"): allowed-tools is not the read-only set"; fi
done

# R6 — a person signs
has R6 "$LAUNCH" '**Claude never signs.**'
has R6 "$LAUNCH" 'Never write anything after `Signed:` or `Date:` in a launch record, never propose a name for them'
has R6 "$LAUNCH" 'I never sign.'
has R6 "$AGENT" 'Never sign, and never suggest a name or a date for `Signed:` or `Date:`.'
has R6 "$README" 'No skill, agent or script here writes after `Signed:` or `Date:`.'
for f in $SKILLS "$AGENT" "$README" "$RULES"; do
  n=$(grep -F 'Signed:' "$f" | grep -Evc 'ever |person|your name|^\*\*Signed:\*\*$|ana-lopez' || true)
  if [ "$n" -eq 0 ]; then ok; else bad "R6 $(rel "$f") names Signed: on a line that does not say a person signs: $(grep -F 'Signed:' "$f" | grep -Ev 'ever |person|your name|^\*\*Signed:\*\*$|ana-lopez' | head -1 | cut -c1-120)"; fi
done
if grep -q 'printf "\*\*Signed:\*\*\\n\\n\*\*Date:\*\*\\n"' "$PLUGIN/scripts/lib/render.awk"; then ok; else bad "R6 render.awk does not leave Signed: and Date: empty"; fi

# R7 — who writes
has R7 "$LAUNCH" '**Write only these, and only after approval:**'
has R7 "$LAUNCH" 'Never edit the verdict, the evidence table, the waivers or the conditions of a record'
has R7 "$LAUNCH" 'never commit a record'
has R7 "$LAUNCH" 'never remove it yourself'
has R7 "$RECORD" '**Write only after approval, and only the review log.**'
has R7 "$RECORD" '**Never change or remove a row.**'
has R7 "$RECORD" '**Refuse without a rating and a commit.**'
has R7 "$RECORD" 'Never commit.'
has R7 "$RECORD" '### Step 3 — After confirmation only'
has R7 "$RECORD" 'never leave out an open High finding'
has R7 "$RECORD" 'one id for each finding'
has R7 "$RECORD" 'Keep the log to that one table: every table row below its header is read as a review row.'
has R7 "$LAUNCH" "When Step 3's answer is NO-GO, do not write the record unless the operator asks for the refusal on record"
has R7 "$REVIEW" '**Read-only.** Never write the review log, a launch record or the contract here, and never run a review'
has R7 "$REVIEW" 'The proposal is text for the operator; never write it.'
lacks R7 "$REVIEW" 'append'
lacks R7 "$AGENT" 'append'
has R7 "$RULES" 'Only `launch-readiness` and `review-record` write it'

# R8 — the CI example
if grep -Eq -- '--branch v[0-9]+\.[0-9]+\.[0-9]+ https://github.com/lloydbrian/lloydbriantech-ascent' "$README"; then ok; else bad "R8 the README's CI example does not pin a release tag"; fi
has R8 "$README" 'fetch-depth: 0'
has R8 "$README" 'Pin a release tag; never a branch.'
has R8 "$README" 'a check that fails with a High finding or stops without finishing'
if grep -Eq -- '--branch (main|master)|@main' "$README"; then bad "R8 the README's CI example follows a branch"; else ok; fi

# R9 — contract keys
awk '/^governance:/{on=1; next} on && /^[^ #]/{on=0} on && /^  [a-z_]+:/{k=$1; sub(/:$/, "", k); print k}' "$TEMPLATE" | LC_ALL=C sort -u > "$WORK/keys"
[ "$(wc -l < "$WORK/keys" | tr -d ' ')" -ge 7 ] || bad "R9 fewer than 7 keys under governance: in the contract template"
cat $SKILLS "$AGENT" "$RULES" | grep -oE '(^|[^a-z-])governance\.[a-z_]+' | sed 's/^.*governance\.//' | LC_ALL=C sort -u > "$WORK/used"
while read -r k; do if grep -qx "$k" "$WORK/keys"; then ok; else bad "R9 governance.$k is named but is not a key of the contract template"; fi; done < "$WORK/used"
for k in $(cat "$WORK/keys"); do
  if cat $SKILLS "$AGENT" "$RULES" | grep -qE "(governance\.|\`)$k\b|$k\`"; then ok; else bad "R9 contract key governance.$k is used by no skill, agent or reference"; fi
done

# R10 — cited steps exist
for f in $SKILLS; do
  grep -oE '(launch-readiness|governance-review|review-record) Steps? [0-9]+( to Step [0-9]+)?' "$f" | LC_ALL=C sort -u | while read -r sk _ n _ _ m; do
    t="$PLUGIN/skills/$sk/SKILL.md"
    for s in $n $m; do
      if [ -f "$t" ] && grep -q "^### Step $s " "$t"; then echo ok; else echo "bad R10 $(rel "$f") cites $sk Step $s, which does not exist"; fi
    done
  done
done > "$WORK/r10"
[ -s "$WORK/r10" ] || bad "R10 no skill cites another's step"
while read -r l; do case "$l" in ok) ok ;; *) bad "${l#bad }" ;; esac; done < "$WORK/r10"

# R11 — the reviews the default floors name
grep -Eo "review\\\\t[a-z-]+\\\\t[0-9]+|for it in [a-z -]*review[a-z -]*; do shows \"\\\$it\" && printf 'review" "$SCRIPT" | sed 's/\\t/ /g' | grep -Eo '[a-z]+-(review|posture)' | LC_ALL=C sort -u > "$WORK/reviews"
[ "$(wc -l < "$WORK/reviews" | tr -d ' ')" -ge 5 ] || bad "R11 fewer than 5 default reviews found in check-audit.sh: $(tr '\n' ' ' < "$WORK/reviews")"
while read -r r; do
  row=$(grep -E "^  \| \`$r\` \| \`ascent-[a-z]+:[a-z-]+\` \|" "$RULES" || true)
  if [ -z "$row" ]; then bad "R11 the default review $r is not in the reference's review table"; continue; fi
  sk=$(printf '%s\n' "$row" | grep -Eo 'ascent-[a-z]+:[a-z-]+')
  if [ -f "$PLUGINS/${sk%%:*}/skills/${sk#*:}/SKILL.md" ]; then ok; else bad "R11 $r names $sk, which is not a skill of that plugin"; fi
  if grep -Eq 'strong.*moderate.*weak' "$PLUGINS/${sk%%:*}/skills/${sk#*:}/SKILL.md"; then ok; else bad "R11 $sk gives no strong, moderate or weak rating to record"; fi
done < "$WORK/reviews"

# R12 — /bin/bash gives the same result as bash on PATH
if [ -x /bin/bash ]; then
  mkdir -p "$WORK/none"
  (cd "$HERE/fixtures/audit-good" && GITHUB_STEP_SUMMARY= bash "$SCRIPT" --env prod --no-git --today 2026-12-02 --plugins "$WORK/none" . >"$WORK/out-path" 2>&1; echo "exit $?" >>"$WORK/out-path")
  (cd "$HERE/fixtures/audit-good" && GITHUB_STEP_SUMMARY= /bin/bash "$SCRIPT" --env prod --no-git --today 2026-12-02 --plugins "$WORK/none" . >"$WORK/out-sys" 2>&1; echo "exit $?" >>"$WORK/out-sys")
  if grep -q '^exit 0$' "$WORK/out-path" && grep -q 'prod: GO WITH CONDITIONS' "$WORK/out-path" && cmp -s "$WORK/out-path" "$WORK/out-sys"; then ok; else bad "R12 check-audit.sh: /bin/bash differs or fails: $(diff "$WORK/out-path" "$WORK/out-sys" | head -3 | tr '\n' ' ')$(tail -2 "$WORK/out-path" | tr '\n' ' ')"; fi
fi

# R13 — the ends of the outputs, and the ids in the README
for f in $SKILLS; do
  if awk '/^## Output/{on=1} on && /^Recommended next: </{f=1} END{exit !f}' "$f"; then ok; else bad "R13 $(rel "$f"): its Output has no Recommended next: line"; fi
done
for r in 'GOV-S1–S2' 'GOV-L1–L5' 'GOV-W1–W4' 'GOV-R1–R4'; do
  if grep '^| `check-audit.sh` | script |' "$README" | grep -qF -- "$r"; then ok; else bad "R13 the README's row for check-audit.sh does not name $r"; fi
done
has R13 "$README" 'It checks that the evidence exists and is current, not that the system is good.'
has R13 "$RULES" 'It checks that the evidence exists and is current.'
has R13 "$LAUNCH" 'It checks that the evidence exists and is current, not that the system is good.'
for f in $SKILLS "$AGENT"; do
  d=$(awk '/^description:/{on=1; next} on && /^[a-z-]+:/{on=0} on' "$f" | tr '\n' ' ' | sed 's/^ *//')
  case "$d" in "Use when "*) ok ;; *) bad "R13 $(rel "$f"): the description does not start with 'Use when'" ;; esac
done

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

echo "test-governance-rules: $PASS/$((PASS + FAIL)) PASS"
[ "$FAIL" -eq 0 ]
