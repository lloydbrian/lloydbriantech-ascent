# ADR-012: UX plugin, design directions and plugin dependencies

**Status:** Accepted (2026-10-25, after the read-only trial and re-trial of U-H)
**Date:** 2026-10-24 (America/New_York)
**Decider:** lloydbriantech

## Context

`ascent-ux` is rank 2 of the plugin roadmap (decisions 2026-10-18, order confirmed 2026-10-24). ASCENT already defines the ui-ux-designer role in `skills/lloydbriantech-ascent/references/role-ui-ux-designer.md`: the design system, tokens, theming, layouts, visual specs, interaction states and accessibility-as-design. No plugin makes that role checkable in an existing repository, and no plugin helps a builder choose a look and feel before the first screen is built.

The standards to judge against, as of 2026-10-24:

- WCAG 2.2, also ISO/IEC 40500:2025. WCAG 3 is a W3C Working Draft (March 2026).
- WAI-ARIA 1.2 and the ARIA Authoring Practices Guide.
- Legal context: the ADA Title II rule (WCAG 2.1 AA; DOJ extended the compliance dates to April 2027 and April 2028), Section 508 (WCAG 2.0 AA), and the European Accessibility Act through EN 301 549. Version 3.2.1 is in force; v4.1.1 adopts WCAG 2.2 AA and awaits citation.
- Nielsen's 10 usability heuristics, ISO 9241-110:2020 and ISO 9241-11.
- The Design Tokens Community Group format 2025.10, the first stable version. It is a Community Group report, not a W3C Standard.
- Core Web Vitals.

The architecture trial (ADR-011, decision E) showed which rules a review plugin needs from day one: severities only from the table, exact evidence, valid contract values, fresh evidence, security referrals, and a search for secrets in client code.

## Decision

1. **A hand-written plugin, `ascent-ux` 0.1.0** (U-G, as ADR-011 decision B). There are four sibling skills, and the hybrid pattern applies: the entry skill recommends deeper skills only where a surface check flags something.
   - `ux-review`: the entry point and the rating. It loads or proposes the contract, maps the UI, runs surface checks over five lenses (accessibility, design system, usability heuristics, states and content, performance UX), runs the scripts and the browser pass, checks maturity gaps, and reports strong, moderate or weak.
   - `accessibility-audit`: criterion by criterion against WCAG 2.2 A and AA for the core flows, plus ARIA pattern conformance.
   - `design-system-check`: the token source, hard-coded values, theming through tokens, and contrast for every theme.
   - `design-directions`: chooses a look and feel (U-J). Details are in decision 7.

   Usability heuristics are a lens inside `ux-review` in 0.1.0 (R1). Heuristic concerns that don't break a WCAG criterion go under unrated observations. A full heuristics skill waits for trial evidence.
2. **Scope is web UIs** (U-A): HTML, CSS, and JS or TS templates (React, Vue, Svelte, Astro, Eta). Native mobile is out of 0.1.0.
3. **The default conformance target is WCAG 2.2 Level AA** (U-B) at every maturity level. AAA is opt-in per criterion. The legal map is informational, dated (`as_of`), and says it is not legal advice (R4).
4. **Evidence is ranked** (U-C, R2).
   - **The browser pass is authoritative.** Through the Playwright MCP server it reads the live accessibility tree, walks the core flow with the keyboard, takes a screenshot per focus stop, reflows at 320 px, emulates reduced motion and dark mode, and measures target sizes. It runs axe-core only when the project already has `axe-core` installed. It opens only `file://` and `localhost` pages, or a URL the operator names. It never submits real data and never signs in with real credentials. The operator starts any dev server.
   - **The static checks** in `scripts/check-web-accessibility.sh` (U1–U12) are a pre-flight and a fallback. Their findings are labelled "static" until the browser pass confirms them.
   - `scripts/check-token-contrast.sh` computes WCAG contrast ratios exactly from color tokens. It reads CSS custom properties or Design Tokens JSON, and infers pairs from CSS rules when no pair file exists, labelled "inferred" (R5).
5. **Honest limits** (U-D). A report never claims conformance from automated checks. Every report carries a dated manual checklist: a keyboard pass and a screen-reader pass.
6. **Companion plugins are dependencies** (U-E, R3). `plugin.json` declares `design` (anthropic-plugin-directory), `frontend-design` and `playwright` (claude-plugins-official). The marketplace allowlists both marketplaces in `allowCrossMarketplaceDependenciesOn`, and `make test-plugins` T12 fails when a cross-marketplace dependency is not allowlisted.
   - A spike in an isolated config (2026-10-24) confirmed three things: installing installs and enables all three; a dependency cannot be disabled while `ascent-ux` is enabled; and without the allowlist, `ascent-ux` fails to load.
   - Skill descriptions route explicitly. `ascent-ux` rates against the project contract and gathers conformance evidence; `design:accessibility-review` is a quick design-level audit that `accessibility-audit` may call as a sub-step.
   - `figma` and `design-skills` are optional, detected and never required.
7. **Design directions** (U-J). There are five predefined directions, each a Design Tokens 2025.10 file with light and dark themes:
   - D1 Clean neutral
   - D2 Bold brand
   - D3 Editorial
   - D4 Soft friendly
   - D5 Dense professional

   `design-directions` renders the project's own pages with each direction's tokens through the accessible page blueprint (U-I), alongside "D0 — current" for an existing project. Every option is checked before it is shown: contrast, the static checks on the mock, and the browser pass. The skill builds a side-by-side gallery from Playwright screenshots at desktop and 320 px, in light and dark.

   When none of the five satisfies, the skill generates D6, D7 and so on from the operator's direction, with `frontend-design` guidance, and they pass the same checks. The choice ends in an ADR draft, a proposed token file, `ux.direction` for the contract, and, for an existing project, a migration map. Mocks are the only files the plugin writes. They go to the session scratchpad or a gitignored `tmp/ux-mocks/`, never into tracked files.
8. **The project contract** (U-F): a `ux:` section in `.ascent/contract.yml` (or `.claude/contract.yml`). It holds the maturity target, conformance, jurisdictions, personas, core flows, pages, tokens, themes, contrast pairs, browsers, viewports, the performance budget, manual tests, direction, the ADR directory and waivers. New projects get it from the scaffolder; existing projects get it proposed (detect, don't ask).
9. **Core Web Vitals only with evidence** (R8): contract budgets plus Lighthouse or field data when present. Otherwise one Low "unmeasured" line.
10. **Single source** (R7). The plugin is the source. The ui-ux-designer role reference links to it instead of repeating it, and the Phase 4 scaffolder installs the plugin rather than copying its skills.
11. **Trial** (U-H): read-only on `homelab-docs` (about 150 static HTML pages) and `ground-turf-truth` (an ASCENT-scaffolded vanilla-JS MVC app), each run in a fresh conversation. Framework syntax (JSX, Vue, Svelte) is covered by test fixtures until a framework repository is trialled (R6). The trial (2026-10-24, five runs) led to one calibration round before release: the static checker reads HTML in JS template literals and judges outline removal per selector; the blueprint's tables scroll in a labelled region at 320 px; the browser pass is mandatory when Playwright is present; guessed core flows are labelled; contrast findings group by token; and the agent never rates estimated contrast. A re-trial on `ground-turf-truth` (2026-10-25) led to a second round: the scripts run awk with `LC_ALL=C` (line numbers were wrong after non-ASCII text), U12 follows delegated click listeners, and unrated NOTE lines cover an `<h1>` rendered by script and a box-shadow focus ring.

## Alternatives considered

- **Usability heuristics as a fourth review skill.** Deferred (R1): it is mostly judgment, hard to test, and the architecture trial found most defects in the entry skill. `design-directions` takes the slot because its core is testable: fixed token files and deterministic contrast.
- **A separate `.ux.yml`.** Rejected (U-F): it repeats shared values (`maturity_target`, `adr_dir`, personas) across files, and the scaffolder would write one file per plugin. Each plugin already owns only its own section of the contract.
- **Require Playwright with axe-core as npm packages.** Rejected (U-C): it adds a project dependency and fails without a browser. The Playwright plugin's MCP server needs nothing in the project.
- **Bundle our own pinned `.mcp.json` for Playwright.** More reproducible, but it starts a second browser next to the one the operator already uses. Deferred: see Consequences.
- **Optional companion plugins, detected only.** Safer for context size, but it leaves the default experience incomplete. This remains the fallback if routing between `design:accessibility-review` and `accessibility-audit` proves ambiguous in the trial.
- **Free-form mock designs without token sets.** Rejected: free-form mocks can't be checked for contrast or carried into the repository. Tokens make every direction verifiable and portable.

## Consequences

- Builders get a rated UX review with WCAG evidence, a design-system check, and a way to choose a look and feel with every option already accessible.
- Installing `ascent-ux` adds three plugins to every session. The context cost and trigger overlap are accepted, and they are checked in the trial.
- The Playwright plugin runs `@playwright/mcp@latest`, which is not pinned. ASCENT pins exact versions elsewhere. This is accepted as a known risk; `ascent-ops` revisits pinning.
- The operator's `design` plugin may be the claude.ai-synced copy. Resolved in the beta install (2026-10-24): the dependency installed `design@anthropic-plugin-directory`, and Claude Code reports that the synced copy "is not loaded" because the local one has the same name and takes precedence. Only one copy is active.
- Routing between `ascent-ux:accessibility-audit` and `design:accessibility-review` held in the trial: the plain request "audit the accessibility of this site" ran `ascent-ux:accessibility-audit`.
- Some Playwright setups block `file://`, and the Playwright server writes snapshots to `.playwright-mcp/` in its working directory. The skills ask the operator to serve static files on localhost when `file://` is blocked, and report any `.playwright-mcp/` folder rather than deleting it.
- The static checks read markup with bash and awk. They are reliable for HTML and common template syntax, not for markup built at runtime, which is why the browser pass is authoritative.
- The legal map and the standards status go stale. Both carry `as_of`, and the skill asks for a refresh after 90 days.
- The trial (U-H, 2026-10-24) ran the skills and the agent five times on two real repositories, and a re-trial (2026-10-25) checked the first calibration. They found gaps in the static checker and in the skill rules, not in the design: single-page-app views were invisible, one `:focus-visible` rule excused every outline removal, line numbers drifted after non-ASCII text, delegated click handlers were missed, and the browser pass could be skipped without a reason. Two calibration rounds fixed them before release, each pinned by rule tests and negative controls (P94–P117).
- `make test-mutants` grows by 56 controls (P62–P117), to 183 in total; the macOS gate takes 18m39s of its 25-minute timeout. To keep CI inside its timeout, a control that edits one plugin's files runs T11 for that plugin only (`ASCENT_T11_ONLY`). Running fewer tests can only make a control harder to kill, never easier; the baseline control and the real gate still run every plugin's tests.

## Cost implications

- About 1,800 lines of plugin (four skills, an agent, eight references, three scripts with a shared parser, five direction token files and a blueprint) and about 600 lines of tests, plus 56 negative controls (P62–P117) and a new gate check, T12.
- Recurring: refresh the legal map and the standards status every 90 days, and review the direction token files when WCAG or the tokens format changes.
- Runtime: the browser pass needs Node.js for the Playwright MCP server, which the `playwright` plugin already requires.
