# Design tokens

Design tokens are the single source of the ASCENT ui-ux-designer role: colors, type, spacing, radius, motion. Components consume tokens; screens compose components; themes are different token values.

## The format: Design Tokens Community Group 2025.10

The Design Tokens Format Module 2025.10 (<https://www.designtokens.org/>) is the first stable version, published 28 October 2025 as a W3C Community Group final report. It is not a W3C Standard, but tools cite it by date and its core is stable for production.

```json
{
  "color": {
    "$type": "color",
    "text": {
      "primary": { "$value": { "colorSpace": "srgb", "components": [0.122, 0.137, 0.157], "hex": "#1f2328" } }
    },
    "link": { "$value": "{color.text.primary}" }
  },
  "space": { "$type": "dimension", "2": { "$value": { "value": 8, "unit": "px" } } }
}
```

- A **token** is an object with `$value`; a **group** is any other object. `$type` on a group applies to every token inside it.
- **Aliases** use `{group.token}` and resolve to the target's value.
- **Types** the ascent-ux scripts read: `color` (a hex string, or an object with `hex` or srgb `components`), `dimension` and `duration` (`{ "value": N, "unit": "px" }`), `fontFamily` (a string or a list), `fontWeight`, `number`, `cubicBezier`.
- **Themes:** one file per theme, `<name>.light.tokens.json` and `<name>.dark.tokens.json`. The dark file carries only what changes. `check-token-contrast.sh` reads the theme from the file name.

## The ASCENT direction schema

Every shipped direction ([directions/](../directions/README.md)) defines the same tokens, so pages, pairs and mocks work with any of them:

| Group | Tokens |
|---|---|
| `color.text` | `primary`, `secondary`, `link`, `on-accent` |
| `color.surface` | `base`, `raised`, `sunken` |
| `color.accent` | `base`, `strong` |
| `color.border` | `default` (decorative), `strong` (input boundaries, 3:1) |
| `color.focus` | `ring` (3:1 on every surface) |
| `color.status` | `error`, `success`, `warning` (as text on the base surface, 4.5:1) |
| `font.family` | `body`, `heading`, `mono` |
| `font.size` | `sm`, `md`, `lg`, `xl`, `xxl` |
| `font.weight` | `regular`, `bold` |
| `font.line-height` | `body`, `heading` |
| `space` | `1`, `2`, `3`, `4`, `6`, `8` |
| `radius` | `sm`, `md`, `lg`, `pill` |
| `size` | `target-min` (24px, 2.5.8), `target-comfortable` (44px), `measure` (68ch line length) |
| `motion` | `duration.fast`, `duration.base`, `easing.standard` |

Pairs that must pass are in `directions/pairs.tsv`.

## Other sources the scripts read

| Source | How ascent-ux reads it |
|---|---|
| CSS custom properties (`:root { --color-text-primary: … }`) | `check-token-contrast.sh` reads them directly. Dark values come from `prefers-color-scheme: dark`, `[data-theme=dark]`, `.dark` or `.theme-dark` |
| `tailwind.config.*` (`theme.extend.colors`) | read by `design-system-check`. Export to CSS variables (Tailwind 4 `@theme`) to run the contrast script |
| SCSS or Less variables | read by `design-system-check`; contrast needs the compiled CSS |
| Figma variables | through the optional `figma` plugin; compared with the code's tokens |

## Naming, so pair inference works

- `color-text-*` is text, checked on every `color-surface-*`.
- `*-on-X` is content on the `X` color, checked on `color-X`, `color-X-base` and `color-X-strong`.
- Name decorative borders `border-default`, so they are not mistaken for 3:1 boundaries.
