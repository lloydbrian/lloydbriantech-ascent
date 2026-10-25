---
name: accessibility-audit
description: >-
  Use when asked for a "WCAG 2.2 audit", "criterion by criterion accessibility",
  "keyboard and screen reader audit", or when ux-review flags the accessibility
  lens. Walks every WCAG 2.2 Level A and AA criterion for the core flows,
  checks ARIA widgets against the Authoring Practices, runs the static checks,
  the Playwright browser pass and axe-core when the project has it, and
  returns a criterion table with evidence. Read-only.
version: 0.1.0
allowed-tools: Read, Grep, Glob
---

# accessibility-audit

The deep accessibility check behind [ux-review](../ux-review/SKILL.md). It is a sibling that shares that skill's severity table, contract and evidence rules. Where `ux-review` samples, this skill goes criterion by criterion over the core flows and produces the evidence an accessibility conformance report would need. It never claims conformance itself.

Sources: [wcag-22-checklist.md](../../references/wcag-22-checklist.md) (all 55 Level A and AA criteria of WCAG 2.2, with 4.1.1 Parsing removed), [aria-patterns.md](../../references/aria-patterns.md) and [manual-test-checklist.md](../../references/manual-test-checklist.md).

`design:accessibility-review` gives a quick design-level pass with fix suggestions. Use it for wording and design remedies; this skill keeps the criterion table, the evidence and the severities.

## Rules

- All `ux-review` rules apply: read-only; repository-relative `file:line` evidence with the criterion; fresh evidence; severities only from the `ux-review` table; static until the browser confirms; no conformance claims; no personal data; not legal advice.
- **Every criterion gets one status:** `pass`, `fail`, `not tested` (what would test it) or `N/A` (why: for example "no video on these pages" for 1.2.x). Never leave a row blank, and never mark a row pass on static evidence alone when the checklist says it needs the browser or a person.
- **ARIA is checked against the APG pattern**, not against intuition. The first rule of ARIA applies: a native element beats a role. A widget that uses `role="menu"` for site navigation fails the pattern; say why.

## Steps

### Step 1 — Scope

From the contract (`ux.core_flows`, `ux.pages`, `ux.conformance`), or the `ux-review` Step 0 proposal, list the pages and flows in scope, the conformance target and the shipped themes. Name any AAA criteria the contract opts into (`wcag-2.2-aa-plus`).

### Step 2 — Static checks

Run the checker over the scope, with `--core` for each core-flow file, and include the output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-web-accessibility.sh" --core <core-flow file> <scope>
```

`PLUGIN_ROOT` is two directories above this skill's base directory. Map each U-check to its criterion in the table. Static results feed the criterion rows; they are not the audit. A `NOTE` line is never a pass: its criterion stays `not tested` until the browser pass settles it.

### Step 3 — Criterion walk

Go through [wcag-22-checklist.md](../../references/wcag-22-checklist.md) in order (perceivable, operable, understandable, robust). For each criterion, read the code it names: templates, CSS, event handlers, form validation, live regions and media. Record the status and the evidence. Give the six criteria new at Level A and AA in WCAG 2.2 extra attention, because older templates miss them:
- 2.4.11 Focus Not Obscured (Minimum)
- 2.5.7 Dragging Movements
- 2.5.8 Target Size (Minimum)
- 3.2.6 Consistent Help
- 3.3.7 Redundant Entry
- 3.3.8 Accessible Authentication (Minimum)

### Step 4 — Widgets

List the interactive widgets on the core flows (dialogs, menus, tabs, accordions, comboboxes, toasts, carousels). For each one, compare roles, states and the keyboard model with [aria-patterns.md](../../references/aria-patterns.md), and record every difference with its criterion (usually 4.1.2, 2.1.1 or 2.4.3).

### Step 5 — Browser pass

Run the `ux-review` Step 4 browser pass for each core flow, with the same rules:
- `file://` or `localhost` only
- no real data
- the operator starts any server

Add one widget-level walk per widget from Step 4: open it, operate it, close it, and confirm focus returns to the trigger. Run axe-core only if `node_modules/axe-core` exists. Browser results replace static results for the same element.

### Step 6 — Report

```
accessibility-audit: <n> criteria — <p> pass, <f> fail, <t> not tested, <a> N/A   [(static only)]
Scope: <pages and flows>   Target: <conformance>   Themes: <list>

| Criterion | Level | Status | Evidence | Severity |
|---|---|---|---|---|
| 1.1.1 Non-text Content | A | fail | src/views/home.html:42 [browser] | Medium |
…

Findings: <each fail as a ux-review X<n> block, most severe first>
Widgets (Step 4): <widget | pattern | differences>
Not tested: <criterion, and the manual step or tool that would test it>
Manual checklist: <keyboard pass and screen-reader pass items still to do; record the date in ux.manual_tests>
```

## What this skill does not do

- Fix anything, or produce a VPAT or ACR on its own.
- Test with assistive-technology users. The manual checklist is the minimum, not a substitute.
- Rate the design system or the look: use [design-system-check](../design-system-check/SKILL.md) and [design-directions](../design-directions/SKILL.md).
