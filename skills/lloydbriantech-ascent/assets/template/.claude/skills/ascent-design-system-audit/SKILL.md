---
name: ascent-design-system-audit
description: >-
  Validates design-system token consistency and hardcoded-value detection
  for <<PROJECT_TITLE>>. Detects whether a design system is present
  before auditing. No-ops gracefully on plain-CSS projects.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
---

# ascent-design-system-audit

Validates design-system discipline: token consistency (custom properties defined vs used) and hardcoded-value detection (inline colors, fonts, or spacing that bypass the token system). The skill detects whether a design system is present before auditing — projects with plain CSS and no custom properties get a clean no-op exit.

This skill is conditional — the Phase 4 scaffolder will gate its inclusion based on project type. Until then, it ships in all scaffolded projects and exits gracefully when its subsystem is absent.

## When this skill engages

- After modifying design tokens, theme files, or component styles
- When a developer asks "is the design system consistent?"
- As a periodic check (recommended: per-design-change)
- NOT for design review or visual QA — this skill checks structural token discipline

## Inputs

- **`frontend/src/` CSS/SCSS files** — scanned for `:root` custom properties and usage
- **`tokens.css`, `design-tokens.json`, `theme/`, `tokens/`** — design token source files
- **`frontend/src/` component files** — scanned for hardcoded values that bypass tokens

## Outputs

- **Per-check report** — each check marked PASS, CONCERN, or SKIP
- **Summary line** — "design-system-audit: N/3 checks passing" or "design-system-audit: no design system detected (no-op)"

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Detect design system

**Action:** Scan for design-system markers:
- CSS files with `:root` blocks containing `--` custom properties
- `tokens.css`, `design-tokens.json`, `design-tokens.yml` files
- `theme/` or `tokens/` directories

**Action on detected:** Proceed to audit. Report: "Design system detected: [marker type] at [location]."

**Action on not detected:** Report "design-system-audit: no design system detected — this skill is a no-op for the current project state." Exit zero.

### Step 2 — Token consistency

**Condition:** Design system detected.

**Action:** Extract all custom properties defined in `:root` blocks (e.g., `--color-primary`, `--font-size-base`). Extract all `var(--*)` usages across CSS files. Compare:
- Defined but never used → unused token (informational)
- Used but never defined → undefined reference (concern)

**Action on PASS:** Report "Token consistency — PASS. [N] tokens defined, all referenced tokens resolve."

**Action on CONCERN:** List undefined references. "Token consistency — CONCERN. `var(--color-accent)` used in App.css but not defined in any `:root` block."

### Step 3 — Hardcoded value detection

**Condition:** Design system detected.

**Action:** Scan CSS files for hardcoded color values (`#hex`, `rgb()`, `hsl()`), font-family declarations, and fixed spacing values that bypass the token system. Exclude `:root` blocks (where tokens are defined) and CSS reset/normalize files.

**Action on PASS:** Report "Hardcoded values — PASS. No inline values bypassing the token system."

**Action on CONCERN:** List findings. "Hardcoded values — CONCERN. frontend/src/App.css:12 uses `color: #ff0000` — should use `var(--color-primary)` or equivalent token."

### Step 4 — Aggregate and report

**Action:** Collect results. Report summary.

## Examples

### Example 1 — Design system with violations

```
design-system-audit: 2/3 checks passing (1 concern)
  Design system detected  PASS (`:root` tokens in App.css)
  Token consistency       PASS (8 tokens, all resolve)
  Hardcoded values        CONCERN — 3 inline color values bypassing tokens
```

### Example 2 — No design system (plain CSS)

```
design-system-audit: no design system detected — this skill is a no-op for the current project state.
```

## Anti-patterns

### Anti-pattern 1 — Hardcoding "just this once"

Adding `color: #333` instead of `var(--color-text)` because "it's just one component." **Why it's tempting:** the token system feels heavy for a small change. **What to do instead:** every hardcoded value is a maintenance liability. When the token changes, the hardcoded value doesn't — and the inconsistency is invisible until a user notices.
