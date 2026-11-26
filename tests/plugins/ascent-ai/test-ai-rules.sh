#!/usr/bin/env bash
# Rule test for the ascent-ai skills, agent and references (ADR-031):
#   R1  ai-design recommends the lowest rung that fits: it names the three rungs,
#       says why each lower one does or does not fit, and keeps an agent for steps
#       that cannot be known in advance
#   R2  ai-design writes the design record, the contract section and the ADR
#       only after the operator approves
#   R3  ai-design reads the code first when AI code exists, and flags more
#       autonomy than the job needs; it reads hand-built loops and notebooks, the
#       record describes what was built, and it asks for the baseline the code
#       cannot give; ai-design-check says what AI-A1's script does not see; a tool
#       that only reads is reversible (trial on cd14524, v0.4.27)
#   R4  every rule id of references/ai-rules.md is listed by exactly one check
#       script and named by exactly one check skill, the one the table names
#   R5  every check skill cites its script by path, and every option it passes
#       is one the script's usage line lists
#   R6  the agent's tools are exactly Read, Grep, Glob, and it names the lenses
#       it leaves to others: Code review, Security and privacy, Architecture and
#       cost, Tests
#   R7  ai-review groups its findings by the lifecycle stages and adds no rule
#   R8  no skill or agent runs a model, an eval, a red team or a network call:
#       no promptfoo, garak, curl, wget or http command in a code block
#   R9  the ai-severity table is the same in ai-review and the agent, and agrees
#       with references/ai-rules.md
#   R10 every $PLUGIN_ROOT/<path> and every relative link a skill or the agent
#       names exists
#   R11 the four lens tables name the AI behavior lens with ascent-ai:ai-reviewer
#
# Prints "test-ai-rules: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../../.."
PLUGINS="$ROOT"/plugins   # quoted so: the scope reads only the paths named below (make/gate-scope.sh)
PLUGIN="$ROOT/plugins/ascent-ai"
DESIGN="$PLUGIN/skills/ai-design/SKILL.md"
REVIEW="$PLUGIN/skills/ai-review/SKILL.md"
DCHECK="$PLUGIN/skills/ai-design-check/SKILL.md"
ECHECK="$PLUGIN/skills/ai-evidence-check/SKILL.md"
RCHECK="$PLUGIN/skills/ai-runtime-check/SKILL.md"
AGENT="$PLUGIN/agents/ai-reviewer.md"
RULES="$PLUGIN/references/ai-rules.md"
GUIDE="$PLUGIN/references/ai-design-guide.md"
for f in "$DESIGN" "$REVIEW" "$DCHECK" "$ECHECK" "$RCHECK" "$AGENT" "$RULES" "$GUIDE"; do
  [ -f "$f" ] || { echo "FAIL  test-ai-rules: missing $f"; echo "test-ai-rules: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
rel() { printf '%s' "${1#"$PLUGINS"/}"; }
has() { if grep -qF -- "$3" "$2"; then ok; else bad "$1 $(rel "$2") does not contain: $3"; fi; }
lacks() { if grep -qiF -- "$3" "$2"; then bad "$1 $(rel "$2") must not contain: $3"; else ok; fi; }
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT INT TERM
CHECKS="$DCHECK $ECHECK $RCHECK"
ALL="$DESIGN $REVIEW $CHECKS $AGENT"

# R1 the lowest rung that fits
for s in 'a single prompt' 'a fixed workflow' 'an agent' 'an agent only when the steps cannot be known in advance' 'why each lower rung does or does not fit'; do has R1 "$DESIGN" "$s"; done
has R1 "$GUIDE" 'an agent only when the steps cannot be known in advance'
# R2 written only after approval
has R2 "$DESIGN" 'Write them only after the operator approves'
for s in 'design record' '`ai:` section' 'ADR'; do has R2 "$DESIGN" "$s"; done
# R3 existing code first
has R3 "$DESIGN" 'read the code first'
has R3 "$DESIGN" 'more autonomy than the job needs'
has R3 "$DESIGN" 'a step graph or state machine where a step that runs tools routes back to the model call is an agent loop'
has R3 "$DESIGN" 'Notebooks (`.ipynb`) count; the scripts do not read them, so read their code cells.'
has R3 "$DESIGN" 'the design record describes the application **as built**'
has R3 "$DESIGN" 'Never fill the baseline from the code.'
has R3 "$DCHECK" 'It does not see a loop built by hand as a step graph or state machine'
has R3 "$GUIDE" 'A tool that only reads, inside or outside (a search, a fetch, a database query), changes nothing and is reversible'

# R4 each rule id: one script, one skill, as the table says
awk -F '|' '/<!-- ai-rules:start -->/ { on = 1; next } /<!-- ai-rules:end -->/ { on = 0 } on && $2 ~ /AI-[A-Z][0-9]/ { id = $2; gsub(/[ \t]/, "", id); s = $5; gsub(/[ \t`]/, "", s); print id "\t" s }' "$RULES" > "$WORK/rules"
n=$(wc -l < "$WORK/rules" | tr -d ' ')
if [ "$n" -ge 28 ]; then ok; else bad "R4 references/ai-rules.md lists $n rules, fewer than 28"; fi
while IFS="$(printf '\t')" read -r id script; do
  in=""; for sc in "$PLUGIN"/scripts/check-ai-*.sh; do grep -Eq "^#   $id " "$sc" && in="$in $(basename "$sc")"; done
  if [ "$in" = " $script" ]; then ok; else bad "R4 $id: the table names $script, the script headers list it in:${in:- none}"; fi
  nsk=0; for sk in $CHECKS; do grep -qF -- "$id" "$sk" && nsk=$((nsk + 1)) && owner="$sk"; done
  if [ "$nsk" -eq 1 ] && grep -qF -- "scripts/$script" "$owner"; then ok; else bad "R4 $id is named by $nsk check skill(s), or not by the one that runs $script"; fi
done < "$WORK/rules"
# R5 each check skill cites its script, and passes only options the usage line lists
for pair in "$DCHECK:check-ai-design.sh" "$ECHECK:check-ai-evidence.sh" "$RCHECK:check-ai-runtime.sh"; do
  sk="${pair%%:*}"; sc="${pair#*:}"
  has R5 "$sk" "\$PLUGIN_ROOT/scripts/$sc"
  usage=$(grep -m1 '^# Usage:' "$PLUGIN/scripts/$sc")
  grep -o "scripts/$sc[^\`]*" "$sk" | grep -oE -- '--[a-z][a-z-]*' | sort -u > "$WORK/opts"
  [ -s "$WORK/opts" ] && ok || bad "R5 $(rel "$sk") passes no option to $sc"
  while read -r o; do case "$usage" in *"$o "*|*"$o]"*) ok ;; *) bad "R5 $(rel "$sk") passes $o, which $sc's usage line does not list" ;; esac; done < "$WORK/opts"
done
for sk in "$REVIEW"; do
  for sc in check-ai-design.sh check-ai-evidence.sh check-ai-runtime.sh; do has R5 "$sk" "\$PLUGIN_ROOT/scripts/$sc"; done
done

# R6 the agent reads only, and leaves four lenses to others
tools=$(sed -n 's/^tools:[[:space:]]*//p' "$AGENT" | head -1)
if [ "$tools" = "Read, Grep, Glob" ]; then ok; else bad "R6 the agent's tools are '$tools', not 'Read, Grep, Glob'"; fi
for s in 'Code review' 'Security and privacy' 'Architecture and cost' 'Tests'; do has R6 "$AGENT" "$s"; done
lacks R6 "$AGENT" 'Bash'
# R7 ai-review groups by stage and adds no rule
for s in 'design' 'build' 'evaluate' 'operate' 'improve'; do has R7 "$REVIEW" "| $s |"; done
has R7 "$REVIEW" 'It adds no rule'
ids_in_review=$(grep -oE 'AI-[A-Z][0-9]+' "$REVIEW" | sort -u)
for id in $ids_in_review; do if grep -q "^$id	" "$WORK/rules"; then ok; else bad "R7 ai-review names $id, which references/ai-rules.md does not list"; fi; done

# R8 nothing runs a model, an eval or a network call
for f in $ALL; do
  awk '/^```/ { inb = !inb; next } inb { print FILENAME ":" FNR ": " $0 }' "$f" > "$WORK/blocks"
  if grep -Eiq '(^|[ ;|&(])(promptfoo|garak|curl|wget|http|https|python3? -m (garak|promptfoo)|npx promptfoo)( |$)' "$WORK/blocks"; then
    bad "R8 $(rel "$f") runs a model, an eval or a network call: $(grep -Ei '(^|[ ;|&(])(promptfoo|garak|curl|wget|http|https)( |$)' "$WORK/blocks" | head -1)"
  else ok; fi
done

# R9 the severity table, the same in ai-review and the agent, and as the rule table says
sev() { awk '/<!-- ai-severity:start -->/ { on = 1; next } /<!-- ai-severity:end -->/ { on = 0 } on' "$1"; }
sev "$REVIEW" > "$WORK/s1"; sev "$AGENT" > "$WORK/s2"
[ -s "$WORK/s1" ] && ok || bad "R9 ai-review has no ai-severity table"
if cmp -s "$WORK/s1" "$WORK/s2"; then ok; else bad "R9 the ai-severity tables of ai-review and the agent differ"; fi
awk -F '|' '/<!-- ai-rules:start -->/ { on = 1; next } /<!-- ai-rules:end -->/ { on = 0 } on && $2 ~ /AI-[A-Z][0-9]/ { id = $2; gsub(/[ \t]/, "", id); b = $4; gsub(/^[ \t]+|[ \t]+$/, "", b); print id "\t" b }' "$RULES" > "$WORK/base"
awk -F '|' '$2 ~ /AI-[A-Z][0-9]/ { id = $2; gsub(/[ \t]/, "", id); b = $3; gsub(/^[ \t]+|[ \t]+$/, "", b); print id "\t" b }' "$WORK/s1" > "$WORK/sevs"
if cmp -s "$WORK/base" "$WORK/sevs"; then ok; else bad "R9 the ai-severity table and references/ai-rules.md disagree: $(diff "$WORK/base" "$WORK/sevs" | grep '^[<>]' | head -2 | tr '\n' ';')"; fi

# R10 every path a skill or the agent names exists
for f in $ALL; do
  d=$(dirname "$f")
  grep -oE '\$PLUGIN_ROOT/[A-Za-z0-9_./-]+' "$f" | sed 's|^\$PLUGIN_ROOT/||; s|[.,]$||' | sort -u | while read -r p; do
    [ -e "$PLUGIN/$p" ] || echo "R10 $(rel "$f") names \$PLUGIN_ROOT/$p, which does not exist"
  done > "$WORK/miss"
  grep -oE '\]\([^)#]+' "$f" | sed 's/^](//' | grep -v '^http' | sort -u | while read -r p; do
    [ -e "$d/$p" ] || echo "R10 $(rel "$f") links $p, which does not exist"
  done >> "$WORK/miss"
  if [ -s "$WORK/miss" ]; then bad "$(head -1 "$WORK/miss")"; else ok; fi
done

# R11 the AI behavior lens, in all four tables
for f in "$ROOT/docs/framework/OWNERSHIP.md" "$ROOT/plugins/ascent-delivery/skills/delivery-loop/SKILL.md" "$ROOT/plugins/ascent-delivery/skills/delivery-loop/references/review-lenses.md" "$ROOT/plugins/ascent-delivery/README.md"; do
  if grep -Eq '^\| AI behavior \| `ascent-ai:ai-reviewer`' "$f"; then ok; else bad "R11 ${f#"$ROOT"/} has no AI behavior lens row for ascent-ai:ai-reviewer"; fi
done

printf "test-ai-rules: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
