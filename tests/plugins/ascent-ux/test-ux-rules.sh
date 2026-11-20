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
#   R24 the agent applies UX-U11 per selector with box-shadow rings, and UX-U12 to delegated listeners
#   ascent-ux 0.3.0 (ADR-022):
#   R25 the ladder names the lowest principle at risk, lists unmeasured ones apart, never changes a severity
#   R26 ux-review Step 2 reports exactly the seven lenses, grouped by the four principles
#   R27 the pleasant principle is never "met" (skills, agent, script output)
#   R28 the walk navigates only, unless test_data names a fixture, on localhost
#   R29 an engine the operator does not run is unmeasured; a project's Playwright config is never run
#   R30 a UX-R failure is read against the hook or service the file imports before it is rated
#   R31 every script option flow-check names exists in that script's usage line, and every option is named
#   R32 every UX-F, UX-R and UX-P rule in the reference has a row in the severity table
#   R33 every skill directory is in the README components table; ux-review recommends flow-check
#   Review before release (2026-11-13):
#   R34 the browser rules' fail conditions and severities are pinned (UX-F5, UX-F6, UX-R5)
#   R35 a missing key is unmeasured whatever a script prints; flow-check NOTE lines are unrated
#   R36 with no confirmed contract, the unmeasured targets are one Low finding
#   R37 an untrusted repository: contract values quoted, the fixture inside the repo,
#       no git status there, a dev-server warning, navigation only on an operator's URL
#   R38 the README shows how to add a server per engine, and flow-check links to it
#   0.3.1:
#   R39 the agent rates a box-shadow ring under 3:1, matches delegated selectors from any
#       scanned file, and rates dead ends off the core flows; the docs say the script reads
#       one level of imports for UX-R1 and UX-R2
#   R40 the Firefox and WebKit trial: browsers installed with the server's own playwright
#       version, and the engine differences that are not findings
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
FLOWCHK="$PLUGIN/skills/flow-check/SKILL.md"
REF="$PLUGIN/references/flow-and-reliability.md"
for f in "$REVIEW" "$AUDIT" "$DIRECT" "$AGENT" "$TEMPLATE" "$LAW" "$FLOWCHK" "$REF"; do
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
has R7 "$REVIEW" 'only `file://` pages, a `localhost` server (`localhost`, `127.0.0.1` or `[::1]`, on the port the operator confirms), or a URL the operator names, for navigation only'
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
LISTED=$(sed -n 's/^| UX-\(D[0-9][0-9]*\) | .*/\1/p' "$DIRECT" | LC_ALL=C sort | tr '\n' ' ')
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
for s in check-web-accessibility.sh check-token-contrast.sh tokens-to-css.sh check-flow-integrity.sh check-ux-resilience.sh; do
  grep -q ' LC_ALL=C awk "$PROG" ' "$PLUGIN/scripts/$s" && ok || bad "R22 scripts/$s does not run awk with LC_ALL=C"
done
has R23 "$REVIEW" 'Each `NOTE` line is unrated: list it under Other observations'
has R23 "$AUDIT" 'A `NOTE` line is never a pass'
has R24 "$AGENT" 'A box-shadow ring in the same `:focus` rule replaces it too'
has R24 "$AGENT" 'That includes delegated listeners'

# R25 — the ladder orders the report and never rates
has R25 "$REVIEW" 'The report names the lowest principle at risk, and lists the unmeasured principles apart with the key each one needs'
has R25 "$REVIEW" 'The ladder orders the report; it never changes a severity.'
has R25 "$REF" 'The ladder orders the report; it never changes a finding'"'"'s severity.'
has R25 "$AGENT" 'the principles line (the lowest principle at risk, and the unmeasured ones apart)'
has R25 "$REVIEW" 'lowest at risk: <principle or "none">; unmeasured: <principle (missing key), … or "none">'

# R26 — seven lenses in four groups
LENSES=$(sed -n '/^### Step 2 /,/^### Step 3 /p' "$REVIEW" | sed -n 's/^- \*\*\([A-Za-z ]*\):\*\*.*/\1/p' | tr '\n' '|')
[ "$LENSES" = "Flow integrity|Usability heuristics|Reliability|States and content|Performance UX|Accessibility|Design system|" ] && ok || bad "R26 ux-review Step 2 lenses are '$LENSES'"
PGROUPS=$(sed -n '/^### Step 2 /,/^### Step 3 /p' "$REVIEW" | grep -oE '^\*\*(Functional|Reliable|Accessible|Pleasant)\*\*' | tr -d '*' | tr '\n' '|')
[ "$PGROUPS" = "Functional|Reliable|Accessible|Pleasant|" ] && ok || bad "R26 ux-review Step 2 principle groups are '$PGROUPS'"

# R27 — pleasant is observed, never met
has R27 "$REVIEW" 'as **observed** or **at risk**, never met.'
has R27 "$AGENT" 'A UX-P rule that passes is "observed", never "met".'
has R27 "$FLOWCHK" '**The pleasant principle is never met.**'
has R27 "$REF" 'A UX-P rule that passes is reported as "observed", never "met"'
has R27 "$PLUGIN/scripts/check-ux-resilience.sh" '"; observed, never met"'

# R28 — the walk is safe
has R28 "$FLOWCHK" '**The walk navigates; it never acts for real.**'
has R28 "$FLOWCHK" 'only when `core_flows[].test_data` names a fixture file and the target is `localhost`'
has R28 "$REVIEW" 'Navigation only, unless `test_data` names a fixture file and the target is `localhost`; on a URL the operator names, navigation only.'
has R28 "$REF" 'Never real data, never credentials, never a link off the site.'

# R29 — engines
has R29 "$FLOWCHK" 'An engine the operator does not run is unmeasured, never passed.'
has R29 "$FLOWCHK" 'is supporting evidence and is never run'
has R29 "$REVIEW" 'An engine not run is unmeasured.'

# R30 — imports are read before a UX-R failure is rated
has R30 "$FLOWCHK" 'before rating a UX-R1, R2, R3 or R4 `FAIL`, read the hook or service the file imports'
has R30 "$REVIEW" 'A UX-R `FAIL` is read against the shared hook or service the file imports before it is rated'
has R30 "$AGENT" 'A guard, failure branch, draft or retry in a shared hook or service the file imports counts'

# R31 — flow-check names exactly the scripts' options
for sc in check-flow-integrity.sh check-ux-resilience.sh; do
  USAGE=$(grep -m1 '^# Usage: ' "$PLUGIN/scripts/$sc")
  NAMED=$(grep -F "scripts/$sc" "$FLOWCHK" | grep -oE -- '--[a-z-]+' | LC_ALL=C sort -u)
  OPTS=$(printf '%s\n' "$USAGE" | grep -oE -- '--[a-z-]+' | LC_ALL=C sort -u)
  [ -n "$NAMED" ] && [ "$NAMED" = "$OPTS" ] && ok || bad "R31 flow-check names '$(echo $NAMED)' for $sc; its usage line has '$(echo $OPTS)'"
done

# R32 — every rule in the reference is rated by the severity table
SEVBLOCK=$(sed -n '/ux-severity:start/,/ux-severity:end/p' "$REVIEW")
NIDS=0
for id in $(grep -oE '^\| UX-[FRP][0-9]+ ' "$REF" | tr -d '| '); do
  NIDS=$((NIDS + 1))
  printf '%s\n' "$SEVBLOCK" | grep -qE "$id[^0-9]" && ok || bad "R32 $id is defined in the reference but has no severity row"
done
[ "$NIDS" -eq 18 ] || bad "R32 expected 18 UX-F, UX-R and UX-P rules in the reference, found $NIDS"

# R33 — every skill is documented; ux-review recommends flow-check
for d in "$PLUGIN"/skills/*/; do
  sk=$(basename "$d"); grep -qF "| \`$sk\` | skill" "$PLUGIN/README.md" && ok || bad "R33 README components table has no row for skill $sk"
done
has R33 "$REVIEW" 'Flow integrity or reliability at risk or unmeasured: recommend [flow-check](../flow-check/SKILL.md).'

# R34 — the browser rules: what fails them, and how severe it is
has R34 "$FLOWCHK" 'A same-origin 4xx or 5xx, or an uncaught error, is a UX-F5 finding'
has R34 "$FLOWCHK" 'A failure that blocks a core flow in one engine is High (UX-F6); a layout or focus defect that does not block it is Medium.'
has R34 "$FLOWCHK" 'The view state comes back from the URL, or it is a confirmed UX-R5 finding.'
has R34 "$REVIEW" 'On `localhost` only, check Back and refresh on the `url_state` pages (UX-R5).'
sevrow() { printf '%s\n' "$SEVBLOCK" | grep -F -- "$2" | grep -qF "| $3 |" && ok || bad "R34 the severity row for $1 is not $3"; }
sevrow UX-F5-core 'a same-origin error on the walk (UX-F5), or a failure in a listed engine (UX-F6)' High
sevrow UX-F5-off 'a dead script on a page off the core flows (UX-F5)' Medium
sevrow UX-F6-layout 'A layout or focus defect in one listed engine that does not block a core flow (UX-F6)' Medium
sevrow UX-R5-core 'or loses listed view state on Back or refresh (UX-R5)' Medium
sevrow UX-R5-off 'listed view state lost on Back or refresh off the core flows (UX-R5)' Low
sevrow UX-F3-off 'that no link reaches or that has no way back (UX-F3)' Low

# R35 — unmeasured stays unmeasured; NOTE lines are unrated
has R35 "$REVIEW" 'is reported as unmeasured, whatever the script prints'
has R35 "$FLOWCHK" 'Each `NOTE` line (a link built at runtime, an id set at runtime, a route step) is unrated'

# R36 — no contract: one finding, not one per target
has R36 "$REVIEW" 'One exception: with no confirmed contract, the unmeasured targets, and the maturity gaps that a missing key alone causes, are one Low finding'
printf '%s\n' "$SEVBLOCK" | grep -qF 'with no confirmed contract, one finding for all of them (Step 6) | Low |' && ok || bad "R36 the unmeasured row does not say one finding with no contract"

# R37 — the reviewed repository is untrusted
has R37 "$REVIEW" '**Quote contract values.** Single-quote every value taken from the contract'
has R37 "$FLOWCHK" 'Single-quote every value in the commands; a value that contains a quote, `$`, `;`, a backtick or a newline is a contract error, never passed.'
has R37 "$FLOWCHK" 'The fixture must be a file inside the reviewed repository, never `.env*`, a key or a credentials file'
has R37 "$REF" 'The fixture is a file inside the reviewed repository, never `.env*`, a key or a credentials file'
has R37 "$REVIEW" 'Never run `git status` there; an untrusted repository'
has R37 "$FLOWCHK" 'never `git status` there: an untrusted repository'
has R37 "$REVIEW" 'A dev server runs the reviewed repository'
has R37 "$FLOWCHK" 'on a URL the operator names it navigates only, with no submit and none of the localhost-only checks below'
for f in "$REVIEW" "$FLOWCHK"; do grep -qE 'run `git status` in the reviewed|^After the (pass|walk), run `git status`' "$f" && bad "R37 $(basename "$(dirname "$f")") still runs git status in the reviewed repository" || ok; done

# R38 — other engines
has R38 "$PLUGIN/README.md" '## Other engines'
has R38 "$PLUGIN/README.md" 'claude mcp add --scope local playwright-firefox -- npx @playwright/mcp@latest --browser firefox'
has R38 "$FLOWCHK" '[Other engines](../../README.md#other-engines)'
grep -qF -- '--browser firefox` (or' "$FLOWCHK" && bad "R38 flow-check still asks for a restart of the companion server" || ok

# R39 — 0.3.1: ring contrast, delegated selectors across files, dead ends, imports
has R39 "$AGENT" 'replaces it too when one of its layers has 3:1 against the page background'
has R39 "$AGENT" 'Under 3:1 it is a finding'
has R39 "$AGENT" 'a click listener in any scanned file finds'
has R39 "$AGENT" 'is a dead end: Low, Medium in a core file'
has R39 "$REF" 'a page with none is a dead end (Low; Medium in a core file)'
has R39 "$REF" 'UX-R1 and UX-R2 also read the local modules a file imports'
has R39 "$FLOWCHK" 'For UX-R1 and UX-R2 the script also reads the local modules a file imports'
has R39 "$REVIEW" 'the script reads relative imports one level deep and names them in the finding'

# R40 — the Firefox and WebKit trial (v0.4.20)
has R40 "$PLUGIN/README.md" 'PW="$(npm view @playwright/mcp@latest dependencies.playwright)"'
has R40 "$PLUGIN/README.md" 'npx -y "playwright@$PW" install firefox webkit'
grep -q '^npx playwright install' "$PLUGIN/README.md" && bad "R40 the README installs browsers with the latest playwright, not the server's" || ok
grep -qF 'have not been trialled yet' "$PLUGIN/README.md" && bad "R40 the README still says Firefox and WebKit are not trialled" || ok
has R40 "$FLOWCHK" 'Check keyboard reach in WebKit with `Alt+Tab`.'
has R40 "$FLOWCHK" 'Read UX-F5 from `browser_network_requests` in every engine, never from the console alone.'
has R40 "$FLOWCHK" 'Reload once: report it only if it comes back.'

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

printf "test-ux-rules: %s/%s PASS\n" "$PASS" "$((PASS + FAIL))"
[ "$FAIL" -eq 0 ]
