# WCAG 2.2 Level A and AA checklist

WCAG 2.2 is a W3C Recommendation and, since October 2025, ISO/IEC 40500:2025. It has 55 success criteria at Level A and AA; 4.1.1 Parsing was removed in 2.2. Criteria marked **new** were added in 2.2. Read the normative text at <https://www.w3.org/TR/WCAG22/> when a case is close.

**Evidence** names where a result can come from:
- `U#`: a static check of `check-web-accessibility.sh`
- `C`: `check-token-contrast.sh`
- `B`: the Playwright browser pass
- `R`: reading code
- `M`: the manual checklist (keyboard or screen reader)

A criterion that needs `B` or `M` is never marked pass on `U#` or `R` alone.

## 1. Perceivable

| Criterion | Level | Look for in code | Common failure | Evidence |
|---|---|---|---|---|
| 1.1.1 Non-text Content | A | `alt` on every `img`, `role="img"` with `aria-label` on SVG icons, labels on icon buttons, captcha alternatives | missing `alt`; `alt="image"`; meaningful icon with no name | U2, U4, R, B |
| 1.2.1 Audio-only and Video-only (Prerecorded) | A | transcript link next to audio or silent video | podcast with no transcript | R, M |
| 1.2.2 Captions (Prerecorded) | A | `<track kind="captions">` or burned-in captions | video with no captions | R, M |
| 1.2.3 Audio Description or Media Alternative (Prerecorded) | A | described track or full text alternative | instructions shown only visually in a video | R, M |
| 1.2.4 Captions (Live) | AA | live captioning in the stream setup | live stream with no captions | M |
| 1.2.5 Audio Description (Prerecorded) | AA | `<track kind="descriptions">` or described version | key visual information never spoken | M |
| 1.3.1 Info and Relationships | A | landmarks, heading elements, `th`/`scope`, `label for`, `fieldset`/`legend`, lists as `ul`/`ol` | bold text as headings; layout tables; `div` lists; labels not tied to inputs | U3, U7, R, B |
| 1.3.2 Meaningful Sequence | A | DOM order matches reading order; CSS `order` and absolute positioning do not reorder meaning | visual order differs from DOM order | R, B |
| 1.3.3 Sensory Characteristics | A | instructions that rely only on shape, color, size or position ("click the round button") | "fields in red are required" | R |
| 1.3.4 Orientation | AA | no CSS or JS locking portrait or landscape | `screen.orientation.lock` without need | R, B |
| 1.3.5 Identify Input Purpose | AA | `autocomplete` tokens on personal-data fields (`name`, `email`, `tel`, `street-address`) | sign-up form with no `autocomplete` | R |
| 1.4.1 Use of Color | A | errors, links and states also shown by text, icon or underline | links distinguished by color alone; red-only errors | R, B |
| 1.4.2 Audio Control | A | autoplaying audio can be paused or muted | background audio on load | U10, R |
| 1.4.3 Contrast (Minimum) | AA | text 4.5:1, large text (24px, or 18.66px bold) 3:1, in every theme | grey placeholder-like text; dark theme never checked | C, B |
| 1.4.4 Resize Text | AA | text scales to 200% without loss; no `user-scalable=no` | fixed-height containers clip text; zoom blocked | U5, B |
| 1.4.5 Images of Text | AA | text rendered as text, not baked into images | headings as PNG | R |
| 1.4.10 Reflow | AA | no horizontal scrolling at 320 CSS px wide (except data tables, maps) | fixed widths; `min-width: 1024px` | B |
| 1.4.11 Non-text Contrast | AA | 3:1 for input borders, focus indicators, icons and chart marks that carry meaning | light-grey input borders; faint focus ring | C, B |
| 1.4.12 Text Spacing | AA | content survives line-height 1.5, letter spacing 0.12em, word spacing 0.16em, paragraph spacing 2em | fixed heights cut off text | B |
| 1.4.13 Content on Hover or Focus | AA | tooltips and popovers are dismissible (Escape), hoverable and persistent | tooltip disappears when the pointer moves onto it | B, M |

## 2. Operable

| Criterion | Level | Look for in code | Common failure | Evidence |
|---|---|---|---|---|
| 2.1.1 Keyboard | A | every action reachable and operable by keyboard; native controls or role + tabindex + key handlers | clickable `div`; drag-only reordering; hover-only menus | U12, B, M |
| 2.1.2 No Keyboard Trap | A | focus can always leave a component (Tab, Shift+Tab, Escape) | modal or embedded widget that holds focus | B, M |
| 2.1.4 Character Key Shortcuts | A | single-key shortcuts can be turned off, remapped, or only work on focus | "s" for search fires while typing elsewhere | R |
| 2.2.1 Timing Adjustable | A | time limits can be turned off, adjusted or extended (except real-time events) | session times out with no warning | R, M |
| 2.2.2 Pause, Stop, Hide | A | moving, blinking or auto-updating content over 5 s can be paused | carousels with no pause; auto-scrolling tickers | U10, R, B |
| 2.3.1 Three Flashes or Below Threshold | A | nothing flashes more than three times per second | strobe effects; rapid animated GIFs | R, M |
| 2.4.1 Bypass Blocks | A | skip link to `main`, or landmarks | no skip link and long repeated navigation | R, B |
| 2.4.2 Page Titled | A | a unique, descriptive `<title>` per page or route | every route titled "App" | U9, B |
| 2.4.3 Focus Order | A | focus order follows meaning; no positive `tabindex`; dialogs move focus in and return it | positive tabindex; focus lost after closing a dialog | U6, B, M |
| 2.4.4 Link Purpose (In Context) | A | link text (with its context) says where it goes | "click here", "read more" repeated | U4, R |
| 2.4.5 Multiple Ways | AA | more than one way to reach a page (nav, search, sitemap), except steps in a process | content reachable only through one deep path | R |
| 2.4.6 Headings and Labels | AA | headings and labels describe their topic or purpose | vague labels such as "Field 1" | U7, R |
| 2.4.7 Focus Visible | AA | a visible `:focus-visible` style on every interactive element | `outline: none` with nothing in its place | U11, B |
| 2.4.11 Focus Not Obscured (Minimum) **new** | AA | the focused element is not fully hidden by sticky headers, footers or banners | sticky header covers focused links while tabbing | B |
| 2.5.1 Pointer Gestures | A | multipoint or path gestures have a single-pointer alternative | pinch-only zoom on a map without buttons | R, M |
| 2.5.2 Pointer Cancellation | A | actions fire on up-event, or can be aborted | destructive action on `mousedown` | R |
| 2.5.3 Label in Name | A | the accessible name contains the visible label text | button shows "Send", `aria-label="Submit form"` | B |
| 2.5.4 Motion Actuation | A | shake or tilt features have a control alternative and can be turned off | shake to undo only | R |
| 2.5.7 Dragging Movements **new** | AA | every drag action has a single-pointer alternative (buttons, a menu) | drag-only sortable lists or sliders | R, B |
| 2.5.8 Target Size (Minimum) **new** | AA | targets at least 24 by 24 CSS px, or spaced so a 24 px circle fits, or inline in text | tiny icon buttons packed together | B |

## 3. Understandable

| Criterion | Level | Look for in code | Common failure | Evidence |
|---|---|---|---|---|
| 3.1.1 Language of Page | A | `<html lang="…">` | missing `lang` | U1 |
| 3.1.2 Language of Parts | AA | `lang` on passages in another language | quotes in another language read with the wrong voice | R |
| 3.2.1 On Focus | A | focus never triggers a change of context | focusing a field opens a new page | B |
| 3.2.2 On Input | A | changing a setting does not change context without warning | a select that navigates on change | R, B |
| 3.2.3 Consistent Navigation | AA | repeated navigation keeps the same order across pages | menu order changes per page | R |
| 3.2.4 Consistent Identification | AA | the same function has the same label everywhere | "Search", "Find" and "Look up" for one feature | R |
| 3.2.6 Consistent Help **new** | A | help (contact, chat, FAQ link) in the same relative place on every page | help link moves or disappears | R |
| 3.3.1 Error Identification | A | errors are described in text and tied to the field (`aria-describedby`, `aria-invalid`) | red border only | R, B |
| 3.3.2 Labels or Instructions | A | labels and format instructions before input | placeholder as the only label or hint | U3, R |
| 3.3.3 Error Suggestion | AA | errors say how to fix them | "Invalid input" | R, B |
| 3.3.4 Error Prevention (Legal, Financial, Data) | AA | reversible, checked or confirmed submissions for legal, financial or data changes | one-click irreversible delete or payment | R |
| 3.3.7 Redundant Entry **new** | A | information entered earlier in a process is auto-filled or selectable | asking for the same address twice | R |
| 3.3.8 Accessible Authentication (Minimum) **new** | AA | no cognitive function test to sign in, or an alternative: password managers and paste allowed, passkeys, email links | blocking paste in password fields; puzzle captcha with no alternative | R, B |

## 4. Robust

| Criterion | Level | Look for in code | Common failure | Evidence |
|---|---|---|---|---|
| 4.1.2 Name, Role, Value | A | native controls, or ARIA roles with states (`aria-expanded`, `aria-checked`, `aria-selected`) that update | custom checkbox without `aria-checked`; unnamed icon button | U3, U4, U8, U12, B |
| 4.1.3 Status Messages | AA | status changes announced through `role="status"`, `role="alert"` or `aria-live` without moving focus | "Saved" toast never announced | R, B, M |

## Level AAA (opt-in through `wcag-2.2-aa-plus`)

Commonly adopted: 1.4.6 Contrast (Enhanced) 7:1, 2.4.12 Focus Not Obscured (Enhanced), 2.4.13 Focus Appearance, 2.5.5 Target Size (Enhanced) 44 px, 3.3.9 Accessible Authentication (Enhanced). The contract lists the chosen ones; the others are not rated.
