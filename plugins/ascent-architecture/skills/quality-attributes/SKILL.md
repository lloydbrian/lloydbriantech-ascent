---
name: quality-attributes
description: >-
  Use when asked "score the -ilities", "what are our quality targets?", "are we
  meeting availability, latency, RTO/RPO or budget?", or when architecture-review
  flags two or more attributes at risk. Sets measurable targets in the project
  contract, scores each quality attribute as met, at risk or unmeasured with
  file evidence, and ranks the gaps. Read-only.
version: 0.1.2
allowed-tools: Read, Grep, Glob
---

# quality-attributes

A scored review of the system's quality attributes (the "-ilities") against measurable targets. It is a sibling of [architecture-review](../architecture-review/SKILL.md): both read the contract and [architecture-principles.md](../../references/architecture-principles.md), and neither invokes the other. Severities come from the table in architecture-review.

A quality attribute without a number is a wish. This skill's first job is to turn wishes into targets the team can measure; its second is to show, with evidence, whether the design can meet them.

## The attributes

The list combines ISO/IEC 25010:2023 product quality characteristics with the operational attributes cloud reviews add. Use only the ones that matter for this system, and say which you skipped and why.

| Attribute | Measurable target (examples) | Evidence that supports it |
|---|---|---|
| Functional suitability | acceptance criteria met; core rules covered by tests | Tests mapped to requirements; the delivery loop's definition of done |
| Availability | 99.9% monthly at the entry point | Managed multi-AZ services; health checks; no single instance; CDN serving cached content during origin failure |
| Reliability and recoverability | RPO 24h, RTO 4h; restore tested on a date | Point-in-time recovery or backups; `DeletionPolicy: Retain`; a restore runbook with a dated test |
| Performance efficiency | p95 latency 500 ms; time to first byte | CDN and cache policy; payload size; cold-start settings; database access patterns (no scans on hot paths) |
| Scalability (capacity) | sustained peak requests per second | On-demand or autoscaling services; throttling set above peak and below the budget's limit |
| Security | `ascent-security` rating strong; TLS 1.2+ | Private origins; headers; least-privilege roles; secrets in a store |
| Cost efficiency | monthly budget in USD; cost per 1,000 users | Dated estimate (deployment-options Step 3); budget alert; scale to zero; log retention |
| Operability and observability | time to detect; alarm routed to a person | Alarms on errors, latency, saturation; structured logs; build stamp; runbooks |
| Maintainability | change lead time; test coverage of core rules | Layering; tests; IaC; ADRs; small modules |
| Flexibility (portability) | services with a named exit path | Standard protocols; IaC; data export path; [cloud-component-mapping.md](../../references/cloud-component-mapping.md) equivalents |
| Interaction capability (usability, accessibility) | WCAG 2.2 AA; task success | Owned by the `ascent-ux` plugin (`ux-review`, `accessibility-audit`) and `design:accessibility-review`; list here, do not score |
| Compatibility | supported browsers and clients; API versioning | Versioned or additive-only API contracts; browser support statement |
| Sustainability | idle capacity near zero | Serverless or right-sized resources; arm64 where available |
| Safety | no harm to people or equipment when the system fails | Fail-safe defaults; human confirmation for physical or irreversible actions; usually out of scope for web systems, so say so |

## Steps

### Step 1 — Targets

Read `architecture.quality_targets` from `.ascent/contract.yml` (or `.claude/contract.yml`). For each attribute that matters and has no target, **propose one** from what the repository and docs imply (traffic, audience, business hours, existing SLOs), marked `# guess`. Present the proposals as a YAML block for the operator to confirm and commit. Do not write the file.

A missing target is scored **unmeasured** (Low at the enterprise target), never assumed met.

### Step 2 — Evidence per attribute

For each attribute in scope, collect evidence with `file:line` references from IaC, configuration, code and docs, using the evidence column above. Where the evidence needs a running system (actual latency, actual availability), say exactly what to measure and where: a CloudWatch metric, the CDN report, a load test. Do not guess numbers.

When the project has a CloudFormation template on the static-site pattern, the mechanical checks in architecture-review Step 4 give direct evidence for security, recoverability, cost and observability. Reuse their output; do not re-derive it.

### Step 3 — Score

| Status | Meaning |
|---|---|
| **met** | The design can meet the target, and evidence shows it (or a measurement does) |
| **at risk** | A specific gap could miss the target; name the gap and the scenario |
| **unmeasured** | No target, or no way to tell yet; name the measurement that would settle it |

Each **at risk** attribute becomes a finding, rated with the architecture-review severity table. The attribute's importance to the users decides the order, not the table alone.

### Step 4 — Report and next steps

```
quality-attributes: <met>/<in scope> met, <r> at risk, <u> unmeasured
Contract targets: <path or "proposed below">

| Attribute | Target | Status | Evidence | Gap / measurement |
|---|---|---|---|---|

Findings: <architecture-review format, most severe first>
Proposed targets (confirm and commit): <YAML block, or "none">
Trade-offs: <where two attributes pull against each other, e.g. cost vs availability, and the recommended balance>
```

Name the trade-offs explicitly. A second region raises availability and doubles cost; a longer cache TTL lowers cost and latency and delays content updates. The operator decides; record the decision in an ADR when it is a one-way door.

## What this skill does not do

- Measure a live system or run load tests. It names the measurement; the operator or a delivery loop runs it.
- Edit the contract. It proposes targets for the operator to commit.
- Score accessibility or usability in depth: that is the `ascent-ux` plugin and `design:accessibility-review`.
