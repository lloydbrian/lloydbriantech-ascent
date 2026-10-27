---
name: design-directions
description: >-
  Use when asked "what should this look like?", "show me design options",
  "pick a look and feel", "mock designs", "re-theme the app", or when starting
  a new UI. Offers five predefined design directions (clean neutral, bold
  brand, editorial, soft friendly, dense professional) as visual mocks of the
  project's own pages, every one checked for WCAG contrast and accessibility
  before it is shown, generates more on request, and turns the choice into an
  ADR draft and a token file. Writes mock files only, never tracked files.
version: 0.1.1
allowed-tools: Read, Grep, Glob
---

# design-directions

Helps the operator choose a look and feel with real screens to compare, before code depends on it. It is the decide half of the ui-ux-designer role; [ux-review](../ux-review/SKILL.md) and [design-system-check](../design-system-check/SKILL.md) are the verify half. It is a sibling of `ux-review`: it uses that skill's contract, evidence rules and severities.

Each direction is a token set (Design Tokens format 2025.10, light and dark), not free-form CSS, so every option can be checked for contrast and carried straight into the repository. Sources: [the direction catalog](../../directions/README.md), [design-tokens.md](../../references/design-tokens.md), and the [accessible page blueprint](../../blueprints/accessible-page/README.md), which is the mock template.

`frontend-design` (installed with this plugin) guides new directions in Step 6, and `design:design-critique` can comment on a gallery. This skill keeps the catalog, the checks and the hand-off.

## Rules

- **Mocks are the only files this skill writes**, in the session scratchpad, or in `tmp/ux-mocks/` when `git check-ignore tmp/ux-mocks` confirms it is ignored. Never write tracked files, token files or styles in the repository. The ADR, the token file and the contract change are proposals the operator commits.
- **Every option shown has passed the checks** (Step 4). A direction that fails is fixed or dropped, never shown with a footnote.
- **No real personal data in mocks.** Use the project's public page text. Replace names, emails and scores of real people with neutral samples.
- **No imitation of another organization's brand**: logos, trademarked palettes or product look-alikes. Brand colors are the project's own, from its repository or from the operator.
- **Fonts:** a direction names font stacks with system fallbacks. Say when a named web font must be licensed and loaded; mocks render with whatever the machine has, and the gallery says which font was used.
- **Browser rules from `ux-review` Step 4:** `file://` or `localhost` only, and no real data.
- **The catalog guarantee is contrast.** Layout still depends on the page: check reflow at 320 px, focus and target sizes for every option in the browser, and fix the mock's structure, not the tokens, when it overflows.

## Steps

### Step 0 — Inputs

From the contract and the repository:
- `ux.direction` (a current choice)
- the personas
- the core flows
- any brand colors or logo in the repository
- the current token source

For an existing project, the current look is **D0 — current**. It is shown next to the catalog and checked the same way, so the comparison is honest.

### Step 1 — Pages to mock

Pick the one to three pages that matter most: the home or landing page, and the main core-flow page (a form, a list, a dashboard). Take their real structure and public text.
- If the project's CSS already uses custom properties, mock by overriding those properties.
- Otherwise, place the content into the blueprint's structure (header, navigation, main, a card, a table, a form, an empty state, a footer).

### Step 2 — The catalog

| Id | Direction | Feels like | Suits |
|---|---|---|---|
| D1 | Clean neutral | calm, generous white space, one accent | most apps; the safe default |
| D2 | Bold brand | strong color, large type, high contrast | marketing and community sites |
| D3 | Editorial | serif headings, reading first, comfortable line length | docs and content sites |
| D4 | Soft friendly | rounded corners, warm palette, gentle motion | consumer and hobby apps |
| D5 | Dense professional | compact spacing, data-first palette, crisp lines | dashboards and admin tools |

Recommend the two that best fit the personas and core flows, with one reason each, but always build all five. The operator chooses.

**Brand-adapted option.** When the project has its own brand colors (its current accent, logo colors, or colors the operator names), also offer **D<n>-brand**: the top recommendation with its accent and focus colors replaced by the brand hue, adjusted until every pair in `pairs.tsv` passes. Build it as a D6+ option (Step 6) and show it next to the catalog, so the operator can keep their identity without losing accessibility.

### Step 3 — Build the mocks

For each direction, and for D0:

```bash
bash "$PLUGIN_ROOT/scripts/tokens-to-css.sh" \
  "$PLUGIN_ROOT/directions/<Dn>.light.tokens.json" "$PLUGIN_ROOT/directions/<Dn>.dark.tokens.json" > <mock dir>/<Dn>/tokens.css
```

`PLUGIN_ROOT` is two directories above this skill's base directory. Copy the blueprint's `page.css` next to it, and write each mock page with the Step 1 content. Each mock folder holds only `tokens.css`, `page.css` and the mock pages.

### Step 4 — Verify each option

For each mock, include the output verbatim and drop or fix anything that fails:

```bash
bash "$PLUGIN_ROOT/scripts/check-token-contrast.sh" --pairs "$PLUGIN_ROOT/directions/pairs.tsv" \
  "$PLUGIN_ROOT/directions/<Dn>.light.tokens.json" "$PLUGIN_ROOT/directions/<Dn>.dark.tokens.json"
bash "$PLUGIN_ROOT/scripts/check-web-accessibility.sh" <mock dir>/<Dn>
```

Then run the browser pass on each mock (`file://`): `browser_snapshot`, a short Tab walk, and 320 px reflow. The five shipped directions pass the contrast pairs by construction; the plugin's tests keep it that way. D0 often fails; its failures are findings, shown next to it.

### Step 5 — Gallery

Take screenshots with `browser_take_screenshot` of each mock at 1280 wide and 320 wide, in light and dark (`browser_emulate_media` `colorScheme`). If `file://` is blocked, ask the operator to serve the mock directory on localhost (as in `ux-review` Step 4) and wait. Write one `gallery.html` in the mock directory, with every screenshot at a legible size (320 px shots at their natural width, 1280 px shots at least half size, each linking to the full image):
- the options side by side
- each with its name, "feels like" and fit
- the contrast summary and any check notes
- the font actually rendered

Give the operator the full path to open. If the session can publish a private page, offer to publish the gallery; never publish without the operator saying yes.

### Step 6 — More options

If none fits, ask what is missing in the operator's words ("warmer", "less corporate", "use our green #2e7d32", "like D4 but more compact"). Generate **D6, D7 and so on** as new token files in the mock directory, on the same schema as the catalog (every token in `directions/D1-clean-neutral.light.tokens.json`, in light and dark), with `frontend-design` guidance.
- Run Step 4 on each before showing it.
- When a brand color cannot pass as text on the surface, keep it for large accents, borders or fills that pass at 3:1, and use a darker or lighter shade for text. Say which shade and why.
- Add the new options to the gallery. Continue until the operator chooses, or stops.

### Step 7 — Decision and hand-off

When the operator chooses, show (never write):

1. **An ADR draft** (Context, Decision, Alternatives considered, Consequences, Cost implications) recording the direction, the options compared, the check results, the fonts and the trade-offs. It is for `adr_dir`.
2. **The token files** to add: the chosen direction's light and dark files, renamed for the project (for example `design/tokens/<slug>.light.tokens.json`), and the generated `tokens.css`.
3. **The contract change:** `ux.direction: <Dn>`, `ux.tokens: <path>`, `ux.themes: [light, dark]`, `ux.contrast_pairs: <path>`.
4. **For an existing project, a migration map:** each hard-coded value or old token (from `design-system-check` Step 2) and the new token that replaces it, grouped by file. This is input to the delivery loop, not an edit.

## What this skill does not do

- Apply the direction to the code. The delivery loop and the operator do that.
- Design logos, illustrations or brand identity.
- Show an option that failed the checks.
