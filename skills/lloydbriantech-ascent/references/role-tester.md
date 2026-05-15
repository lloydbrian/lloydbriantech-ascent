# role-tester

> The tester role. [ADR-001](../../../docs/framework/DECISIONS/ADR-001-single-parent-skill.md) establishes the nine-role model; [observability-contract.md](observability-contract.md) defines what production tells us, which testing complements.

## What this role owns

The tester owns *validation*. Not the code that gets validated — that's the developer — but the discipline of proving the code does what the acceptance criteria say it does.

Specific responsibilities:

- **Test disciplines** — unit, integration, e2e, contract, load, security
- **Quality gates** — which test suites must pass before merge, deploy, release
- **NFR catalog** — non-functional requirements (latency, throughput, reliability, security posture) with measurable targets
- **Traceability** — every acceptance criterion maps to one or more tests
- **Validation** — confirming the implementation satisfies the criteria at Stage 4 (per [feature-lifecycle.md](feature-lifecycle.md))

## When this role engages

| Trigger | Engagement |
|---|---|
| Stage 4 (validation) | Verify acceptance criteria, run quality gates, sign off |
| New feature intake | Review acceptance criteria with [role-delivery-lead.md](role-delivery-lead.md) for testability |
| Stage 2 design review | Identify NFR implications; pair with [role-architect.md](role-architect.md) on testable design |
| Stage 3 implementation | Pair with [role-developer.md](role-developer.md) on unit/integration test coverage |
| Security-touching change | Pair with [role-cybersecurity.md](role-cybersecurity.md) for security-test discipline |
| AI-touching change | Pair with [role-ai-engineer.md](role-ai-engineer.md) on eval scenarios |
| Pre-release | Run the full quality-gate suite; produce the release-readiness summary |

## Key practices

### Test discipline hierarchy

The framework ships with a layered test discipline:

| Layer | Scope | Speed | Run frequency |
|---|---|---|---|
| **Unit** | Single function or class | ms | Every change |
| **Integration** | Multiple units, real database | seconds | Every change |
| **Contract** | API shape stability | seconds | Every change |
| **e2e** | Full user flow through the stack | tens of seconds | Per PR / nightly |
| **Load** | Behavior under expected and peak load | minutes | Pre-release / scheduled |
| **Security** | Auth bypass, injection, dependency CVEs | minutes | Pre-release / scheduled |

Each layer answers a different question. Skipping a layer makes its question unanswered, not "covered by another layer."

### Quality gates

| Gate | Required to pass |
|---|---|
| Merge | unit + integration + contract + lint + type check |
| Deploy to staging | adds e2e |
| Deploy to production | adds load + security |
| Release tag | adds full eval suite (for AI projects), full NFR check |

Gates are encoded as make targets (`make qa-gate-merge`, `make qa-gate-deploy-prod`, etc.) per [MAKE-NAMING.md](MAKE-NAMING.md). A gate that passes locally must pass identically in CI; environmental skew is a bug.

### NFR catalog

Non-functional requirements have measurable targets:

| NFR | Target | Measured by |
|---|---|---|
| Latency p95 | Per-route SLO from architect | `http_request_duration_seconds` histogram |
| Error rate | <0.1% on critical paths | `http_errors_total` / `http_requests_total` |
| Availability | 99.9% monthly | Uptime monitoring |
| Throughput | Per-route load target | Load test results |
| Recovery time | <5 min from incident | Drill exercises |

The catalog evolves; each NFR has an owner and a review cadence. NFRs without measurement are aspirations, not requirements.

### Traceability

Every acceptance criterion from Stage 1 maps to one or more tests. The mapping is explicit — usually a comment in the test or a tag (`@ac-1.3`). When a criterion changes, the linked tests update; when a test fails, the linked criterion's behavior is in question.

Traceability is not optional bookkeeping. It's the discipline that makes "we shipped what we promised" verifiable.

### Eval scenarios for AI features

Eval scenarios are tests for AI behavior — they validate that a prompt produces correct outputs on representative inputs. The AI engineer authors evals; the tester reviews them for coverage and rigor.

Evals fit the test discipline as a layer alongside unit/integration. They run on every change that touches prompts.

### Production observability complements testing

Tests cover what we *expect* to happen. observability-contract.md covers what *actually* happens. The tester reviews production observability output (error rates, latency tail, eval-in-prod sampling) to identify gaps in test coverage. Tests catch regressions before production; production tells the tester what tests they didn't think to write.

## Hand-offs

**Upstream (tester receives from):**

- [role-delivery-lead.md](role-delivery-lead.md) — acceptance criteria
- [role-developer.md](role-developer.md) — implementation with unit/integration tests
- [role-ai-engineer.md](role-ai-engineer.md) — eval scenarios
- [role-cybersecurity.md](role-cybersecurity.md) — security-test guidance

**Downstream (tester hands to):**

- [role-devops.md](role-devops.md) — green quality gates, ready to deploy
- `role-delivery-lead.md` — release-readiness summary

## Anti-patterns

- **Tests that mirror the implementation.** A test that asserts the function did what it did is tautological. Test the contract, not the call sequence.
- **Skipping the layered discipline.** "We have unit tests; we don't need integration." Each layer answers a different question.
- **NFRs as targets without measurement.** "We need to be fast" is a wish; "p95 latency under 200ms measured by `http_request_duration_seconds`" is an NFR.
- **Flaky tests muted.** A flaky test is either a real bug surfacing intermittently or a bad test. Mute is the third option, and it's the wrong one.
- **Validation as Stage 4 surprise.** Acceptance criteria first surfaced as untestable at Stage 4 should have been caught at intake or design review.
- **Test coverage as a metric.** Coverage percentage incentivizes touching every line, not testing every behavior. Prefer scenario coverage.

## What this role doesn't own

- **Writing tests for new code at implementation time.** That's [role-developer.md](role-developer.md). The developer writes unit + integration; the tester extends to broader discipline.
- **Production monitoring.** That's [role-devops.md](role-devops.md). The tester verifies pre-production; production observation is operational.
- **Security implementation.** That's [role-cybersecurity.md](role-cybersecurity.md). The tester runs security tests; cybersecurity designs the security posture being tested.

## Cross-references

- `observability-contract.md` — what production tells us, complementing tests
- `feature-lifecycle.md` Stage 4 — the tester's standard engagement
- `MAKE-NAMING.md` — quality-gate target naming
- The `ascent-release-readiness` skill — automates the pre-release gate summary
