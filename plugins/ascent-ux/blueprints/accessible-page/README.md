# Blueprint: accessible page

A one-page starter that shows the ASCENT UX baseline working. It is also the template `design-directions` uses to mock each direction, and the known-good fixture the plugin's tests run against.

| File | Role |
|---|---|
| `index.html` | the page: skip link, header, navigation with `aria-current`, main with `h1` and `h2`s, a captioned table with `th scope`, a labelled form (select, text input with hint and error, a radio group in a `fieldset`), a live status region, an empty state, and a footer with help (3.2.6) |
| `page.css` | layout and components, **built only from tokens**: one `:focus-visible` style, 44px targets, 3:1 input borders, a `prefers-reduced-motion` rule, and reflow at 320px |
| `tokens.css` | generated from UX-D1 with `scripts/tokens-to-css.sh`; swap it to change direction |

## What it demonstrates

| Practice | WCAG 2.2 | Where |
|---|---|---|
| Skip link and landmarks | 2.4.1, 1.3.1 | `.skip-link`, `header`, `nav`, `main`, `footer` |
| Language, title, one `h1`, no skipped levels | 3.1.1, 2.4.2, 1.3.1 | `<html lang>`, `<title>`, headings |
| Labels tied to inputs; hint and error through `aria-describedby` | 1.3.1, 3.3.1, 3.3.2, 4.1.2 | the score form |
| Group label for radios | 1.3.1 | `fieldset` and `legend` |
| Status announced without moving focus | 4.1.3 | `role="status"` |
| Visible focus that is never removed | 2.4.7, 2.4.11 | `:focus-visible` in `page.css` |
| Targets of at least 24px (44px on primary controls) | 2.5.8 | `--size-target-*` |
| Contrast in light and dark | 1.4.3, 1.4.11 | the token pairs |
| Reduced motion and reflow | 2.3.3, 1.4.10 | the media queries |
| Wide tables scroll in a labelled, focusable region, so the page itself never scrolls sideways at 320px | 1.4.10, 2.1.1 | `.table-wrap` with `role="region"` and `tabindex="0"` |

## Using it in a project

Copy the three files. Regenerate `tokens.css` from the chosen direction, or from the project's own tokens:

```bash
bash "$PLUGIN_ROOT/scripts/tokens-to-css.sh" <direction>.light.tokens.json <direction>.dark.tokens.json > tokens.css
```

Then check it:

```bash
bash "$PLUGIN_ROOT/scripts/check-web-accessibility.sh" .
bash "$PLUGIN_ROOT/scripts/check-token-contrast.sh" tokens.css page.css
```

The form posts to `#` and has no script. Wire validation through the project's own code, and keep the hint, error and status patterns.
