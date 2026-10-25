#!/usr/bin/env bash
# Rule test for the ascent-ux skills and agent (ADR-012). The lessons of the
# ascent-architecture trial are pinned from day one, plus the UX-specific rules:
#   R1  every $PLUGIN_ROOT/<path> a skill or the agent names exists
#   R2  the maturity_target and conformance values quoted in ux-review and the agent
#       are exactly those in references/contract-template.yml
#   R3  ux-review and the agent route off-table concerns to "Other observations (unrated)"
#   R4  a missing target is "unmeasured, never met", or at risk when the evidence shows a gap
#   R5  ux-review requires fresh evidence and repository-relative file:line evidence
#   R6  no conformance claims from automation, in ux-review and the agent
#   R7  the browser pass is file:// or localhost only and never submits real data
#   R8  design-directions writes mock files only, never tracked files, and shows only
#       options that passed the checks
#   R9  every report carries the manual checklist; the law map is dated and not legal advice
#   R10 security items are referred, and Recommended next names ascent-security
#   R11 every "<skill> Step N" a skill cites names a skill and a heading that exist
#   R12 the design-directions catalog names exactly the shipped direction files
#
# Prints "test-ux-rules: N/N PASS" last (make/test-plugins.sh T11 requires it).
# Portable: bash 3.2+, GNU/Linux and BSD/macOS.

set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN="$HERE/../../../plugins/ascent-ux"
REVIEW="$PLUGIN/skills/ux-review/SKILL.md"
AUDIT="$PLUGIN/skills/accessibility-audit/SKILL.md"
DIRECT="$PLUGIN/skills/design-directions/SKILL.md"
AGENT="$PLUGIN/agents/ux-reviewer.md"
TEMPLATE="$PLUGIN/references/contract-template.yml"
LAW="$PLUGIN/references/accessibility-law-map.md"
for f in "$REVIEW" "$AUDIT" "$DIRECT" "$AGENT" "$TEMPLATE" "$LAW"; do
  [ -f "$f" ] || { echo "test-ux-rules: missing $f"; echo "test-ux-rules: 0/1 PASS"; exit 1; }
done

PASS=0; FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); printf "FAIL  %s\n" "$1"; }
has() { if grep -qF -- "$3" "$2"; then ok; else bad "$1 ${2#"$PLUGIN"/} does not contain: $3"; fi; }
# list_of "a | b | c" -> "a, b or c"
list_of() { printf '%s\n' "$1" | awk -F' [|] ' '{ s = $1; for (i = 2; i < NF; i++) s = s ", " $i; if (NF > 1) s = s " or " $NF; print s }'; }

# R1 — named plugin paths exist
NPATHS=0
for f in "$PLUGIN"/skills/*/SKILL.md "$AGENT"; do
  for p in $(grep -oE '\$PLUGIN_ROOT/[A-Za-z0-9._/-]+' "$f" | sed 's|^\$PLUGIN_ROOT/||' | LC_ALL=C sort -u); do
    NPATHS=$((NPATHS + 1))
    if [ -e "$PLUGIN/$p" ]; then ok; else bad "R1 ${f#"$PLUGIN"/} names \$PLUGIN_ROOT/$p, which does not exist"; fi
  done
done
[ "$NPATHS" -gt 0 ] || bad "R1 no \$PLUGIN_ROOT paths found at all"

# R2 — contract values match the template
MAT=$(sed -n 's/^[[:space:]]*# \(enterprise\) (default) | \([a-z |]*\)\..*/\1 | \2/p' "$TEMPLATE" | head -1)
CONF=$(sed -n 's/^[[:space:]]*# \(wcag-2\.2-aa\) (default) | \([a-z0-9.| -]*\) (AA plus.*/\1 | \2/p' "$TEMPLATE" | head -1)
if [ -z "$MAT" ] || [ -z "$CONF" ]; then bad "R2 cannot read maturity_target or conformance values from the contract template"
else
  has R2 "$REVIEW" "\`maturity_target\` is one of $(list_of "$MAT")"
  has R2 "$AGENT" "\`maturity_target\` is one of $(list_of "$MAT")"
  has R2 "$REVIEW" "\`conformance\` is one of $(list_of "$CONF")"
fi

# R3 — off-table concerns are unrated
has R3 "$REVIEW" '**Other observations (unrated)**'
has R3 "$REVIEW" 'Other observations (unrated):'
has R3 "$AGENT" '**Other observations (unrated)**'

# R4 — no target, no "met"
has R4 "$REVIEW" 'unmeasured, never met; it is at risk instead when the evidence shows a gap'
has R4 "$AGENT" 'unmeasured, never met; it is at risk instead when the evidence shows a gap'

# R5 — fresh, exact evidence
has R5 "$REVIEW" '**Fresh evidence.**'
has R5 "$REVIEW" 'repository-relative `path/to/file:line` (never a bare file name or a directory)'
has R5 "$AGENT" 'repository-relative `path/to/file:line` (never a bare file name or a directory)'

# R6 — automation never claims conformance
has R6 "$REVIEW" '**No conformance claims from automation.**'
has R6 "$AGENT" 'Never claim conformance.'
has R6 "$AUDIT" 'It never claims conformance itself.'

# R7 — browser pass safety
has R7 "$REVIEW" 'only `file://` pages or a `localhost` server, or a URL the operator names'
has R7 "$REVIEW" '**Never** submit forms with real data, sign in with real credentials'
has R7 "$DIRECT" '`file://` or `localhost` only, and no real data'

# R8 — design-directions writes mocks only and shows only checked options
has R8 "$DIRECT" '**Mocks are the only files this skill writes**'
has R8 "$DIRECT" 'Never write tracked files'
has R8 "$DIRECT" '**Every option shown has passed the checks**'

# R9 — manual checklist and dated, non-legal law map
has R9 "$REVIEW" 'Manual checklist: <'
has R9 "$AUDIT" 'Manual checklist: <'
has R9 "$LAW" '**as_of: '
has R9 "$LAW" 'not legal advice'
has R9 "$REVIEW" '**Not legal advice.**'

# R10 — security referral
has R10 "$REVIEW" 'Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`.'
has R10 "$AGENT" 'Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`.'

# R11 — cross-skill step references resolve
NREFS=0
for f in "$PLUGIN"/skills/*/SKILL.md; do
  refs=$(sed 's/`//g' "$f" | grep -oE '[a-z][a-z0-9]*-[a-z0-9-]+ Steps? [0-9][0-9, –-]*' || true)
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    skill=${ref%% Step*}
    if [ ! -f "$PLUGIN/skills/$skill/SKILL.md" ]; then bad "R11 ${f#"$PLUGIN"/} cites $skill, which is not a skill"; continue; fi
    for n in $(printf '%s' "${ref#* Step}" | tr -cs '0-9' ' '); do
      NREFS=$((NREFS + 1))
      if grep -q "^### Step $n " "$PLUGIN/skills/$skill/SKILL.md"; then ok; else bad "R11 ${f#"$PLUGIN"/} cites $skill Step $n, which does not exist"; fi
    done
  done <<EOF_REFS
$refs
EOF_REFS
done
[ "$NREFS" -gt 0 ] || bad "R11 no skill step references found at all"

# R12 — the catalog in design-directions matches the shipped files
SHIPPED=$(cd "$PLUGIN/directions" && ls ./*.light.tokens.json 2>/dev/null | sed 's|^\./||; s/-.*//' | LC_ALL=C sort | tr '\n' ' ')
LISTED=$(sed -n 's/^| \(D[0-9][0-9]*\) | .*/\1/p' "$DIRECT" | LC_ALL=C sort | tr '\n' ' ')
if [ -n "$SHIPPED" ] && [ "$SHIPPED" = "$LISTED" ]; then ok; else bad "R12 design-directions lists '$LISTED' but directions/ ships '$SHIPPED'"; fi
for d in $SHIPPED; do
  ls "$PLUGIN/directions/$d"-*.dark.tokens.json >/dev/null 2>&1 && ok || bad "R12 $d has no dark tokens file"
done

printf "test-ux-rules: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
