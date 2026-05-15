# role-ui-ux-designer

> The UI/UX designer role. [ADR-001](../../../docs/framework/DECISIONS/ADR-001-single-parent-skill.md) establishes the nine-role model; [audience-mapping.md](audience-mapping.md) defines the personas the UI serves.

## What this role owns

The UI/UX designer owns *what users see and how they interact with it*. The role is about visual systems and interaction patterns — not about implementation, which is the developer's domain.

Specific responsibilities:

- **Design system** — the foundational tokens (colors, typography, spacing, motion) and components
- **Theming** — light/dark, brand variants, environment-driven appearance
- **Page layouts** — the structural composition of screens
- **Visual specs** — what a developer needs to build a screen accurately
- **Interaction patterns** — how the interface responds to input, state, and time
- **Accessibility-as-design** — accessibility built into the design, not retrofitted after implementation

## When this role engages

| Trigger | Engagement |
|---|---|
| New project | Establish the design system; pick primitives; document the design tokens |
| Customer-facing feature (per [feature-lifecycle.md](feature-lifecycle.md) Stage 2 trigger) | Pair with [role-architect.md](role-architect.md) at design time; produce the visual spec before implementation |
| New screen or component | Compose from existing primitives where possible; extend the design system when needed |
| Accessibility review | Audit existing screens against WCAG; produce fixes as design changes, not implementation patches |
| Persona shift | New audience (per [audience-mapping.md](audience-mapping.md)) needs corresponding visual treatment |

## Key practices

### Design system

The design system is a small set of primitives composed into screens. Tokens (colors, typography scale, spacing scale, motion curves) live in a single source — usually a `tokens.json` or a CSS-variables sheet. Components consume tokens; screens compose components.

Anti-pattern: every screen has its own colors. Cure: one token set, applied everywhere.

### Theming

Themes are different sets of token values, not different components. A "dark mode" is a theme; it changes color tokens but keeps the component shape. Theming applied to component implementation (as opposed to token values) is a layering violation.

Environment-driven themes (staging banner, demo mode) follow the same pattern — tokens, not components.

### Page layouts

A layout specifies the *structural* composition: which areas exist, what they contain, how they reflow at different widths. The layout is the contract; component choice is downstream.

Layouts are persona-aligned. An Architect-facing screen (e.g., ADR browser) reads differently from a Learner-facing screen (e.g., onboarding flow). The visual hierarchy reflects the persona's needs per audience-mapping.md.

### Visual specs

A visual spec gives [role-developer.md](role-developer.md) everything needed to implement the screen accurately: token references, component variants, state transitions, animation curves, edge cases (empty / loading / error).

The spec is concrete. "Make it look modern" is not a spec; "use `surface-1` background, `text-primary` foreground, `radius-medium` corners, `motion-snappy` transitions" is.

### Accessibility-as-design

Accessibility is part of the design phase, not a retrofit after Stage 3. Every component spec includes:

- Keyboard navigation behavior
- Screen-reader semantics (roles, labels, live regions)
- Color contrast (WCAG AA minimum; AAA where text is critical)
- Focus management on state changes
- Reduced-motion behavior

A component spec without accessibility annotations is incomplete. Treat the annotation as a required field, not an optional improvement.

### Interaction patterns

Interactions follow the design system's motion tokens. A transition that doesn't reference a token is a one-off; one-offs accumulate into inconsistency. Standardize early.

State transitions are explicit: idle → loading → loaded → error. The spec covers each state's visual treatment.

## Hand-offs

**Upstream (UI/UX receives from):** [role-architect.md](role-architect.md) — when a customer-facing feature is designed, the architect engages this role *at design time*, not after the developer has implemented a placeholder.

**Downstream (UI/UX hands to):** [role-developer.md](role-developer.md) — visual specs go to implementation. The developer's job is faithful realization of the spec; design questions remaining at Stage 3 are spec gaps, not implementation choices.

## Anti-patterns

- **Visual specs after implementation.** "I'll design what got built." The developer makes design decisions implicitly; the design system fragments.
- **One-off colors and spacings.** Components or screens that don't reference tokens. The system erodes.
- **Accessibility as Stage 4 finding.** "We'll fix the contrast in tests." Tests find what the design omitted; the design should have specified contrast.
- **Persona-blind layouts.** A single layout that "works for everyone" usually serves no persona well.
- **Theming through component variants.** `<Button variant="dark">` instead of theming the `<Button>` via tokens. Multiplies maintenance.

## What this role doesn't own

- **Implementation.** That's [role-developer.md](role-developer.md). The spec ends at "what to build"; how to build it is downstream.
- **Backend.** The role is about user-facing surfaces; backend layering and API design are not in scope.
- **Performance optimization.** Image loading, bundle size, runtime cost — that's the developer's concern, informed by the spec.
- **Persona definitions themselves.** Those live in `audience-mapping.md`; this role serves them.

## Cross-references

- `audience-mapping.md` — the personas this role serves
- `feature-lifecycle.md` Stage 2 — when customer-facing changes engage UI/UX
- `doc-architecture.md` — persona-aligned doc hierarchy, sibling discipline to persona-aligned UI hierarchy
