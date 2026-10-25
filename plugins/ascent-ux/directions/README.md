# Design directions

Five predefined looks for `design-directions` (ADR-012, decision 7). Each one is a pair of Design Tokens 2025.10 files:
- `<id>.light.tokens.json` holds the whole token set
- `<id>.dark.tokens.json` holds only the colors that change

They share one schema ([design-tokens.md](../references/design-tokens.md)), so any page built on the tokens takes any direction without changes.

| Id | Direction | Feels like | Suits | Type | Shape |
|---|---|---|---|---|---|
| D1 | Clean neutral | calm, generous white space, one blue accent | most apps; the safe default | system UI, base 16px | radius 4–8px |
| D2 | Bold brand | violet with a magenta focus ring, large type, high contrast | marketing and community sites | Inter body, Poppins headings at weight 800, base 17px | radius 10–20px |
| D3 | Editorial | warm paper, rust accent, serif throughout, long reading lines | docs and content sites | Source Serif 4 with a Georgia fallback, base 18px, line-height 1.7 | radius 2–4px |
| D4 | Soft friendly | warm cream, teal accent, gentle motion | consumer and hobby apps | Nunito, base 16px | radius 10–24px, 200–320ms motion |
| D5 | Dense professional | white and slate, blue accent, compact | dashboards and admin tools | system UI, base 14px, line-height 1.45 | radius 3–6px, 2–24px spacing |

## Guarantees (checked by `tests/plugins/ascent-ux/`)

- Every direction passes every pair in [pairs.tsv](pairs.tsv), in light and dark. That covers text on every surface (4.5:1), on-accent text (4.5:1), accent and input borders (3:1), the focus ring on every surface (3:1), and status colors as text (4.5:1).
- Every direction converts to CSS with `scripts/tokens-to-css.sh`.
- The blueprint's `tokens.css` is exactly the D1 output, so it cannot drift.

## Fonts

Named web fonts (Inter, Poppins, Source Serif 4, Nunito) are open-source (SIL Open Font License), but they must be loaded by the project. Every stack ends in a system fallback, and mocks say which font actually rendered.

## Adding a direction

`design-directions` Step 6 generates D6 and onward in the session's mock directory, never here. A direction joins this catalog only through a plugin change: the same schema, a passing `pairs.tsv` in both themes, and a version bump.
