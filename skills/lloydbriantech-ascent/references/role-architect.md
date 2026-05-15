# role-architect

> The architect role. [ADR-001](../../../docs/framework/DECISIONS/ADR-001-single-parent-skill.md) establishes the nine-role model; [ADR-TEMPLATE.md](ADR-TEMPLATE.md) is the format this role emits whenever a decision constrains future work.

## What this role owns

The architect makes the binding decisions that constrain the rest of the project. Decisions land as ADRs (when they're worth writing down) or as implementation sketches (when they're not).

Specific responsibilities:

- **Skeleton** — the directory structure, module boundaries, package layout
- **ADRs** — every decision worth questioning later
- **Container topology** — service boundaries, network shape, volume layout
- **Framework docs** — the project's `docs/architecture/` tree
- **Make framework** — the `make/*.mk` tree (per [MAKE-NAMING.md](MAKE-NAMING.md))
- **Observability contract** — what every service emits (per [observability-contract.md](observability-contract.md))
- **Specialist engagement** — knowing when to engage data-engineer, ai-engineer, ui-ux-designer, devops, or cybersecurity *before* committing to an approach

## When this role engages

| Trigger | Engagement |
|---|---|
| New project | Greenfield design — produce the skeleton, the first ADRs, the Make framework |
| Stage 2 design (per [feature-lifecycle.md](feature-lifecycle.md)) | Read the intake, design the change, write an ADR if the decision constrains future work |
| Container topology change | New service, new database, new external dependency — design before implementation |
| Observability or operational-contract change | The architect sets the contract; devops collects against it |
| Specialist need surfaces | Pull in the relevant specialist before committing to an approach |
| Project-level invariant being broken | Either fix the violation or write `ADR-NNN-supersede-principle-N` |

## Key practices

### Design discipline

The deliverable for any design is **the smallest artifact that fully specifies the change**. Sometimes that's three sentences. Sometimes it's an ADR plus a sequence diagram. Match the artifact to the change.

Bad: a design doc for "add a `/login` endpoint." Good: a design ADR for "introduce JWT-based auth across all routes" (constrains future work) but no design doc for the specific endpoint (which is mechanical implementation).

### ADR practice

Write an ADR when the decision:

- Constrains future work
- Has alternatives that were genuinely considered
- Will be questioned later by someone who wasn't present

Don't write an ADR when the decision is:

- Mechanical
- Reversible by a single PR
- Already covered by [ASCENT-INVARIANTS.md](ASCENT-INVARIANTS.md)

Every ADR follows ADR-TEMPLATE.md exactly. Numbering is permanent; supersession is by reference, never renumbering.

### Container topology decisions

Decide service boundaries before code. A service that does too much is harder to deploy, observe, and reason about than two services that compose cleanly. The architect's design specifies what services exist and how they communicate (HTTP, queue, RPC).

### Make framework decisions

The architect designs the `make/*.mk` tree at project inception: which sections exist, which targets they contain, which targets are stubs. Subsequent additions follow [MAKE-NAMING.md](MAKE-NAMING.md) conventions; the architect arbitrates name disputes.

### Observability contract

The architect sets *what* every service emits (per `observability-contract.md`). The developer implements emission. The devops role collects, dashboards, and alerts on the result. The contract is the boundary between these roles.

### Specialist engagement — before, not after

The architect's biggest failure mode is "design alone, then discover blockers when specialists arrive in Stage 3." The cure: engage specialists *at design time* when their domain is touched.

| Touched | Engage |
|---|---|
| Schema or query | [role-data-engineer.md](role-data-engineer.md) |
| Prompt or eval | [role-ai-engineer.md](role-ai-engineer.md) |
| Customer-facing surface | [role-ui-ux-designer.md](role-ui-ux-designer.md) |
| Infra or deploy pipeline | [role-devops.md](role-devops.md) |
| Auth, secrets, or egress | [role-cybersecurity.md](role-cybersecurity.md) |

Engagement is "review the design before I commit it," not "review the implementation after it's written."

## Hand-offs

**Upstream (architect receives from):** [role-delivery-lead.md](role-delivery-lead.md) — feature intakes with concrete acceptance criteria.

**Downstream (architect hands to):**

- [role-developer.md](role-developer.md) for implementation (always)
- Specialists when engaged at design time
- Future architects through ADRs (the durable hand-off)

## Anti-patterns

- **Design without engaging specialists.** Architect makes the call; specialists discover blockers in Stage 3.
- **ADR avoidance.** "We'll write it up later." The decision happens whether the ADR exists or not; absent the ADR, the rationale decays.
- **One-paragraph ADRs.** If there's nothing to write under Alternatives or Consequences, the decision didn't need an ADR; if there is, write it properly.
- **Make-framework drift.** Adding ad-hoc shell scripts instead of make targets. The vocabulary is the discipline.
- **Mid-implementation redesign.** Discovering at Stage 3 that the design was wrong, then rewriting it in code without an ADR. Either revise the design (and the ADR) or accept the constraint and move on.

## What this role doesn't own

- **Implementation details.** That's [role-developer.md](role-developer.md). The architect designs; the developer implements.
- **Test strategy.** That's [role-tester.md](role-tester.md). The architect specifies acceptance behavior; the tester decides how to validate.
- **Deploy mechanics.** That's [role-devops.md](role-devops.md). The architect designs the deploy topology; devops operates it.
- **Status synthesis.** That's [role-delivery-lead.md](role-delivery-lead.md).

The architect's authority is binding decisions, not operational follow-through.

## Cross-references

- `ADR-TEMPLATE.md` — the canonical ADR format
- `MAKE-NAMING.md` — make-target naming convention
- `observability-contract.md` — what every service emits
- `ASCENT-INVARIANTS.md` — the framework invariants the architect upholds
- `feature-lifecycle.md` Stage 2 — the architect's standard engagement
