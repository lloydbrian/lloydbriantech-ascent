# role-developer

> The developer role. [ADR-001](../../../docs/framework/DECISIONS/ADR-001-single-parent-skill.md) establishes the nine-role model; [ASCENT-INVARIANTS.md](ASCENT-INVARIANTS.md) §6 (strict backend layering) is the central invariant this role enforces.

The developer role covers both backend and frontend implementation. ADR-001's nine-role model has one "developer"; specialist engagement (data, AI, UI/UX) pairs in when the domain calls for it.

## What this role owns

- **Backend implementation** — routes, controllers, services, storage (per ASCENT-INVARIANTS.md §6)
- **Frontend implementation** — components, screens, state, integration with the backend
- **Agent task modules** — when the project includes AI agent capabilities, the orchestration code that runs tasks
- **Integration patterns** — consuming external services via wrappers (per [external-services-integration.md](external-services-integration.md))
- **Observability emission** — the hooks that produce the data [observability-contract.md](observability-contract.md) specifies
- **Tests written alongside implementation** — unit and integration; broader test discipline belongs to [role-tester.md](role-tester.md)

## When this role engages

| Trigger | Engagement |
|---|---|
| Stage 3 (per [feature-lifecycle.md](feature-lifecycle.md)) | Implement the design from Stage 2; pair specialists in as needed |
| Bug fix | Reproduce, locate, fix, regression-test |
| Refactor | Within the existing design; deviations require an architect engagement |
| Schema or query change | Pair with [role-data-engineer.md](role-data-engineer.md) |
| Prompt or eval change | Pair with [role-ai-engineer.md](role-ai-engineer.md) |
| Customer-facing surface | Pair with [role-ui-ux-designer.md](role-ui-ux-designer.md); implement to spec |

## Key practices

### Backend layering

The pipeline is `routes → controllers → services → storage`. Only the storage layer writes data. Controllers contain no business logic. Routes register only.

```
routes/          # HTTP method + path; calls the controller
  └─ controllers/   # Request validation, response shaping; calls services
       └─ services/    # Business logic; calls storage
            └─ storage/   # Database interaction; only layer that writes
```

Cross-layer calls are forbidden. A route calling storage directly is a violation; a service calling another service is fine; storage calling a service is a violation (storage doesn't know about business logic).

### Frontend conventions

Frontend code mirrors backend layering in spirit: components own rendering, hooks/composables own state and effects, services own external calls. UI components don't call APIs directly — they consume state from hooks or stores that own the network egress.

Visual implementation follows specs from `role-ui-ux-designer.md`. Tokens come from the design system, never hardcoded colors or spacings.

### Agent task modules

When the project ships an AI agent, task modules are the unit of agent capability. Each task module has:

- A clear input schema
- A clear output schema
- Observability hooks (every external call traced)
- An idempotency story when the operation has side effects
- An eval scenario validating the task's behavior (paired with `role-ai-engineer.md`)

Task modules live in `backend/agent/tasks/` per the architect's skeleton. The developer implements; the AI engineer pairs in for prompt and eval work.

### Integration patterns

Every external-service call goes through a client wrapper per external-services-integration.md. The wrapper owns retry, secrets-from-env, observability, fallback. The developer's job is to consume the wrapper's typed interface — never to import the vendor SDK directly into route handlers.

### Observability emission

The developer implements emission hooks per observability-contract.md:

- Structured logger calls (level, ts, trace_id, msg, ctx)
- Metrics middleware on the HTTP layer
- Trace propagation in inbound and outbound requests
- `/healthz` and `/readyz` handlers
- Lifecycle event emissions on startup/shutdown

Emission is the developer's job; collection and alerting belong to [role-devops.md](role-devops.md). The boundary is the wire format.

### Tests written alongside implementation

Every implementation lands with tests. Unit tests cover the service-layer logic; integration tests cover the controller → service → storage path. The acceptance criteria from Stage 1 drive what's tested; the developer writes the tests, then `role-tester.md` validates that the tests cover the criteria and extends with broader discipline (e2e, contract, load, security).

## Hand-offs

**Upstream (developer receives from):**

- [role-architect.md](role-architect.md) — design, with or without ADR
- Specialists when they paired in at design time

**Downstream (developer hands to):**

- [role-tester.md](role-tester.md) — implementation with unit/integration tests
- [role-devops.md](role-devops.md) indirectly — code that emits per the observability contract

## Anti-patterns

- **Cross-layer calls.** Routes touching storage; storage importing service logic. Refactor or supersede the invariant with an ADR.
- **SDK in route handlers.** Vendor SDK imported into application code outside its wrapper. Layering violation.
- **Hardcoded colors / spacings / sizes in frontend code.** Use design tokens; deviation requires updating the design system, not bypassing it.
- **Observability hooks added "later."** Code lands without log/metric/trace emission. Bug-debugging in production becomes blind.
- **Tests written after the feature is "done."** Tests should grow with the implementation; bolting them on at the end produces tests that match the bugs they were written around.
- **Refactor without architect.** Substantial restructuring that changes the design. Either the design wasn't right (engage architect) or the refactor is gratuitous.

## What this role doesn't own

- **Design.** That's [role-architect.md](role-architect.md). The developer implements designs; design questions go back to the architect.
- **Test strategy across the project.** That's [role-tester.md](role-tester.md). The developer writes tests for their code; the tester owns coverage discipline.
- **Visual design.** That's [role-ui-ux-designer.md](role-ui-ux-designer.md). The developer implements specs faithfully.
- **Deploy.** That's [role-devops.md](role-devops.md). Code lands; devops ships it.

## Cross-references

- `ASCENT-INVARIANTS.md` §6 — backend layering
- `observability-contract.md` — emission baseline
- `external-services-integration.md` — vendor wrapper pattern
- `feature-lifecycle.md` Stage 3 — the developer's standard engagement
