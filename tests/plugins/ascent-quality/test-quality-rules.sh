#!/usr/bin/env bash
# Rule test for the ascent-quality skills and agent (ADR-014, ADR-019, ADR-021). The
# lessons of the earlier plugins' trials are pinned from day one, plus the
# quality-specific rules:
#   R1  every $PLUGIN_ROOT/<path> a skill or the agent names exists
#   R2  the maturity_target values quoted in quality-review and the agent are
#       exactly those in references/contract-template.yml
#   R3  quality-review and the agent route off-table concerns to "Other
#       observations (unrated)"
#   R4  a missing target is "unmeasured, never met", or at risk when the evidence
#       shows a gap
#   R5  fresh evidence and repository-relative file:line evidence
#   R6  every check id a script prints is in the severity table at the severity
#       the script gives it, in its header and in every fail() call; the table
#       names no id the scripts do not print
#   R7  the agent's inline quality: key list equals the keys of the contract
#       template (with the tests and mutation sub-keys), and the test types it
#       quotes are those check-test-inventory.sh accepts
#   R8  every "<skill> Step N" a skill cites names a skill and a heading that exist
#   R9  every skill is read-only, never runs the tests, and quotes every contract
#       value it passes to a script
#   R10 other plugins' tests are referred with markers, and Recommended next
#       names ascent-security
#   R11 N/A is never a pass, NOTE lines are unrated and never a pass, and the two
#       heuristics (QA-H3, QA-I4) are opened before they are rated
#   R12 every script parses and runs under the system /bin/bash (3.2 on macOS)
#       with the same result as the bash on PATH
#   R13 the README maturity table and test-strategy.md name every rule family
#       the scripts check, and nothing else
#
# Prints "test-quality-rules: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/../../.."
PLUGIN="$ROOT/plugins/ascent-quality"
REVIEW="$PLUGIN/skills/quality-review/SKILL.md"
INV="$PLUGIN/skills/test-inventory/SKILL.md"
TCHK="$PLUGIN/skills/test-check/SKILL.md"
TEV="$PLUGIN/skills/test-evidence/SKILL.md"
AGENT="$PLUGIN/agents/quality-reviewer.md"
TEMPLATE="$PLUGIN/references/contract-template.yml"
STRAT="$PLUGIN/references/test-strategy.md"
README="$PLUGIN/README.md"
GOOD="$HERE/fixtures/quality-good"
EVID="$HERE/fixtures/evidence-good"
for f in "$REVIEW" "$INV" "$TCHK" "$TEV" "$AGENT" "$TEMPLATE" "$STRAT" "$README"; do
  [ -f "$f" ] || { echo "test-quality-rules: missing $f"; echo "test-quality-rules: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
has() { if grep -qF -- "$3" "$2"; then ok; else bad "$1 ${2#"$ROOT"/} does not contain: $3"; fi; }
list_of() { printf '%s\n' "$1" | awk -F' [|] ' '{ s = $1; for (i = 2; i < NF; i++) s = s ", " $i; if (NF > 1) s = s " or " $NF; print s }'; }
EN=$(printf '\342\200\223')

# R1 — named plugin paths exist
NPATHS=0
for f in "$PLUGIN"/skills/*/SKILL.md "$AGENT"; do
  for p in $(grep -oE '\$PLUGIN_ROOT/[A-Za-z0-9._/-]+' "$f" | sed 's|^\$PLUGIN_ROOT/||' | LC_ALL=C sort -u); do
    NPATHS=$((NPATHS + 1))
    if [ -e "$PLUGIN/$p" ]; then ok; else bad "R1 ${f#"$PLUGIN"/} names \$PLUGIN_ROOT/$p, which does not exist"; fi
  done
done
[ "$NPATHS" -gt 0 ] || bad "R1 no \$PLUGIN_ROOT paths found at all"

# R2 — maturity values match the template
MAT=$(sed -n 's/^[[:space:]]*# \(enterprise\) (default) | \([a-z |]*\)\..*/\1 | \2/p' "$TEMPLATE" | head -1)
if [ -z "$MAT" ]; then bad "R2 cannot read maturity_target values from the contract template"
else
  has R2 "$REVIEW" "\`maturity_target\` is one of $(list_of "$MAT")"
  has R2 "$AGENT" "\`maturity_target\` is one of $(list_of "$MAT")"
fi

# R3 — off-table concerns are unrated
has R3 "$REVIEW" '**Other observations (unrated)**'
has R3 "$REVIEW" 'Other observations (unrated):'
has R3 "$AGENT" '**Other observations (unrated)**'
has R3 "$REVIEW" 'Never invent a severity.'
has R3 "$AGENT" 'Never invent a severity.'

# R4 — a missing target is unmeasured, never met
has R4 "$REVIEW" 'A lens whose target is missing from the contract is unmeasured, never met; it is at risk instead when the evidence shows a gap.'
has R4 "$AGENT" 'A target missing from the contract makes the lens unmeasured, never met; it is at risk instead when the evidence shows a gap.'

# R5 — fresh, repository-relative evidence
has R5 "$REVIEW" '**Fresh evidence.**'
has R5 "$REVIEW" 'repository-relative `path/to/file:line` (never a bare file name or a directory)'
has R5 "$AGENT" 'repository-relative `path/to/file:line` (never a bare file name or a directory)'
for f in "$INV" "$TCHK" "$TEV"; do has R5 "$f" 'repository-relative `file:line` evidence; fresh evidence'; done

# R6 — script check ids and severities match the table
TABLE=$(awk '/<!-- qa-severity:start/ { on = 1; next } /<!-- qa-severity:end/ { on = 0 } on' "$REVIEW")
[ -n "$TABLE" ] || bad "R6 quality-review has no qa-severity table"
PRINTED=""
for s in "$PLUGIN"/scripts/*.sh; do
  lib="$PLUGIN/scripts/lib/$(basename "$s" .sh).awk"
  [ -f "$lib" ] || { bad "R6 $(basename "$s") has no lib/$(basename "$s" .sh).awk"; continue; }
  while read -r id sev; do
    [ -n "$id" ] || continue
    PRINTED="$PRINTED $id"
    if printf '%s\n' "$TABLE" | grep -E "\($id\)" | grep -q "| $sev |\$"; then ok; else bad "R6 $(basename "$s") header gives $id $sev, but no table row names ($id) at $sev"; fi
    k=${id#QA-}
    while read -r fsev; do
      [ -n "$fsev" ] || continue
      [ "$fsev" = "$sev" ] && ok || bad "R6 $(basename "$lib") calls fail(\"$k\", \"$fsev\"), the header says $sev"
    done <<EOF_F
$(grep -oE "fail\(\"$k\", \"[A-Za-z]+\"" "$lib" | sed 's/.*, "//; s/"$//' | sort -u)
EOF_F
    grep -q "fail(\"$k\"" "$lib" || bad "R6 $(basename "$lib") never fails $id"
  done <<EOF_IDS
$(sed -nE 's/^#   (QA-[A-Z][0-9]+) +(High|Medium|Low) .*/\1 \2/p' "$s")
EOF_IDS
done
for id in $(printf '%s\n' "$TABLE" | grep -oE '\(QA-[A-Z][0-9]+\)' | tr -d '()' | sort -u); do
  case " $PRINTED " in *" $id "*) ok ;; *) bad "R6 the table names $id, which no script header prints" ;; esac
done
# Every copy of the table is identical to quality-review's (T5 checks it too).
[ "$(awk '/<!-- qa-severity:start/ { on = 1; next } /<!-- qa-severity:end/ { on = 0 } on' "$AGENT")" = "$TABLE" ] && ok || bad "R6 the agent's severity table differs from quality-review's"

# R7 — the agent's key list and test types
KEYS=$(awk '/^quality:/ { on = 1; next } on && /^[a-z]/ { on = 0 } on && /^  [a-z_]+:/ { k = $1; sub(/:$/, "", k); print k }' "$TEMPLATE" | tr '\n' ' ')
for k in $KEYS; do has R7 "$AGENT" "\`$k\`"; done
SUB=$(awk '/^  tests:/ { on = 1; next } on && /^  [a-z]/ { on = 0 } on && /^    [a-z_]+:/ { k = $1; sub(/:$/, "", k); print k }' "$TEMPLATE" | tr '\n' ',' | sed 's/,$//; s/,/`, `/g')
has R7 "$AGENT" "\`tests\` (\`$SUB\`)"
SUB=$(awk '/^  mutation:/ { on = 1; next } on && /^  [a-z]/ { on = 0 } on && /^    [a-z_]+:/ { k = $1; sub(/:$/, "", k); print k }' "$TEMPLATE" | tr '\n' ',' | sed 's/,$//; s/,/`, `/g')
[ -n "$SUB" ] && ok || bad "R7 the contract template has no quality.mutation keys"
has R7 "$AGENT" "\`mutation\` (\`$SUB\`)"
TYPES=$(sed -n 's/.*unit|integration|contract|e2e) ;;.*/unit, integration, contract, e2e/p' "$PLUGIN/scripts/check-test-inventory.sh" | head -1)
[ "$TYPES" = "unit, integration, contract, e2e" ] && ok || bad "R7 cannot read the types check-test-inventory.sh accepts"
has R7 "$AGENT" '`types_required` takes only unit, integration, contract and e2e'
has R7 "$REVIEW" '`types_required` takes only unit, integration, contract and e2e'
has R7 "$TEMPLATE" '# unit | integration | contract | e2e.'

# R8 — every "<skill> Step N" citation resolves
NREF=0
for f in "$PLUGIN"/skills/*/SKILL.md "$AGENT"; do
  for ref in $(grep -oE '`?(quality-review|test-inventory|test-check|test-evidence)`? Step [0-9]+' "$f" | tr -d '`' | tr ' ' '_' | LC_ALL=C sort -u); do
    NREF=$((NREF + 1)); sk=${ref%%_Step_*}; n=${ref##*_}
    if grep -q "^### Step $n " "$PLUGIN/skills/$sk/SKILL.md" 2>/dev/null; then ok; else bad "R8 ${f#"$PLUGIN"/} cites $sk Step $n, which has no heading"; fi
  done
done
[ "$NREF" -gt 0 ] || bad "R8 no step citations found"

# R9 — read-only, and the tests are never run
for f in "$REVIEW" "$INV" "$TCHK" "$TEV"; do
  tools=$(sed -n 's/^allowed-tools: //p' "$f")
  case "$tools" in *Write*|*Edit*|*"Bash("[!g]*|*"Bash(git push"*|*"Bash(git commit"*) bad "R9 ${f#"$PLUGIN"/} pre-approves a write: $tools" ;; *) ok ;; esac
done
has R9 "$REVIEW" '**Read-only.** Never edit files, write or fix a test, run the test suite, or install a test tool.'
has R9 "$INV" '**Never run the tests or CI**'
has R9 "$TCHK" '**Never edit, unskip or run a test.**'
has R9 "$TEV" '**Never run a load test or a mutation tool.**'
has R9 "$REVIEW" 'Never run a load test or a mutation tool.'
has R9 "$AGENT" 'Do not propose commands that modify the repository or run the tests.'
for f in "$REVIEW" "$INV" "$TCHK" "$TEV"; do has R9 "$f" '**Quote every contract value.** Put each value in single quotes'; done
has R9 "$REVIEW" 'never with `--output`, `--ext-diff` or `--textconv`'

# R10 — other plugins' tests are referred
for m in '→ ascent-ux' '→ ascent-ops' '→ ascent-delivery' '→ ascent-security'; do has R10 "$REVIEW" "$m"; has R10 "$AGENT" "$m"; done
has R10 "$REVIEW" 'Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`.'
has R10 "$AGENT" 'Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`.'

# R11 — N/A, NOTE and the two heuristics
has R11 "$REVIEW" '`N/A` is never a pass.'
has R11 "$REVIEW" '`NOTE` lines are unrated'
has R11 "$AGENT" 'A check with nothing to check is N/A, never a pass.'
has R11 "$REVIEW" '**QA-H3 and QA-I4 are heuristics.** Open each hit before you rate it.'
has R11 "$TCHK" '- **QA-H3 hits.** Open each one.'
has R11 "$INV" 'Open each QA-I4 hit.'
has R11 "$TEV" '**A NOTE is never a pass.**'

# R12 — /bin/bash gives the same result
if [ -x /bin/bash ]; then
  for s in "$PLUGIN"/scripts/*.sh "$PLUGIN"/scripts/lib/*.sh; do
    if /bin/bash -n "$s" 2>/dev/null; then ok; else bad "R12 $(basename "$s") does not parse under /bin/bash"; fi
  done
  a=$(cd "$GOOD" && bash "$PLUGIN/scripts/check-tests.sh" --criteria docs --core src/rules --helper check_close . 2>&1; echo "rc=$?")
  b=$(cd "$GOOD" && /bin/bash "$PLUGIN/scripts/check-tests.sh" --criteria docs --core src/rules --helper check_close . 2>&1; echo "rc=$?")
  if [ "$a" = "$b" ]; then ok; else bad "R12 check-tests.sh gives a different result under /bin/bash"; fi
  a=$(cd "$GOOD" && bash "$PLUGIN/scripts/check-test-inventory.sh" --types unit,integration,contract,e2e . 2>&1; echo "rc=$?")
  b=$(cd "$GOOD" && /bin/bash "$PLUGIN/scripts/check-test-inventory.sh" --types unit,integration,contract,e2e . 2>&1; echo "rc=$?")
  if [ "$a" = "$b" ]; then ok; else bad "R12 check-test-inventory.sh gives a different result under /bin/bash"; fi
  a=$(cd "$EVID" && bash "$PLUGIN/scripts/check-test-evidence.sh" --p95 400 --rps 50 --today 2026-11-01 . 2>&1; echo "rc=$?")
  b=$(cd "$EVID" && /bin/bash "$PLUGIN/scripts/check-test-evidence.sh" --p95 400 --rps 50 --today 2026-11-01 . 2>&1; echo "rc=$?")
  if [ "$a" = "$b" ]; then ok; else bad "R12 check-test-evidence.sh gives a different result under /bin/bash"; fi
fi

# R13 — the README and test-strategy.md name exactly the families the scripts check
FAMS=$(sed -nE 's/^#   QA-([A-Z])[0-9]+ +(High|Medium|Low) .*/\1/p' "$PLUGIN"/scripts/*.sh | sort -u | tr '\n' ' ')
[ -n "$FAMS" ] && ok || bad "R13 no rule families in the script headers"
for f in "$README" "$STRAT"; do
  for fam in $FAMS; do
    ids=$(sed -nE "s/^#   (QA-$fam[0-9]+) +(High|Medium|Low) .*/\1/p" "$PLUGIN"/scripts/*.sh | sort -u)
    [ -n "$ids" ] || { bad "R13 no QA-$fam ids in the script headers"; continue; }
    if grep -qE "QA-$fam[0-9]" "$f"; then ok; else bad "R13 ${f#"$PLUGIN"/} never names the QA-$fam rules"; fi
  done
  for id in $(grep -oE 'QA-[A-Z][0-9]+' "$f" | sort -u); do
    sed -nE 's/^#   (QA-[A-Z][0-9]+) .*/\1/p' "$PLUGIN"/scripts/*.sh | grep -qx "$id" && ok || bad "R13 ${f#"$PLUGIN"/} names $id, which no script checks"
  done
done
has R13 "$README" "QA-I1${EN}I5"
has R13 "$README" "QA-T1${EN}T4"
has R13 "$README" "QA-H1${EN}H4"
has R13 "$README" "QA-L1${EN}L5"
has R13 "$README" "QA-M1${EN}M4"

printf "test-quality-rules: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
