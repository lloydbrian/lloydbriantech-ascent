# ascent-ux

UX review for any web UI on four principles: functional (users can finish the core flows), reliable (the flows survive a failed request, a double click, a reload or a lost connection), accessible (WCAG 2.2 AA evidence and a design-system check) and pleasant (observed, never met), plus a look-and-feel chooser with five accessible design directions. It makes the ASCENT ui-ux-designer role checkable in an existing repository ([ADR-012](../../docs/framework/DECISIONS/ADR-012-ux-plugin-design-directions-and-plugin-dependencies.md), [ADR-022](../../docs/framework/DECISIONS/ADR-022-ux-principles-flow-integrity-and-reliability.md)).

```
/plugin marketplace add lloydbrian/lloydbriantech-ascent
/plugin install ascent-ux@lloydbriantech-ascent
```

Installing it also installs and enables its companions: `design` (Anthropic directory), `frontend-design` and `playwright` (claude-plugins-official). They can't be disabled while `ascent-ux` is enabled. `figma` and `design-skills` are used when present, and never required.

## What's inside

| Part | Kind | What it does |
|---|---|---|
| `ux-review` | skill, entry point | contract, UI map, four principles over seven lenses, static checks, Playwright browser pass with a walk of each core flow, maturity gaps; strong, moderate or weak |
| `flow-check` | skill | the functional and reliable principles: flow-integrity and reliability checks with the contract's values, a browser walk of each core flow, the same flows in every listed engine the operator runs |
| `accessibility-audit` | skill | every WCAG 2.2 A and AA criterion for the core flows, ARIA widgets against the APG, axe-core when the project has it |
| `design-system-check` | skill | token source, values that bypass tokens, contrast in every theme, theming, motion, component states |
| `design-directions` | skill | five predefined directions shown as checked mocks of the project's pages, more on request, ADR and token hand-off |
| `ux-reviewer` | agent, read-only | independent static review; a delivery-loop review lens for UI changes |
| `check-web-accessibility.sh` | script | UX-U1–U12 static checks on HTML, JSX/TSX, Vue, Svelte, Astro, server templates and HTML inside JS/TS template literals (single-page-app views) |
| `check-flow-integrity.sh` | script | UX-F1–F4 and F7 static checks: links, form actions, router links and navigation calls resolve to a file or route (React Router, Vue Router, file-based routes in pages/, app/ and SvelteKit); in-page and ARIA targets exist; core-flow steps have a way forward and a way out; a not-found route exists; build targets match the contract's browsers |
| `check-ux-resilience.sh` | script | UX-R1–R7 and UX-P1–P4 static checks: scripted submits are guarded, failed requests (fetch, axios, React Query, SWR) are shown and can be retried, long core forms keep a draft, listed view state is in the URL, an offline notice when required, optimistic updates roll back, progress feedback, motion through tokens, no pre-checked consent, a way to cancel after sign-up |
| `check-token-contrast.sh` | script | exact WCAG contrast for token pairs, per theme, from Design Tokens JSON or CSS custom properties |
| `tokens-to-css.sh` | script | Design Tokens JSON to CSS custom properties, light and dark |
| `directions/` | data | UX-D1 Clean neutral, UX-D2 Bold brand, UX-D3 Editorial, UX-D4 Soft friendly, UX-D5 Dense professional |
| `blueprints/accessible-page/` | blueprint | accessible page starter; the mock template |
| `references/` | references | WCAG 2.2 checklist, ARIA patterns, heuristics, flow integrity and reliability rules (UX-F, UX-R, UX-P), tokens, performance UX, dated law map, manual checklist, contract template |

## Evidence, strongest first

1. **Browser pass** (Playwright): the live accessibility tree, a keyboard walk, focus screenshots, 320px reflow, reduced motion, dark mode and target sizes. It runs on `file://`, `localhost` or, for navigation only, a URL the operator names, never with real data; it submits a form only with the operator's `test_data` fixture on `localhost`.
2. **Scripts:** exact contrast; static markup checks, labelled "static" until the browser confirms them.
3. **Reading code:** the agent's view.

No report claims WCAG conformance. Every report ends with the manual keyboard and screen-reader checklist still to do.

## Other engines

The `playwright` companion runs Chromium. For UX-F6, `flow-check` asks the operator to add one more Playwright server per engine in `ux.engines`, beside the companion (Firefox and WebKit have not been trialled yet, so report what goes wrong):

```bash
npx playwright install firefox webkit
claude mcp add --scope local playwright-firefox -- npx @playwright/mcp@latest --browser firefox
claude mcp add --scope local playwright-webkit -- npx @playwright/mcp@latest --browser webkit
```

Restart Claude Code after adding one; its tools are `mcp__playwright-firefox__*` (or `-webkit`). WebKit is Safari's engine, not Safari. Remove them afterwards with `claude mcp remove playwright-firefox` and `claude mcp remove playwright-webkit`; the companion server is never changed.

## Maturity targets

| Item | Prototype | Standard | Enterprise (default) |
|---|---|---|---|
| Flow integrity | UX-F1, UX-F2 pass | UX-F1–F4 pass; core-flow steps in the contract; one engine walked | UX-F1–F7 pass; every listed engine walked |
| Reliability | — | UX-R1, UX-R2 on core flows | UX-R1–R7 on core flows (UX-R6 when offline is required) |
| Accessibility | semantic HTML; UX-U1–U12 pass | WCAG 2.2 AA on core flows; a dated keyboard pass | WCAG 2.2 AA on every page in scope; dated keyboard **and** screen-reader passes; checks in CI |
| Design system | — | one token source; themes pass contrast | tokens plus documented components with states and accessibility notes |
| States and content | error states on core flows | empty, loading, error and success on core flows | every screen; UX copy reviewed |
| Performance UX | — | a page-weight budget | Core Web Vitals budgets, measured |
| Decisions | — | an ADR for the design-system choice | ADRs for the design system, the direction and every waiver |
| Pleasantness | — | — | UX-P1–P4 observed; UX copy reviewed |

## Tests

`make test-plugins` runs `tests/plugins/ascent-ux/`, on every awk installed:
- `test-check-web-accessibility.sh`: good fixtures in four syntaxes pass all 12 checks; one broken copy per check fails that check and no other
- `test-check-flow-integrity.sh`: good fixtures in four syntaxes (HTML, React Router, Vue Router, SvelteKit) pass UX-F1–F4 and F7; one broken copy per rule fails that rule and no other
- `test-check-ux-resilience.sh`: good fixtures (plain JS, React with React Query and axios, Vue) pass UX-R1–R7 and UX-P1–P4; one broken copy per rule fails that rule and no other
- `test-check-token-contrast.sh`: hand-checked ratios; every direction in both themes
- `test-tokens-to-css.sh`: value shapes; the blueprint has no drift
- `test-ux-rules.sh`: the skill rules

`make test-mutants` adds negative controls that must each make a named check fail.
