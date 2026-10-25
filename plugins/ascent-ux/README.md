# ascent-ux

UX review for any web UI: WCAG 2.2 AA evidence, a design-system check, and a look-and-feel chooser with five accessible design directions. It makes the ASCENT ui-ux-designer role checkable in an existing repository ([ADR-012](../../docs/framework/DECISIONS/ADR-012-ux-plugin-design-directions-and-plugin-dependencies.md)).

```
/plugin marketplace add lloydbrian/lloydbriantech-ascent
/plugin install ascent-ux@lloydbriantech-ascent
```

Installing it also installs and enables its companions: `design` (Anthropic directory), `frontend-design` and `playwright` (claude-plugins-official). They can't be disabled while `ascent-ux` is enabled. `figma` and `design-skills` are used when present, and never required.

## What's inside

| Part | Kind | What it does |
|---|---|---|
| `ux-review` | skill, entry point | contract, UI map, five lenses, static checks, Playwright browser pass, maturity gaps; strong, moderate or weak |
| `accessibility-audit` | skill | every WCAG 2.2 A and AA criterion for the core flows, ARIA widgets against the APG, axe-core when the project has it |
| `design-system-check` | skill | token source, values that bypass tokens, contrast in every theme, theming, motion, component states |
| `design-directions` | skill | five predefined directions shown as checked mocks of the project's pages, more on request, ADR and token hand-off |
| `ux-reviewer` | agent, read-only | independent static review; a delivery-loop review lens for UI changes |
| `check-web-accessibility.sh` | script | U1–U12 static checks on HTML, JSX/TSX, Vue, Svelte, Astro, server templates and HTML inside JS/TS template literals (single-page-app views) |
| `check-token-contrast.sh` | script | exact WCAG contrast for token pairs, per theme, from Design Tokens JSON or CSS custom properties |
| `tokens-to-css.sh` | script | Design Tokens JSON to CSS custom properties, light and dark |
| `directions/` | data | D1 Clean neutral, D2 Bold brand, D3 Editorial, D4 Soft friendly, D5 Dense professional |
| `blueprints/accessible-page/` | blueprint | accessible page starter; the mock template |
| `references/` | references | WCAG 2.2 checklist, ARIA patterns, heuristics, tokens, performance UX, dated law map, manual checklist, contract template |

## Evidence, strongest first

1. **Browser pass** (Playwright): the live accessibility tree, a keyboard walk, focus screenshots, 320px reflow, reduced motion, dark mode and target sizes. It runs on `file://` or `localhost` only, never with real data.
2. **Scripts:** exact contrast; static markup checks, labelled "static" until the browser confirms them.
3. **Reading code:** the agent's view.

No report claims WCAG conformance. Every report ends with the manual keyboard and screen-reader checklist still to do.

## Maturity targets

| Item | Prototype | Standard | Enterprise (default) |
|---|---|---|---|
| Accessibility | semantic HTML; U1–U12 pass | WCAG 2.2 AA on core flows; a dated keyboard pass | WCAG 2.2 AA on every page in scope; dated keyboard **and** screen-reader passes; checks in CI |
| Design system | — | one token source; themes pass contrast | tokens plus documented components with states and accessibility notes |
| States and content | error states on core flows | empty, loading, error and success on core flows | every screen; UX copy reviewed |
| Performance UX | — | a page-weight budget | Core Web Vitals budgets, measured |
| Decisions | — | an ADR for the design-system choice | ADRs for the design system, the direction and every waiver |

## Tests

`make test-plugins` runs `tests/plugins/ascent-ux/`, on every awk installed:
- `test-check-web-accessibility.sh`: good fixtures in four syntaxes pass all 12 checks; one broken copy per check fails that check and no other
- `test-check-token-contrast.sh`: hand-checked ratios; every direction in both themes
- `test-tokens-to-css.sh`: value shapes; the blueprint has no drift
- `test-ux-rules.sh`: the skill rules

`make test-mutants` adds negative controls that must each make a named check fail.
