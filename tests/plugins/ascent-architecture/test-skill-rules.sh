#!/usr/bin/env bash
# Rule test for the ascent-architecture skills and agent (trial calibration, 2026-10-24).
#
# The tennis trial showed rules that were missing or unenforced; each one is
# pinned here so it cannot silently go away:
#   R1  every $PLUGIN_ROOT/<path> a skill or the agent names exists
#   R2  architecture-review names the pricing file (it once looked in references/)
#   R3  the maturity_target values quoted in architecture-review and the agent are
#       exactly those in references/contract-template.yml
#   R4  architecture-review and the agent route off-table concerns to
#       "Other observations (unrated)"
#   R5  a missing target makes an attribute "unmeasured, never met", or at risk
#       when the evidence shows a gap (both files)
#   R6  architecture-review requires fresh evidence (no findings carried over)
#   R7  deployment-options puts the profile, script lines and ADR text in the report
#   R8  every "<skill> Step N" a skill cites names a skill and a heading that exist
#   R9  the severity table has the multi-step write row (test-plugins T5 keeps
#       every copy identical)
#   R10 both files search client code for secrets, High even when unpublished
#   R11 both files recommend ascent-security when an item is referred to it
#   R12 no skill, the agent or the README calls a plugin that ships in this repository "planned"
#   R13 both files route operations-only concerns to ascent-ops and recommend it when an
#       item is referred to it (0.2.1)
#
# Prints "test-skill-rules: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-architecture"
REVIEW="$PLUGIN/skills/architecture-review/SKILL.md"
DEPLOY="$PLUGIN/skills/deployment-options/SKILL.md"
AGENT="$PLUGIN/agents/architecture-reviewer.md"
TEMPLATE="$PLUGIN/references/contract-template.yml"
for f in "$REVIEW" "$DEPLOY" "$AGENT" "$TEMPLATE"; do
  [ -f "$f" ] || { echo "test-skill-rules: missing $f"; echo "test-skill-rules: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
has() {  # ID FILE FIXED-STRING
  if grep -qF -- "$3" "$2"; then ok; else bad "$1 ${2#"$PLUGIN"/} does not contain: $3"; fi
}

# R1 — named plugin paths exist
NPATHS=0
for f in "$PLUGIN"/skills/*/SKILL.md "$AGENT"; do
  for p in $(grep -oE '\$PLUGIN_ROOT/[A-Za-z0-9._/-]+' "$f" | sed 's|^\$PLUGIN_ROOT/||' | LC_ALL=C sort -u); do
    NPATHS=$((NPATHS + 1))
    if [ -e "$PLUGIN/$p" ]; then ok; else bad "R1 ${f#"$PLUGIN"/} names \$PLUGIN_ROOT/$p, which does not exist"; fi
  done
done
[ "$NPATHS" -gt 0 ] || bad "R1 no \$PLUGIN_ROOT paths found at all"

# R2 — the review skill knows where pricing lives
has R2 "$REVIEW" '$PLUGIN_ROOT/pricing/aws-us-east-1.tsv'
has R2 "$REVIEW" '$PLUGIN_ROOT/blueprints/static-site-serverless-aws/usage-small.tsv'

# R3 — maturity values match the contract template
VALUES=$(sed -n 's/^[[:space:]]*# \(enterprise\) (default) | \([a-z |]*\)\..*/\1 | \2/p' "$TEMPLATE" | head -1)
if [ -z "$VALUES" ]; then
  bad "R3 cannot read the maturity_target values from references/contract-template.yml"
else
  # "enterprise | standard | prototype" -> "enterprise, standard or prototype"
  LIST=$(printf '%s\n' "$VALUES" | awk -F' [|] ' '{ s = $1; for (i = 2; i < NF; i++) s = s ", " $i; if (NF > 1) s = s " or " $NF; print s }')
  has R3 "$REVIEW" "\`maturity_target\` is one of $LIST"
  has R3 "$AGENT" "\`maturity_target\` is one of $LIST"
fi

# R4 — off-table concerns are unrated
has R4 "$REVIEW" '**Other observations (unrated)**'
has R4 "$REVIEW" 'Other observations (unrated):'
has R4 "$AGENT" '**Other observations (unrated)**'

# R5 — no target, no "met"
has R5 "$REVIEW" 'unmeasured, never met'
has R5 "$AGENT" 'unmeasured, never met'
has R5 "$REVIEW" 'at risk instead when the evidence shows a gap'
has R5 "$AGENT" 'at risk instead when the evidence shows a gap'

# R6 — fresh evidence
has R6 "$REVIEW" '**Fresh evidence.**'

# R7 — the report carries the content, not a path
has R7 "$DEPLOY" '**Everything in the report.**'
has R7 "$DEPLOY" '`TOTAL`, `FLAT-RATE`, `NOTE` and `WARN` lines verbatim'

# R8 — cross-skill step references resolve
NREFS=0
for f in "$PLUGIN"/skills/*/SKILL.md; do
  refs=$(sed 's/`//g' "$f" | grep -oE '[a-z][a-z0-9]*-[a-z0-9-]+ Steps? [0-9][0-9, –-]*' || true)
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    skill=${ref%% Step*}
    if [ ! -f "$PLUGIN/skills/$skill/SKILL.md" ]; then bad "R8 ${f#"$PLUGIN"/} cites $skill, which is not a skill"; continue; fi
    for n in $(printf '%s' "${ref#* Step}" | tr -cs '0-9' ' '); do
      NREFS=$((NREFS + 1))
      if grep -q "^### Step $n " "$PLUGIN/skills/$skill/SKILL.md"; then ok; else bad "R8 ${f#"$PLUGIN"/} cites $skill Step $n, which does not exist"; fi
    done
  done <<EOF_REFS
$refs
EOF_REFS
done
[ "$NREFS" -gt 0 ] || bad "R8 no skill step references found at all"

# R9 — the multi-step write row
has R9 "$REVIEW" '| Multi-step write with no transaction and no idempotency, so a failure leaves partial state (section 4, API design) | Medium |'

# R10 — secrets in client code are looked for, and rated High even before publishing
has R10 "$REVIEW" 'secrets in client code: search the served HTML and JavaScript and the templates'
has R10 "$REVIEW" 'A hit is High per the severity table whether or not the page is published yet'
has R10 "$AGENT" 'a hit is High whether or not the page is published yet'

# R11 — referrals reach Recommended next
has R11 "$REVIEW" 'Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`.'
has R11 "$AGENT" 'Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`.'

# R12 — a shipped plugin is never called planned
for d in "$PLUGIN"/../ascent-*/; do
  p=$(basename "$d")
  for f in "$PLUGIN"/skills/*/SKILL.md "$AGENT" "$PLUGIN/README.md"; do
    if grep -qE "\`$p\`( plugin)? \(planned\)" "$f"; then bad "R12 ${f#"$PLUGIN"/} calls \`$p\` planned, but it ships in plugins/"; else ok; fi
  done
done

# R13 — operations referrals reach Recommended next
has R13 "$REVIEW" 'Operations-only concerns that match no row (runbook steps, script hygiene, configuration stores, manuals, drill records) go under Other observations marked `→ ascent-ops`.'
has R13 "$REVIEW" 'Recommended next names `ascent-ops` whenever any item is marked `→ ascent-ops`.'
has R13 "$AGENT" 'or `→ ascent-ops` when it is operations-only'
has R13 "$AGENT" 'Recommended next names `ascent-ops` whenever any item is marked `→ ascent-ops`.'
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

printf "test-skill-rules: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
