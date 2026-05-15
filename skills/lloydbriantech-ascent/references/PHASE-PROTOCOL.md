# PHASE-PROTOCOL

> Phase-gated delivery discipline. [PRINCIPLES.md §8](../../../docs/framework/PRINCIPLES.md#8-phase-gated-delivery-with-explicit-go-signal) and [ADR-003](../../../docs/framework/DECISIONS/ADR-003-ascent-meta-marker.md) are authoritative.

## The contract

Work is organized into numbered phases (`Phase 0`, `Phase 1`, ...). Each phase has explicit exit criteria. No phase begins without the literal signal **"Proceed with Phase N."** with an explicit integer.

The signal is unambiguous by design. `Continue`, `go ahead`, `start phase 1`, `we're ready` — none of these count. The literal phrase with the integer is the gate.

## Phase exit criteria

A phase ends when every item on its exit-criteria list is satisfied. The list is the contract — once written, it doesn't slip. Items cannot be marked "deferred" or "good enough"; either they ship in this phase or the phase is paused while the gap is closed.

Exit criteria are concrete and verifiable. Bad: "Documentation is good." Good: "PHASE-PROTOCOL.md exists, is substantive, and is referenced from SKILL.md."

## Phase transition steps

When a phase's exit criteria are all met:

1. **Verify.** Re-check every exit criterion against the current state. The owner does this, not the implementer — fresh eyes catch the "I thought I did that" cases.
2. **Update `CHANGELOG.md`.** Add a phase-summary entry under a new version heading. The heading is the version that ships with this phase.
3. **Tag the release.** `git tag v0.N.0 && git push --tags`. Tags are immutable — never force-push a tag.
4. **Wait for the signal.** The implementer pauses. No next-phase work begins until the literal "Proceed with Phase N+1" arrives.
5. **Update phase status.** The next phase's first commit updates `.ascent-meta.json`'s `phase` field, the `CLAUDE.md` phase line, and the roadmap's current-state marker.

Skipping a step is not allowed. The transition is the same shape for v0.2 as it will be for v3.7.

## The `.ascent-meta.json` phase field

Every ASCENT project carries `phase` in `.ascent-meta.json` (per ADR-003):

```json
{
  "phase": "1-parent-skill-skeleton",
  ...
}
```

The string format is `<N>-<kebab-slug>`. The kebab slug matches the phase title in the project's roadmap. The field updates only at phase transition — never mid-phase.

## Worked example — this framework

The ASCENT framework dogfoods its own phase protocol. The framework's [roadmap](../../../docs/framework/ROADMAP.md) lists all phases from Phase 0 to v1.0 with explicit exit criteria for each.

Phase 0 (Foundation) shipped at v0.1.0-alpha on 2026-05-14. Its exit criteria included repository identity files, framework documentation foundation, and ADRs 001-007 — all verifiable items.

Phase 1 (Parent skill skeleton) began only after the literal "Proceed with Phase 1" signal. Its exit criteria include the SKILL.md, all 21 reference modules, the Make framework, and working QA validators — every item is a file that either exists or does not.

The same protocol governs both: tag, signal, update.

## Implementing the protocol

Inside a scaffolded project, the protocol surfaces as:

- `.ascent-meta.json`'s `phase` field as the canonical state
- `docs/delivery/PHASE-PLAN.md` enumerating phases and exit criteria
- The `ascent-delivery-status` skill summarizing where the project is and what's needed to close the current phase
- `CHANGELOG.md` entries at each phase boundary

The phase field is the single source of truth. Other artifacts (CLAUDE.md phase line, README badges) refer to it, never duplicate it.

## Anti-patterns

- **Sliding deadlines.** "We'll finish that in Phase N+1" is sliding. Either Phase N's criterion was wrong (rewrite it now, then close Phase N) or the work isn't done (don't close Phase N).
- **Backfilling acceptance after the fact.** Adding criteria after the phase ships to retroactively justify what was done. Criteria are a contract; if they're wrong, fix them with an ADR, don't quietly rewrite.
- **Skipping the signal.** Beginning Phase N+1 work because "everyone knows we're ready." The signal exists to make the transition observable.
- **`Continue` as a signal.** A user typing "continue" after a phase closes is requesting more conversation, not authorizing a new phase. Ask for the literal signal.

## Overriding the protocol

A project that needs to merge two phases or skip one writes `ADR-NNN-merge-phases-N-and-M` (or similar) before doing so. The override is itself a deliberate, traceable decision.
