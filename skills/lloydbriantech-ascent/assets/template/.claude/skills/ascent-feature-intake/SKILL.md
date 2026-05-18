---
name: ascent-feature-intake
description: >-
  Runs the delivery-lead intake protocol for new features in
  <<PROJECT_TITLE>>: decomposes a request into acceptance criteria,
  identifies cross-role dependencies, estimates scope, and records the
  feature in the project's PHASE-PLAN.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
---

# ascent-feature-intake

Structures a new feature request into the delivery-lead's intake format: concrete acceptance criteria, scope estimate, cross-role dependencies, and a PHASE-PLAN entry. This is Stage 1 of the feature lifecycle — the point where vague requests become testable commitments.

## When this skill engages

- When a stakeholder or developer describes a new feature they want
- When explicitly asked to "intake this feature" or "add this to the phase plan"
- At the start of a new phase, when features are being scoped
- NOT for bug fixes (those skip intake and go directly to developer)

## Inputs

- The feature request (can be conversational, vague, or well-structured)
- The current phase context (from .ascent-meta.json)
- Optional: priority or deadline constraints from the stakeholder

## Outputs

- A structured intake artifact with: one-sentence description, acceptance criteria (concrete + verifiable), estimated scope, cross-role dependencies
- An entry added to `docs/delivery/PHASE-PLAN.md` (or created if first feature)
- The output becomes visible in [ascent-delivery-status](../ascent-delivery-status/SKILL.md) as outstanding work

## Operational logic

The skill interviews the requestor to extract testable acceptance criteria from vague descriptions. "We need user accounts" becomes "User with valid credentials sees the dashboard within 2 seconds; invalid credentials show a clear error; failed attempts are rate-limited to 5/minute." Each criterion is evaluated for testability — if it can't be verified by a test or observation, it's refined until it can. The skill identifies which roles engage (per the feature-lifecycle Stage 2 trigger table) and estimates scope relative to prior features. Per §15 (session resumption), when acceptance criteria are locked, the skill appends them as dated entries to `docs/delivery/working-memory.md` — making feature decisions durable across sessions so they aren't re-litigated on resume. The full interview-protocol decision tree lands in Phase 3.

## Examples

Examples land in Phase 3. Each example will show a vague request, the interview interaction, and the resulting structured intake artifact.

## Anti-patterns

The primary failure mode is **accepting vague acceptance criteria** — "login should work" passes through without decomposition into testable conditions. The skill must push back on every criterion that fails the testability check: "How would you verify this? What does 'works' look like concretely?"
