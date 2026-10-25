# ARIA patterns for common widgets

Based on WAI-ARIA 1.2 and the ARIA Authoring Practices Guide (APG) at <https://www.w3.org/WAI/ARIA/apg/patterns/>.

**The first rule of ARIA:** use the native HTML element when one exists. `<button>`, `<a href>`, `<input>`, `<select>`, `<details>` and `<dialog>` bring their role, keyboard support and states for free. No ARIA is better than wrong ARIA.

| Widget | Native first | Roles and states | Keyboard | Common failures (criterion) |
|---|---|---|---|---|
| **Button** | `<button type="button">` | `role="button"` only when native is impossible; `aria-pressed` for toggles; `aria-expanded` when it opens something | Enter and Space activate | `div` with `onclick` (2.1.1, 4.1.2); icon button with no name (4.1.2) |
| **Link** | `<a href>` | none needed; `aria-current="page"` for the current page | Enter activates | `<a>` without `href` used as a button; "click here" (2.4.4) |
| **Disclosure** (show/hide) | `<details><summary>` | trigger `button` with `aria-expanded` and `aria-controls` | Enter and Space toggle | state not exposed (4.1.2) |
| **Modal dialog** | `<dialog>` with `showModal()` | `role="dialog"` with `aria-modal="true"` and `aria-labelledby` | focus moves into the dialog; Tab cycles inside; Escape closes; focus returns to the trigger | focus left behind the dialog (2.4.3); no Escape (2.1.2); background still readable |
| **Navigation menu** | `<nav>` with a list of links; disclosure buttons for sub-lists | `aria-expanded` on sub-list toggles; **not** `role="menu"` | Tab through links; Enter or Space opens a sub-list; Escape closes it | `role="menu"` on site navigation forces app-menu keys users don't expect (4.1.2); hover-only sub-menus (2.1.1) |
| **Menu button** (app actions) | — | `button` with `aria-haspopup="menu"` and `aria-expanded`; `role="menu"` with `menuitem` children | Enter, Space or Down opens; arrow keys move; Escape closes and returns focus | Tab used instead of arrows inside the menu; focus not returned |
| **Tabs** | — | `tablist` with `tab` elements (`aria-selected`, `aria-controls`) and `tabpanel` elements (`aria-labelledby`) | arrows move between tabs; Tab moves into the panel; Home and End | every tab in the Tab order; selection not exposed (4.1.2) |
| **Accordion** | `<details>` per section, or buttons inside headings | heading > `button` with `aria-expanded` and `aria-controls` | Enter and Space toggle; Tab moves between headers | clickable headings with no button (2.1.1) |
| **Combobox / autocomplete** | `<input list>` with `<datalist>` for simple cases | `input role="combobox"` with `aria-expanded`, `aria-controls` and `aria-activedescendant`; a `listbox` with `option` elements | Down opens and moves; Enter selects; Escape closes | suggestions not announced (4.1.3); mouse-only selection (2.1.1) |
| **Status and alerts** | — | `role="status"` (polite) for results and saves; `role="alert"` for urgent errors; the region exists before its text changes | none: focus does not move | toast added with its live region, so it is never announced (4.1.3) |
| **Tooltip** | prefer visible text | `role="tooltip"` referenced by `aria-describedby`; shown on hover **and** focus | Escape dismisses | hover only (2.1.1, 1.4.13); disappears when hovered (1.4.13) |
| **Carousel** | — | `region` with `aria-roledescription="carousel"` and a label; slides as `group` | a visible pause button; previous and next buttons; no auto-rotation while focus is inside | auto-rotation with no pause (2.2.2) |

## Checks that apply to every widget

- **Name:** every widget and control has an accessible name that contains its visible label (4.1.2, 2.5.3).
- **States are announced:** expanded, selected, checked, pressed and current are exposed as ARIA states or native properties, and they update (4.1.2).
- **Focus is managed:** opening moves focus where the user expects, closing returns it to the trigger, and nothing removes the focus indicator (2.4.3, 2.4.7).
- **Targets:** at least 24 by 24 CSS px (2.5.8); the blueprint uses 44 px for primary controls.
