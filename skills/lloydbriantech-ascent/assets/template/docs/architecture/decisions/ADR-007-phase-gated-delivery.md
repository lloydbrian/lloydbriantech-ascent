# ADR-007: Phase-gated delivery

**Status:** Accepted
**Date:** <<SCAFFOLD_DATE>> (America/New_York)
**Decider:** <<BRAND>> · ASCENT v<<FRAMEWORK_VERSION>> baseline

## Context

<<PROJECT_TITLE>> needs a delivery cadence. Without one, work accumulates without clear "done" signals, scope creeps without explicit rescoping decisions, and the team can't answer "when did we ship X?" without archaeology in the git log.

The project's operator vocabulary (per [ADR-003](ADR-003-make-as-operator-vocabulary.md)) provides the how — make targets that execute operations. This ADR provides the when — a protocol that governs when work ships, who decides, and what "done" means.

## Decision

<<PROJECT_TITLE>> uses phase-gated delivery:

1. Work is organized into numbered phases (`Phase 0`, `Phase 1`, ...).
2. Each phase has explicit exit criteria written at the start.
3. No phase begins without the literal signal **"Proceed with Phase N."**
4. Phase transitions update `CHANGELOG.md`, tag the release, and update `.ascent-meta.json`'s `phase` field.

Exit criteria are concrete and verifiable: "X file exists and Y test passes" — not "documentation is good" or "code is clean."

The delivery-lead role owns the phase plan. The `ascent-delivery-status` skill summarizes current state.

## Alternatives considered

**Continuous deployment (ship every merge).** Rejected because continuous deployment assumes every merge is independently shippable and production-ready. Early-stage projects have features that span multiple PRs; shipping each PR individually produces half-finished user-facing states. Phase gates collect a coherent set of changes into a shippable unit.

**Ad-hoc milestones.** Rejected because milestones without a protocol produce "we'll ship when it feels done" — which is never, because scope creeps to fill available time. The literal "Proceed with Phase N" signal forces a binary decision: done or not done.

**Sprint-based (two-week time boxes).** Rejected because time-based cadences ship whatever is done at the deadline, regardless of coherence. A sprint that ends mid-feature ships a broken state or carries debt into the next sprint. Phase gates are scope-based, not time-based — they close when exit criteria are met, not when a calendar fires.

**Kanban (continuous flow, no phases).** Rejected because Kanban's "continuous flow" works for mature products with steady-state operational work. New projects need the structure of "what are we building, is it done yet?" — which phases answer explicitly.

## Consequences

**Easier:**

- "What shipped in v0.2.0?" is answered by reading the `CHANGELOG.md` entry — one place, one answer
- "Are we done with this phase?" is answered by checking exit criteria — concrete, not vibes
- The go-signal protocol ("Proceed with Phase N") makes transitions observable — no one wonders whether work has begun on the next thing
- Phase plans scope work explicitly — features not listed wait; scope creep requires deliberate rescoping

**Harder:**

- Writing exit criteria at the start requires upfront planning — the team must decide what "done" means before building
- The literal signal protocol may feel ceremonial for small teams or solo developers — but the ceremony is the protection against silent phase drift
- Features that span two phases must be split — the delivery-lead owns the split decision, which can feel constraining

**Neutral:**

- Phase length is flexible — phases can be one week or one month; the protocol governs transitions, not duration
- The protocol scales from solo developer to small team without modification

## Cost implications

**Time:** Upfront cost to write exit criteria at phase start (~30 minutes per phase). Ongoing time savings from never having to ask "are we done?" or "what shipped?"

**Complexity:** The protocol adds a `PHASE-PLAN.md`, a `phase` field in `.ascent-meta.json`, and a CHANGELOG convention. Low structural overhead for high clarity.

**Future flexibility:** Phases can be revised, merged, or extended — the protocol governs the decision-making process, not the content of each phase.

**Money:** None.
