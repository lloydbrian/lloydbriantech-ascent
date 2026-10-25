# Manual test checklist

Automated and static checks find only part of WCAG failures. A person runs these passes on each core flow before a release, and records the date in the contract (`ux.manual_tests`). At the enterprise target, a pass older than the last release that changed the flow is a maturity gap.

## Keyboard pass (about 15 minutes per flow)

Unplug or ignore the mouse.

1. Load the page and press **Tab**. The first stop is a skip link, or the first control; the focus indicator is clearly visible (2.4.7).
2. Tab through the whole flow. The order follows the visual and reading order (2.4.3), and nothing focused is hidden under a sticky header (2.4.11).
3. Operate every control: **Enter** on links and buttons, **Space** on buttons, checkboxes and radios, **arrow keys** in radios, tabs, menus and sliders (2.1.1).
4. Open each dialog, menu and popover. Focus moves in, **Escape** closes it, and focus returns to the trigger (2.1.2, 2.4.3).
5. Submit the form with errors. The error is announced or focused, says what is wrong and how to fix it, and you can reach the field (3.3.1, 3.3.3).
6. Finish the task. Nothing needed a mouse, a drag (2.5.7) or a hover (1.4.13).

## Screen-reader pass (about 20 minutes per flow)

Use one desktop pair, and one mobile pair if the flow is used on phones:
- **VoiceOver + Safari** (macOS: Cmd+F5; iOS: Settings > Accessibility)
- **NVDA + Firefox or Chrome** (Windows, free)
- **TalkBack + Chrome** (Android)

1. Listen to the page title and the first heading (2.4.2, 1.3.1).
2. Open the landmarks list and the headings list (VoiceOver rotor, NVDA+F7). The structure matches the page (1.3.1).
3. Move through every control on the flow. Each has a name that matches its visible label, a role and a state (4.1.2, 2.5.3).
4. Trigger a save, an error and a loading state. Each is announced without moving focus (4.1.3).
5. Check images: informative ones are described, and decorative ones are silent (1.1.1).

## Zoom and display pass (about 5 minutes)

1. Zoom the browser to 200%: nothing is cut off or overlapping (1.4.4).
2. Make the window 320 CSS px wide: no horizontal scrolling for text content (1.4.10).
3. Turn on the OS reduced-motion setting: nothing animates beyond a fade (2.3.3).
4. Switch to dark mode: everything is still readable. The contrast numbers come from `check-token-contrast.sh`.

## Record (in the contract)

```yaml
manual_tests:
  - flow: enter-score
    keyboard: 2026-10-24          # date of the last pass
    screen_reader: 2026-10-24
    screen_reader_used: VoiceOver + Safari 18
    zoom_and_display: 2026-10-24
    issues: docs/ux/manual-2026-10-24.md   # notes; no personal data
```
