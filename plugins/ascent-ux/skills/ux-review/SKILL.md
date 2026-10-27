---
name: ux-review
description: >-
  Use when asked "review the UX", "is this UI accessible?", "rate our
  accessibility against the contract", "WCAG 2.2 AA evidence", or before
  shipping a user-facing change. Rates a web UI against the project contract:
  maps pages, components and tokens, runs surface checks for accessibility,
  design system, usability, states and performance, runs the static checks and
  a Playwright browser pass, and reports strong, moderate or weak with WCAG
  evidence. For a quick design-level critique, design:accessibility-review fits.
version: 0.1.1
allowed-tools: Read, Grep, Glob
---

# ux-review

One review of a web UI, judged against the project's own targets. It is the entry point of the `ascent-ux` plugin. It runs surface checks itself and recommends [accessibility-audit](../accessibility-audit/SKILL.md), [design-system-check](../design-system-check/SKILL.md) or [design-directions](../design-directions/SKILL.md) only for the areas a surface check flags (the hybrid pattern). It never invokes them; they read the same sources.

It makes the ASCENT ui-ux-designer role checkable: one token set, theming through tokens, every state specified, and accessibility designed in, not retrofitted.

Shared sources:
- [wcag-22-checklist.md](../../references/wcag-22-checklist.md): every WCAG 2.2 A and AA criterion with what to look for
- [aria-patterns.md](../../references/aria-patterns.md)
- [usability-heuristics.md](../../references/usability-heuristics.md)
- [design-tokens.md](../../references/design-tokens.md)
- [performance-ux.md](../../references/performance-ux.md)
- [manual-test-checklist.md](../../references/manual-test-checklist.md)
- [accessibility-law-map.md](../../references/accessibility-law-map.md)
- [contract-template.yml](../../references/contract-template.yml): the `ux:` section of `.ascent/contract.yml`

The companion plugins are installed with this one: `design`, `frontend-design` and `playwright`. Use `design:accessibility-review`, `design:ux-copy` and `design:design-critique` for design-level advice and wording. This skill keeps the ASCENT parts: the contract, the severity table, the evidence rules, the browser pass and the report format (decision 5, extend don't duplicate).

## Rules

- **Read-only.** Never edit files, start servers, submit forms or deploy. The browser pass only reads pages (Step 4).
- **Evidence or it is not a finding.** Every finding cites a repository-relative `path/to/file:line` (never a bare file name or a directory) or "absent: searched <paths>", the WCAG 2.2 criterion or the heuristic it breaks, a concrete scenario (who cannot do what), and a fix.
- **Fresh evidence.** Re-read the evidence for every finding in this run. Never carry findings over from an earlier pass, an agent's report or another session.
- **Rate only with the severity table.** A concern that matches no row goes under **Other observations (unrated)** and does not count toward the rating. Never invent a severity.
- **Static until confirmed.** Findings from `check-web-accessibility.sh` or from reading code are marked "static" until the browser pass confirms them. A browser-pass result overrides a static one for the same element.
- **No conformance claims from automation.** Automated checks find only part of WCAG failures. The report never says "conforms to WCAG 2.2 AA". It says what was checked, what failed, and what the manual checklist must still cover.
- **Judge against the contract**, not against an ideal. A gap covered by a waiver ADR is Info, not a finding.
- **Never "met" without a target.** A lens or attribute whose target is missing from the contract is unmeasured, or at risk when the evidence shows a gap. Good evidence alone never makes it met.
- **Guessed core flows are labelled.** Until the operator confirms the contract, every severity that depends on a core flow (High for U3, U12 and the first severity row) carries "(core flow guessed)".
- **One contrast finding per failing foreground token**, listing every background and theme it fails on. The fix is one token change, so it is one finding.
- **Maturity gaps are always rated.** With no confirmed contract, rate them against the enterprise defaults (Step 5) and say so; never list them unrated.
- **No secrets, account ids or personal data** in the report, even when a finding is about one. Credentials in client code are `ascent-security`'s and `ascent-architecture`'s finding: cite the location, mark it `→ ascent-security`, and never print the value.
- **Security-only concerns** (authorization, CSP, cookie flags) go under Other observations marked `→ ascent-security`. Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`.
- **Dated sources.** The law map and the standards status carry `as_of`. If it is more than 90 days old, say "standards status as_of <date>: refresh due" in the report.
- **Not legal advice.** Name the jurisdictions the contract lists and the WCAG version each one references; never say a site is or is not legally compliant.
- **Scripts and data.** The plugin's read-only scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`. The directions are in `$PLUGIN_ROOT/directions/` and the blueprint in `$PLUGIN_ROOT/blueprints/accessible-page/`.

## Severity

Every finding carries one of these severities. The `ux-reviewer` agent uses the same table, and the scripts print the same severities.

<!-- ux-severity:start -->
| Finding | Severity |
|---|---|
| A keyboard or screen-reader user cannot complete a core task (keyboard trap 2.1.2, unreachable control 2.1.1, unnamed control 4.1.2 on a core flow) | High |
| Content that flashes more than three times a second (2.3.1) | High |
| Inaccessible authentication on a core flow: a cognitive test with no alternative (3.3.8) | High |
| Any other WCAG 2.2 Level A or AA failure on a page in scope | Medium |
| Text or UI contrast below the AA ratio in a shipped theme (1.4.3, 1.4.11) | Medium |
| No design-token source, or core components built from hard-coded values, at the standard or enterprise target | Medium |
| A core flow with no error, empty or loading state, or errors that do not say how to recover (3.3.1, 3.3.3) | Medium |
| A Core Web Vital in the "poor" band against a stated budget | Medium |
| A usability-heuristic violation on a core flow that breaks no WCAG criterion, with the heuristic named | Low |
| Hard-coded values outside tokens in non-core screens, or theming through component variants | Low |
| A ux target missing from the contract ("unmeasured") | Low |
| Any other item the maturity target requires, missing with no waiver (Step 5) | Low |
| A gap covered by a waiver ADR | Info |
<!-- ux-severity:end -->

**Rating:** **strong**: no High and no Medium. **moderate**: no High, one or more Medium. **weak**: one or more High.

## Steps

### Step 0 — Load or propose the contract

Read `.ascent/contract.yml`, or `.claude/contract.yml` where ASCENT-named files are not allowed, and use its `ux:` section.

If it is missing, **detect, don't ask.** Propose the section from what the repository declares:

- **Pages and frameworks:** `*.html`, `src/**/*.{jsx,tsx,vue,svelte,astro}`, the router files, and `package.json` dependencies (react, vue, svelte, astro, next, nuxt, tailwindcss).
- **Tokens:** `*.tokens.json`, `tokens.json`, `:root { --… }` sheets, `tailwind.config.*`, SCSS variable files.
- **Themes:** `prefers-color-scheme`, `[data-theme]`, `.dark`.
- **Personas and core flows:** `audience-mapping.md`, README, AGENTS.md, CLAUDE.md, the routes that take input (forms, sign-in, checkout, score entry).
- **Budgets:** Lighthouse CI config, performance notes in the docs.

Use only the keys and values of [contract-template.yml](../../references/contract-template.yml):
- `maturity_target` is one of enterprise, standard or prototype (never a new value)
- `conformance` is one of wcag-2.2-aa, wcag-2.1-aa or wcag-2.2-aa-plus
- each waiver is an `id`, `skips` and `review_by`
- mark detected values with their source (`# detected: <path:line>`) and guesses with `# guess`

Show the proposal once and ask the operator to confirm it. Write nothing: the operator commits the file. Until it is confirmed, review against the enterprise defaults and WCAG 2.2 AA, and say so in the report.

### Step 1 — Map the UI

Build the inventory from the repository, not from memory:

| Surface | Kind | Where defined | Core flow? | Token source | Themes |
|---|---|---|---|---|---|

List the pages or routes, layouts, shared components (header, nav, forms, dialogs, tables), the style and token sources, and the third-party UI kits. Name the core flows from the contract, or the input-taking routes when there is no contract. Mark components that hard-code styles.

### Step 2 — Surface checks (five lenses)

One line per lens: what the contract asks, the evidence found, and the status **met**, **at risk** or **unmeasured**. A lens whose target is missing from the contract is unmeasured, never met; it is at risk instead when the evidence shows a gap. Report these five lenses, in this order, and no others:

- **Accessibility:** landmarks, headings, labels, names, focus, keyboard reachability, alternative text, captions, status messages, target size (2.5.8, 24 by 24 px), reflow (1.4.10).
- **Design system:** one token source, hard-coded colors and spacing, theming through tokens, motion tokens with a `prefers-reduced-motion` path.
- **Usability heuristics:** Nielsen's 10 on the core flows ([usability-heuristics.md](../../references/usability-heuristics.md)). A heuristic concern that breaks a WCAG criterion is rated under that criterion; otherwise it is a Low finding on a core flow, or an unrated observation elsewhere.
- **States and content:** empty, loading, error and success for each core flow; errors that say how to fix (3.3.1, 3.3.3); labels and instructions (3.3.2); redundant entry (3.3.7); consistent help (3.2.6); plain wording (use `design:ux-copy` when it helps).
- **Performance UX:** contract budgets with Lighthouse or field data only ([performance-ux.md](../../references/performance-ux.md)). Without evidence, one line: "Core Web Vitals unmeasured".

Two or more lenses at risk or unmeasured: recommend [accessibility-audit](../accessibility-audit/SKILL.md) or [design-system-check](../design-system-check/SKILL.md) for the lens concerned.

### Step 3 — Mechanical checks

Run both scripts and include their output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-web-accessibility.sh" --core <core-flow file> <pages or src directory>
bash "$PLUGIN_ROOT/scripts/check-token-contrast.sh" [--pairs <contract contrast_pairs>] <token files or CSS>
```

- Pass `--core` once for each file of a core flow, so U3 and U12 failures there are High.
- Each static `FAIL` line is a finding with the severity it prints, marked "static".
- Each `NOTE` line is unrated: list it under Other observations and settle it in the browser pass (an `<h1>` rendered by a script, a box-shadow focus ring whose contrast is not computed).
- Contrast `FAIL` lines are Medium findings (1.4.3 or 1.4.11). Pairs marked "inferred" came from CSS rules or token names; say so.
- If Bash is unavailable or the operator declines it, apply U1–U12 by reading the markup and say "checks applied by reading; scripts not run". Never estimate a contrast ratio by eye: say "contrast not computed".

### Step 4 — Browser pass (authoritative)

When the Playwright tools (`mcp__plugin_playwright_playwright__*`) are available, the browser pass is **not optional**. Check the core flows in a real browser:

- **Where:** only `file://` pages or a `localhost` server, or a URL the operator names. Some Playwright setups block `file://`; then, and whenever the app needs a dev server, ask the operator to start one and **wait for their answer** before writing the report. Give the exact command: `make up`, the project's dev command, or for static files `python3 -m http.server 8000 --bind 127.0.0.1` in the site folder. Never start it yourself.
- **"Not run" needs a concrete reason:** the Playwright tools are missing, the operator declined, or the operator did not start the server. Anything else is a skipped step, not a reason.
- **Never** submit forms with real data, sign in with real credentials, or follow links off the site.
- **Accessibility tree:** `browser_snapshot` on each core page. Every interactive element has a role and a name (4.1.2), and headings and landmarks match the static map (1.3.1).
- **Keyboard walk:** `browser_press_key` Tab through each core flow from the top. Record the focus order (2.4.3), confirm nothing traps focus (2.1.2), confirm every control is reached (2.1.1), and confirm Escape closes dialogs.
- **Focus visible:** `browser_take_screenshot` at each focus stop. The indicator is visible (2.4.7) and not hidden under sticky content (2.4.11).
- **Reflow and zoom:** `browser_resize` to 320 by 800 with no horizontal scrolling (1.4.10). At 1280 wide with text zoomed to 200%, nothing is lost (1.4.4).
- **Preferences:** `browser_emulate_media` with `reducedMotion: reduce` (2.3.3), and `colorScheme: dark` for every shipped theme. Contrast is still checked by the script, not by eye.
- **Target size:** `browser_evaluate` reads the bounding boxes of interactive elements. Each is at least 24 by 24 CSS px, or has the spacing exception (2.5.8).
- **axe-core:** only when `node_modules/axe-core/axe.min.js` already exists. Inject it with `browser_evaluate`, run `axe.run()` with the `wcag2a`, `wcag2aa`, `wcag21aa` and `wcag22aa` tags, and report violations with their WCAG criterion. Never install it.

Without Playwright, say "browser pass not run: <reason>". Every finding then stays "static", and the rating carries "(static only)".

After the pass, run `git status` in the reviewed repository. The Playwright server may write snapshots to `.playwright-mcp/` in its working directory. If that folder appeared, tell the operator and suggest adding it to `.gitignore`. Never delete files in the reviewed repository yourself.

### Step 5 — Maturity gaps

Compare what you found with the `maturity_target` row by row, using the maturity table in the plugin [README](../../README.md#maturity-targets). Each missing item is a finding at the severity the table gives it, unless a waiver ADR in `ux.waivers` covers it. Then it is listed as **Info: waived by ADR-NNN**, and the ADR is checked to exist in `adr_dir`. A waiver that points at a missing ADR is a Low finding.

### Step 6 — Report

The counts and the rating cover rated findings only. Every rated finding gets the full `X<n>` block, Low ones included: no condensed lists.

```
ux-review: <strong | moderate | weak> [(static only)] — <H> High, <M> Medium, <L> Low, <I> Info
Contract: <path, or "none — enterprise defaults, WCAG 2.2 AA (proposal shown in Step 0)">
Maturity target: <target>   Conformance target: <target>   Direction: <Dn or none>

UI map (Step 1): <inventory table>
Lenses (Step 2): <one line per lens: target | evidence | status (met only when the contract sets a target)>

Findings, most severe first:
X<n>  <severity>  <file>:<line or "absent: searched …">  [static | browser] [(core flow guessed)]
      Criterion: <e.g. 2.4.7 Focus Visible (AA)> or Heuristic: <name>
      Scenario: <who cannot do what>
      Fix: <smallest change that closes it>

Other observations (unrated):
O<n>  <file>:<line>  <concern>  [→ ascent-security]

Mechanical checks (Step 3): <both scripts' output, verbatim>
Browser pass (Step 4): <what ran, per flow, or "not run: <reason>">
Manual checklist: <the keyboard and screen-reader items from manual-test-checklist.md still to do, with "record the date in ux.manual_tests">
Recommended next: <only the deeper skills whose surface checks flagged something, with the reason; ascent-security when any item is marked → ascent-security>
```

## What this skill does not do

- Change code, styles or tokens. Fixes go through the delivery loop (`ascent-delivery`) and the operator's runbook.
- Certify conformance or write a VPAT or Accessibility Conformance Report. It gathers the evidence one would need.
- Replace testing with real assistive-technology users or user research (`design:user-research`).
- Rate security or architecture: use `ascent-security` and `ascent-architecture`.
