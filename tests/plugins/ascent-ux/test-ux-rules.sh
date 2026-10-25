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
#   Trial calibration (2026-10-24):
#   R13 the browser pass is mandatory when Playwright is present; "not run" needs a reason
#   R14 the agent's inline ux: key list equals the keys of the contract template
#   R15 core-flow severities from a guessed contract are labelled "(core flow guessed)"
#   R16 one contrast finding per failing foreground token (ux-review, agent, design-system-check)
#   R17 the agent never rates estimated contrast
#   R18 file:// may be blocked (ask for a localhost server); .playwright-mcp/ is reported, never deleted
#   R19 the blueprint's tables scroll in a labelled, focusable region (1.4.10)
#   R20 design-directions offers a brand-adapted option
#   R21 "met" never without a target, and maturity gaps always rated (Rules section)
#   Re-trial calibration (2026-10-25):
#   R22 the three scripts run awk with LC_ALL=C (line numbers after non-ASCII text)
#   R23 NOTE lines from check-web-accessibility.sh are unrated and never a pass
#   R24 the agent applies U11 per selector with box-shadow rings, and U12 to delegated listeners
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

SYSCHK="$PLUGIN/skills/design-system-check/SKILL.md"
BPX="$PLUGIN/blueprints/accessible-page"
has R13 "$REVIEW" 'the browser pass is **not optional**'
has R13 "$REVIEW" '**"Not run" needs a concrete reason:**'
TKEYS=$(awk '/^ux:/{on=1; next} on && /^[^ #]/{on=0} on && /^  [a-z_]+:/{sub(/^  /, ""); sub(/:.*/, ""); print}' "$TEMPLATE" | LC_ALL=C sort | tr '\n' ' ')
AKEYS=$(sed -n 's/.*The `ux:` keys are \(.*\) Use no other keys\..*/\1/p' "$AGENT" | sed 's/([^)]*)//g' | grep -oE '`[a-z_]+`' | tr -d '`' | grep -vE '^(lcp_ms|inp_ms|cls|page_kb|name)$' | LC_ALL=C sort -u | tr '\n' ' ')
if [ -n "$TKEYS" ] && [ "$TKEYS" = "$AKEYS" ]; then ok; else bad "R14 agent ux: keys '$AKEYS' differ from the template's '$TKEYS'"; fi
for k in lcp_ms inp_ms cls page_kb; do grep -q "^  performance_budget:.*$k" "$TEMPLATE" && grep -qF "\`$k\`" "$AGENT" && ok || bad "R14 performance_budget key $k missing from the template or the agent"; done
has R15 "$REVIEW" '"(core flow guessed)"'
has R15 "$AGENT" '"(core flow guessed)"'
has R16 "$REVIEW" '**One contrast finding per failing foreground token**'
has R16 "$AGENT" 'One rated finding per failing token'
has R16 "$SYSCHK" 'each failing foreground token is one Medium finding'
has R17 "$AGENT" 'suspected low contrast, not computed'
has R18 "$REVIEW" 'Some Playwright setups block `file://`'
has R18 "$REVIEW" 'Never delete files in the reviewed repository yourself.'
has R18 "$DIRECT" 'If `file://` is blocked, ask the operator to serve the mock directory on localhost'
has R19 "$BPX/page.css" '.table-wrap { overflow-x: auto;'
has R19 "$BPX/index.html" 'class="table-wrap" role="region" aria-labelledby="standings-caption" tabindex="0"'
has R20 "$DIRECT" '**Brand-adapted option.**'
has R21 "$REVIEW" '**Never "met" without a target.**'
has R21 "$REVIEW" '**Maturity gaps are always rated.**'
for s in check-web-accessibility.sh check-token-contrast.sh tokens-to-css.sh; do
  grep -q ' LC_ALL=C awk "$PROG" ' "$PLUGIN/scripts/$s" && ok || bad "R22 scripts/$s does not run awk with LC_ALL=C"
done
has R23 "$REVIEW" 'Each `NOTE` line is unrated: list it under Other observations'
has R23 "$AUDIT" 'A `NOTE` line is never a pass'
has R24 "$AGENT" 'A box-shadow ring in the same `:focus` rule replaces it too'
has R24 "$AGENT" 'That includes delegated listeners'

printf "test-ux-rules: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
