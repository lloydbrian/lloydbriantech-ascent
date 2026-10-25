# Usability heuristics

These are the heuristic lens of `ux-review` Step 2. A heuristic concern that breaks a WCAG criterion is rated under that criterion. Otherwise it is a Low finding on a core flow, or an unrated observation elsewhere, and it always names the heuristic.

## Nielsen's 10 usability heuristics (Nielsen Norman Group)

| # | Heuristic | Evidence you can see in code | Typical finding |
|---|---|---|---|
| H1 | Visibility of system status | loading indicators, `aria-busy`, progress for long tasks, a confirmation after saving | a submit with no feedback until the page reloads |
| H2 | Match between the system and the real world | labels in the users' words (from personas); dates and units in local formats | internal codes ("PTC-W7-C1") shown to users |
| H3 | User control and freedom | cancel, undo, back links, a dialog close button, Escape | multi-step form with no way back |
| H4 | Consistency and standards | one component per job; the same words for the same action; platform conventions | two different date pickers; "Delete" and "Remove" for one action |
| H5 | Error prevention | constraints (`type`, `min`, `pattern`), confirmation for destructive actions, disabled states with reasons | destructive action with no confirmation |
| H6 | Recognition rather than recall | visible options, defaults, recent items, labels that stay visible while typing | placeholder-only labels that vanish |
| H7 | Flexibility and efficiency of use | keyboard shortcuts with an off switch (WCAG 2.1.4), saved filters, bulk actions | power task needing twenty clicks |
| H8 | Aesthetic and minimalist design | one primary action per view; content hierarchy from tokens | three competing primary buttons |
| H9 | Help users recognize, diagnose and recover from errors | error text that says what happened and how to fix it, placed at the field | "Something went wrong" with no next step |
| H10 | Help and documentation | a consistent help link (WCAG 3.2.6), inline hints at the point of need | help only in a separate PDF |

## ISO 9241-110:2020 interaction principles

These complement the heuristics. ISO 9241-11 defines usability as effectiveness, efficiency and satisfaction in a context of use.

| Principle | What it means for a review |
|---|---|
| Suitability for the user's tasks | the core flow has no steps the task doesn't need |
| Self-descriptiveness | users can tell where they are and what they can do (titles, `aria-current`, step indicators) |
| Conformity with user expectations | it behaves like the platform and the users' other tools |
| Learnability | first use succeeds without training; empty states teach |
| Controllability | users set the pace and can interrupt, undo and go back |
| Use error robustness | errors are prevented, and recoverable when they happen |
| User engagement | the system invites and keeps use: clear value, no dark patterns |

## States every core flow needs

| State | What to check |
|---|---|
| Empty | explains why it is empty and offers the next action |
| Loading | shows progress within about 1 second; announced politely (`role="status"`) |
| Error | says what happened, which field, and how to fix it; focus or announcement reaches it (3.3.1, 3.3.3, 4.1.3) |
| Success | confirms what happened and what comes next |
| Partial and offline | when the app syncs: what is saved and what is not |
