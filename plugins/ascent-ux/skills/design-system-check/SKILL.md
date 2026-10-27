---
name: design-system-check
description: >-
  Use when asked "check our design tokens", "are we using the design system?",
  "find hard-coded colors", "does dark mode pass contrast?", or when ux-review
  flags the design-system lens. Finds the token source, counts values that
  bypass it, checks theming through tokens and reduced motion, computes WCAG
  contrast for every token pair in every theme, and checks component states.
  Read-only.
version: 0.1.1
allowed-tools: Read, Grep, Glob
---

# design-system-check

The deep design-system check behind [ux-review](../ux-review/SKILL.md). It is a sibling that shares that skill's severity table, contract and evidence rules. It checks the ASCENT ui-ux-designer role's rules:
- one token set, applied everywhere
- themes are token values, not component variants
- motion comes from tokens and respects reduced motion
- every component specifies its states

Sources: [design-tokens.md](../../references/design-tokens.md) (Design Tokens Community Group format 2025.10, CSS custom properties, Tailwind), and the shipped [directions](../../directions/README.md) as worked examples of a complete token set.

`design:design-system` documents components and extends the system. Use it for that; this skill keeps the measurements, the contrast results and the severities. If the `figma` plugin is installed and the contract names a Figma file, compare its variables with the code's tokens. That's optional, and never required.

## Rules

- All `ux-review` rules apply: read-only; repository-relative `file:line` evidence; fresh evidence; severities only from the `ux-review` table; no personal data.
- **Contrast is computed, never estimated.** Only `check-token-contrast.sh` output counts. Without it, say "contrast not computed".
- **Count, then sample.** Report how many hard-coded values there are and in how many files, then cite the five worst files with lines. Never list hundreds of lines.

## Steps

### Step 1 — Token source

Find the source of truth, in this order:
1. `ux.tokens` in the contract
2. `*.tokens.json` files
3. a `:root` sheet of custom properties
4. `tailwind.config.*` theme values
5. SCSS or Less variables

Record the format, the themes (light, dark, brands) and how a theme is applied (`prefers-color-scheme`, `[data-theme]`, a class). No source at all is a Medium finding at the standard and enterprise targets.

### Step 2 — Values that bypass tokens

Search styles and templates for literal values outside the token files:
- colors (`#hex`, `rgb(`, `hsl(`, named colors)
- font sizes in `px` or `rem`
- spacing in `margin`, `padding` and `gap`
- radii and shadows
- inline `style=` attributes

Exclude the token files themselves, `0`, `1px` hairlines, `100%` and `currentColor`. Report the counts by kind and the five worst files. In core components the finding is Medium; elsewhere it is Low.

### Step 3 — Contrast for every theme

Run the contrast check with the contract's pairs, or with inferred pairs when there are none, and include the output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-token-contrast.sh" --pairs <ux.contrast_pairs> <token files or CSS>
```

`PLUGIN_ROOT` is two directories above this skill's base directory. Group the `FAIL` lines by foreground token: each failing foreground token is one Medium finding (1.4.3 for text, 1.4.11 for borders, icons and focus rings) that lists every background and theme it fails on, because one token change fixes it. A `SKIP` (translucent or unsupported color) is listed with "not computed". When pairs are inferred, propose a `contrast_pairs` file using the format of the shipped `directions/pairs.tsv`.

### Step 4 — Theming and motion

- **Theming through tokens:** themes change token values, not component markup. `<Button variant="dark">`, `.btn-dark` or per-component dark overrides are Low findings, as the role's anti-pattern.
- **Motion:** durations and easing come from tokens, and a `prefers-reduced-motion: reduce` rule removes or shortens animation (2.3.3, and 2.2.2 for anything that moves for more than 5 seconds).
- **Focus:** one `:focus-visible` style built from a focus-ring token (2.4.7). Removed outlines with no replacement are a finding (U11).

### Step 5 — Component states

For each shared component on a core flow, check that the styles and templates cover each state:
- default, hover, focus-visible, active and disabled
- loading, empty and error, where they apply
- selected or current (`aria-current`, `aria-selected`)

A core component with no visible focus or error state is Medium; other gaps are Low.

### Step 6 — Report

```
design-system-check: <token source or "none"> — <n> themes, <h> hard-coded values in <f> files, contrast <p> pass / <x> fail / <s> skipped
Findings: <ux-review X<n> blocks, most severe first>
Hard-coded values (Step 2): <counts by kind; five worst files with lines>
Contrast (Step 3): <script output, verbatim>
Theming and motion (Step 4): <one line each>
States (Step 5): <component | states present | missing>
Recommended next: <design-directions when there is no token source or the operator wants a new look>
```

## What this skill does not do

- Rewrite styles or migrate values to tokens. It proposes a migration map, and `design-directions` Step 7 produces one for a chosen direction.
- Judge taste. Whether a palette is pleasant is the operator's choice, informed by [design-directions](../design-directions/SKILL.md).
