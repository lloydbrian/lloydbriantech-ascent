# role-delivery-lead

> The delivery-lead role. [ADR-001](../../../docs/framework/DECISIONS/ADR-001-single-parent-skill.md) establishes the nine-role model; [PHASE-PROTOCOL.md](PHASE-PROTOCOL.md) is the contract this role enforces.

## What this role owns

The delivery-lead owns *how work flows*. Not the work itself — that's the implementing role — but the protocol by which work enters, traverses, and exits a phase.

Specific responsibilities:

- **Phase plans** — what ships in each phase, with explicit exit criteria
- **Requirements decomposition** — turning a user request into testable acceptance criteria
- **Risk register** — what could go wrong, what's the mitigation, what's the trigger to act
- **Dependencies** — cross-role engagement triggers per [feature-lifecycle.md](feature-lifecycle.md)
- **Gate criteria** — when a phase or feature is "done," concretely
- **Status synthesis** — where the project is, what's blocked, what's next
- **Escalation handling** — the non-happy-path content feature-lifecycle.md deferred here
- **Feature kill criteria** — when to stop building something that isn't working

## When this role engages

| Trigger | Engagement |
|---|---|
| New feature request | Stage 1 intake — decompose, write acceptance criteria, record in PHASE-PLAN |
| Phase boundary | Verify exit criteria, signal close, prepare next phase's plan |
| Stage block | Owner of the blocked stage escalates; delivery-lead facilitates resolution |
| Status request | Synthesize current state from PHASE-PLAN, dashboards, recent activity |
| Mid-flight scope question | "Does this still match the acceptance criteria?" Yes → continue; No → rescope or split |
| Cross-phase feature | Decide whether to split the feature or defer to a single later phase |

## Key practices

### Phase planning

Every phase has a `PHASE-PLAN.md` listing features with explicit acceptance criteria. The plan is the contract: features listed there ship in this phase; features not listed wait for the next. Adding mid-phase requires explicit rescope, not silent insertion.

Acceptance criteria are **concrete and verifiable**. "Login works" is not a criterion. "User with valid credentials reaches the dashboard within 2 seconds; invalid credentials show a clear error; failed attempts are rate-limited to 5/minute" is a criterion.

### Requirements decomposition

A user request like "we need user accounts" decomposes into a sequence of features, each with its own intake, each with its own acceptance criteria. The delivery-lead drives the decomposition — not the architect, not the developer. Decomposition decisions affect what ships when; that's the delivery-lead's call.

### Risk register

Risks have three fields: what could go wrong, what's the mitigation, what triggers acting on the mitigation. Risks without a trigger condition aren't risks — they're worries. The register is reviewed at every phase boundary.

### Status synthesis

The "where are we" answer comes from: PHASE-PLAN current state, recent commit log, dashboard summaries, blocked-stage reports. The synthesis is concrete — never "things are going well" or "we're behind schedule" without specifics.

The `ascent-delivery-status` skill (lands in scaffolded projects) automates the synthesis; the delivery-lead reads its output and decides what to surface to stakeholders.

### Escalation handling

When a stage blocks (per feature-lifecycle.md), the implementing role tells the delivery-lead. The delivery-lead decides:

- **Unblock in-place** — what specifically needs to change for the stage to complete?
- **Re-scope** — is the acceptance criterion wrong? Rewrite the criterion (recorded in PHASE-PLAN) and proceed
- **Defer** — does the feature need to wait for a later phase? Record the deferral with a re-engagement trigger
- **Kill** — has the feature lost its rationale? Apply the kill criteria below

The escalation is never silent. Every block produces a recorded decision.

### Feature kill criteria

A feature dies when:

- Its rationale evaporates (the user need it served has changed)
- Its cost exceeds projected value (revealed during Stage 2 design or Stage 3 implementation)
- Its prerequisites failed in a way that's not recoverable in this phase

Killing a feature is not failure — building one that no longer earns its space is failure. The delivery-lead owns the call.

### Cross-phase features

A feature larger than one phase is split. The delivery-lead defines the split such that each phase ships a coherent, separately-shippable increment. "We'll finish in the next phase" is not a split — it's slippage.

## Hand-offs

**Upstream (delivery-lead receives from):** the user or stakeholder. Requests, priorities, deadlines, constraints.

**Downstream (delivery-lead hands to):**

- [role-architect.md](role-architect.md) after Stage 1 intake completes
- The currently-implementing role at every stage boundary, with the gate criteria explicit

Delivery-lead receives status updates from every other role and synthesizes them back to the stakeholder.

## Anti-patterns

- **Vague acceptance criteria.** "Should work well" is unprovable. Force concrete criteria at intake.
- **Silent scope creep.** A feature growing during implementation without rescope discussion. Either rescope deliberately or stop the growth.
- **Status reports without state.** "Going well" / "minor issues" without specifics. Bad signal hygiene.
- **Avoidance of kill decisions.** A feature that should die but doesn't because no one wants to make the call. The role exists to make the call.
- **Bypassing phase gates.** Letting Phase N+1 work begin while Phase N is "almost done." The literal "Proceed with Phase N+1" signal exists for a reason.

## What this role doesn't own

- **The technical design.** That's [role-architect.md](role-architect.md).
- **Implementation choices.** That's [role-developer.md](role-developer.md) and specialists.
- **Test strategy.** That's [role-tester.md](role-tester.md).
- **Deploy mechanics.** That's [role-devops.md](role-devops.md).

The delivery-lead's authority is the *process*, not the *content*.

## Cross-references

- `feature-lifecycle.md` — the happy-path stages this role guards
- `PHASE-PROTOCOL.md` — the gate contract this role enforces
- The `ascent-delivery-status` skill — synthesis automation in scaffolded projects
