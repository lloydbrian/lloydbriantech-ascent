# Architecture principles

The shared source for every `ascent-architecture` skill and the `architecture-reviewer` agent. Skills read this file; they never call each other (the sibling pattern). Each principle names the evidence that shows it is met, so a review can cite files instead of opinions.

## 1. System principles (vendor-neutral)

| # | Principle | Evidence that it is met |
|---|---|---|
| P1 | **Design for failure.** Every dependency can be slow or down. | Timeouts on outbound calls; retries with backoff only on idempotent operations; graceful degradation (cached or static fallback); a documented RTO and RPO. |
| P2 | **Least privilege, defense in depth.** | IAM roles scoped to named resources (no `*` actions on `*`); private origins; network and identity controls in layers; secrets in a secret store, never in code. |
| P3 | **Everything as code.** | Infrastructure in IaC (CloudFormation, CDK, Terraform, Bicep) under version control; no production resource created only by hand; repeatable environments. |
| P4 | **Loose coupling, high cohesion.** | Components talk through stable contracts (HTTP APIs, events, queues); no shared database between services; each module has one reason to change. |
| P5 | **Stateless compute, state in managed stores.** | No session state on servers or functions; state in a database, cache or object store; any instance can serve any request. |
| P6 | **Managed over self-managed.** | Prefer serverless and managed services unless a requirement rules them out; every self-managed component has a named reason. |
| P7 | **Observable by default.** | Structured logs with retention; metrics and alarms for errors, latency and saturation; alarms route to a person; a build stamp proves what is deployed. |
| P8 | **Cost is an architecture attribute.** | A dated cost estimate; a budget with alerts; scale-to-zero where traffic is idle; throttling on public entry points; no unbounded log or storage growth. |
| P9 | **Secure by design.** | TLS 1.2+ in transit; encryption at rest; security headers; input validated at the boundary; dependencies scanned (`ascent-security`). |
| P10 | **Reversible by default; one-way doors get an ADR.** | Data migrations, deletions, public API changes and vendor commitments have an ADR with a rollback or exit plan. |
| P11 | **Protect the data.** | Backups or point-in-time recovery; retention on delete (`DeletionPolicy: Retain`); a restore that has been tested at least once. |
| P12 | **Simplest thing that meets the targets.** | Every component maps to a requirement or a quality target; no speculative tiers, clusters or services. |

## 2. AWS Well-Architected Framework (six pillars)

Use the pillars as the review checklist for AWS workloads; the same questions apply on any cloud.

| Pillar | Review question | Principles |
|---|---|---|
| Operational excellence | Can we deploy, observe and recover without heroics? Are runbooks current? | P3, P7, P10 |
| Security | Is every identity least-privilege, every data path encrypted, every secret out of code? | P2, P9 |
| Reliability | What fails, how do we know, and how fast do we recover (RTO/RPO)? | P1, P5, P11 |
| Performance efficiency | Is the right resource type serving each workload, close to users? | P5, P6, P12 |
| Cost optimization | Do we know the monthly cost, its drivers, and who is alerted when it moves? | P8, P12 |
| Sustainability | Do we scale to zero, right-size, and avoid idle capacity? | P6, P8 |

## 3. Solutions Architect Professional lens

The AWS Certified Solutions Architect – Professional exam groups design work into four domains. Use them to frame larger reviews:

1. **Design solutions for organizational complexity.** Multi-account structure (AWS Organizations, landing zone), service control policies, cross-account access, centralized logging and networking.
2. **Design for new solutions.** Requirements to architecture: quality targets, deployment strategy, business continuity, security controls, performance and cost.
3. **Continuously improve existing solutions.** Operational excellence, security, reliability, performance and cost improvements to what already runs.
4. **Accelerate workload migration and modernization.** Portfolio assessment and the 7 Rs: retire, retain, rehost, relocate, repurchase, replatform, refactor.

For a single small project, domain 2 dominates; flag domain 1 when the project shares an account with unrelated workloads (blast radius, budget and IAM separation).

## 4. Software design principles

| Principle | What to look for | Smell |
|---|---|---|
| Separation of concerns (MVC, layered) | Presentation, application logic and data access live in separate modules; routes/controllers stay thin | SQL or HTTP calls in UI components; business rules in route handlers |
| Hexagonal (ports and adapters) | The domain imports no framework, database or SDK; adapters implement interfaces the domain owns | Domain code importing `express`, `aws-sdk`, ORM models |
| SOLID (object-oriented code) | Single responsibility; open for extension through interfaces; substitutable subtypes; small interfaces; depend on abstractions | God classes; `instanceof` switches; subclasses that throw "not supported" |
| DRY, KISS, YAGNI | One home for each rule; the simplest working design; no unused extension points | The same rule in two places drifting apart; frameworks for one use |
| Twelve-factor app | One codebase; explicit dependencies; config in the environment; backing services as attached resources; separate build, release, run; stateless processes; port binding; scale by processes; fast startup and graceful shutdown; dev/prod parity; logs as event streams; admin tasks as one-off processes | Hardcoded hosts or keys; local file state; environment-specific code paths |
| API design | Versioned or additive-only contracts; idempotent writes (keys or PUT); consistent errors; pagination; validation at the edge | Breaking field renames; retries that create duplicates; unbounded list endpoints |
| Errors and resilience | Errors carry context (ids), are logged once, and map to the right status; no swallowed exceptions | `catch {}`; generic 500s with no log; retry loops without limits |

## 5. Maturity targets

Every project defaults to the **enterprise** target (decision 10, 2026-10-18). A project may choose a lower target, but each skipped item is then a recorded **waiver** in an ADR, listed under `architecture.waivers` in the contract.

| Item | Prototype | Standard | Enterprise (default) |
|---|---|---|---|
| Infrastructure as code | optional | required | required, reviewed in PRs |
| Environments | one | beta + prod | beta + prod, prod promoted from beta |
| Backups or point-in-time recovery | — | enabled | enabled, restore tested and dated |
| Monitoring | — | error alarm | alarms on errors, latency and saturation, routed to a person; SLOs |
| Cost guardrail | — | budget alert | budget alert, dated estimate, throttling on public entry points |
| Security baseline | secrets out of code | + TLS, headers, least privilege | + `ascent-security` strong rating, dependency scanning |
| Decisions | — | ADRs for one-way doors | ADRs for one-way doors and every waiver |
| Operations | — | deploy and rollback runbooks; a current Maintenance and Operations Manual | deploy, rollback and incident runbooks with pre-flight and post-flight checks; current Maintenance and Operations and Troubleshooting manuals with diagrams and a dependency map; secure configuration (S1–S10); checked in depth by `ascent-ops` |
