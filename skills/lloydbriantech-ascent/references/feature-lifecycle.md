# feature-lifecycle

> How a feature traverses the nine roles from intake to observed-in-production. [ADR-001](../../../docs/framework/DECISIONS/ADR-001-single-parent-skill.md) defines the role mental model; [ARCHITECTURE.md Layer 2](../../../docs/framework/ARCHITECTURE.md#layer-2--parent-skill) describes the skill's role-routing structure.

This document covers the **happy path only** — the linear flow when a feature is well-scoped and no exceptions occur. Escalations, mid-flight pivots, dead-end branches, and recovery patterns belong to [role-delivery-lead.md](role-delivery-lead.md) (lands in Chunk 5 of Phase 1).

## The lifecycle at a glance

```
Intake → Design → Implementation → Validation → Deployment → Observation
   |        |           |               |             |            |
delivery- architect  developer       tester       devops    devops +
  lead   (+ others)  (+ others)     (+ cyber)               delivery-lead
```

Six stages. Each stage has a primary role and may engage supporting roles. The lifecycle is bounded by [PHASE-PROTOCOL.md](PHASE-PROTOCOL.md) — features within a phase complete; new features wait for the next phase gate.

## Stage 1: Intake — delivery-lead

The delivery-lead receives a feature request, decomposes it into requirements, and writes the entry in the project's PHASE-PLAN. The intake artifact is a short structured note:

- One-sentence feature description
- Acceptance criteria — concrete and verifiable
- Estimated scope (rough — concretized in Stage 2)
- Cross-role dependencies (which roles must engage)

**Output:** feature recorded in PHASE-PLAN. **Triggers Stage 2.**

## Stage 2: Design — architect

The architect reads the intake, designs the change, and writes an ADR if the decision constrains future work. Simple additions (e.g., a new endpoint on an existing service) need no ADR — just an implementation sketch.

The architect engages specialists *before* committing to an approach:

- [role-data-engineer.md](role-data-engineer.md) if schema or query changes
- [role-ai-engineer.md](role-ai-engineer.md) if prompt or eval changes
- [role-ui-ux-designer.md](role-ui-ux-designer.md) if customer-facing surface changes
- [role-devops.md](role-devops.md) if infra or deploy-pipeline changes
- [role-cybersecurity.md](role-cybersecurity.md) if auth, secrets, or egress changes

The design's deliverable is the smallest artifact that fully specifies the change. Sometimes that's three sentences. Sometimes it's an ADR plus a sequence diagram. Match the artifact to the change.

**Output:** design (with or without ADR). **Triggers Stage 3.**

## Stage 3: Implementation — developer (+ specialists)

The developer implements per the design. The implementation follows backend layering (`routes → controllers → services → storage` per [ASCENT-INVARIANTS.md](ASCENT-INVARIANTS.md) §6) and emits observability per [observability-contract.md](observability-contract.md).

Specialists pair in when their domain is touched:

- Schema or query changes → data-engineer pairs in
- Prompt or eval changes → ai-engineer pairs in
- Customer-facing UI → ui-ux-designer pairs in

**Output:** implementation + tests + observability hooks. **Triggers Stage 4.**

## Stage 4: Validation — tester (+ cybersecurity)

The tester verifies the acceptance criteria from Stage 1. Tests cover the happy path, the documented error paths, and the boundary conditions the architect's design anticipated.

The cybersecurity role engages for any change involving authentication, secrets, exposed endpoints, or data egress. The engagement is not a one-line sign-off — it's a review that produces specific findings (cleared or remediation tickets).

**Output:** green tests, validated acceptance, security sign-off where applicable. **Triggers Stage 5.**

## Stage 5: Deployment — devops

The devops role ships the change through the deploy pipeline. The pipeline is itself defined per [MAKE-NAMING.md](MAKE-NAMING.md) — `make aws-ecs-deploy-staging`, then `make aws-ecs-deploy-prod` after staging passes.

Deploy is not "press the button." It's:

1. Run the deploy target
2. Wait for healthchecks (`/healthz`, `/readyz`)
3. Verify smoke tests pass post-deploy
4. Confirm dashboards show no regression in the first 5 minutes

**Output:** code in target environment with healthchecks green and smoke tests passing. **Triggers Stage 6.**

## Stage 6: Observation — devops + delivery-lead

After deploy, the devops role watches dashboards for the next 24-48 hours; the delivery-lead confirms the feature delivers the value claimed in the Stage 1 acceptance criteria. If both pass, the feature is closed in PHASE-PLAN.

A feature is **shipped** when its code is in production. A feature is **delivered** when Stage 6 confirms it works in production as intended. Don't conflate the two.

## Cross-role engagement triggers

When does a feature engage more than its primary stage role? Concrete triggers:

| Trigger | Roles engaged |
|---|---|
| Schema or query change | architect + developer + data-engineer + tester |
| New endpoint | architect + developer + tester + cybersecurity |
| New external service integration | architect + developer + cybersecurity + devops |
| AI prompt or eval change | architect + ai-engineer + tester |
| Customer-facing UI | architect + ui-ux-designer + developer + tester |
| Infrastructure change | architect + devops + cybersecurity |
| Cost-significant change | architect + ai-engineer or devops + delivery-lead |

If no row matches, the feature is single-role. Most features touch 2-4 roles.

## Anti-patterns

- **Skipping intake.** Implementation that doesn't trace to a PHASE-PLAN entry produces scope drift. The intake artifact exists to make the contract explicit.
- **Architect-only "design."** Architect makes the call without engaging specialists, then specialists discover blockers mid-Stage-3. Engage specialists *before* committing to an approach.
- **Implementation without observability hooks.** Code that lands without log/metric/trace emission per `observability-contract.md` is observability theater — green tests, blind production.
- **Validation without cybersecurity sign-off on security changes.** Any auth/secrets/egress change requires cybersecurity in Stage 4, not retroactively after deploy.
- **Skipping Stage 6.** A feature that's "shipped" without observed-in-prod confirmation is deployed, not delivered. The delta is where production bugs live.
- **Parallel-stage shortcuts.** "We'll implement while the architect designs" produces implementations that diverge from the design. Stages are sequential for a reason.

## What this doc doesn't cover

This document is the happy path. The following are out of scope and belong to `role-delivery-lead.md` (lands in Chunk 5 of Phase 1):

- Escalations when a stage blocks
- Cross-phase features (when a feature spans two phase gates)
- Feature kill criteria
- Mid-flight scope changes
- Recovery patterns when a stage's output is rejected by the next stage

The delivery-lead owns those flows because they're variations on the protocol they enforce.
