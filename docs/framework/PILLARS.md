# Pillars and quality attributes

**For:** anyone deciding whether ASCENT covers what their organization asks of software, and contributors choosing what a new plugin or rule should close.

ASCENT's checks serve four outcomes: driving business value, compliance, trust and security, and resilience. This page maps each one to the quality attributes (the "-ilities") behind it, the plugin or skill that checks each attribute, the evidence it produces, and what is not covered yet.

Every review is read-only. The architecture, ux and ops plugins judge against the targets in the project contract, `.ascent/contract.yml`, and an attribute with no target is reported as **unmeasured**, never as met. `ascent-delivery` reads its own contract, `.delivery-loop.yml`.

---

## The four pillars at a glance

| Pillar | Question it answers | Main plugins | Coverage |
|---|---|---|---|
| **Driving business value** | Does the system deliver what users need at a cost and speed the business can sustain? | `ascent-architecture`, `ascent-delivery`, `ascent-ux` | Partial: cost and delivery speed are measured; the outcome a change achieves is not |
| **Compliance** | Can the team show evidence against the standards it must meet? | `ascent-ux`, `ascent-ops`, `ascent-security` | Partial by design: evidence for WCAG 2.2 AA and secure configuration; no certification preparation |
| **Trust and security** | Can users and operators trust the system with their data and their infrastructure? | `ascent-security`, `ascent-delivery`, `ascent-ops` | Partial: secrets, hardening and posture are strong; no threat model and no scan for known vulnerabilities |
| **Resilience** | Does the system keep running, and recover quickly when it does not? | `ascent-ops`, `ascent-architecture`, `ascent-delivery` | Partial: recovery is checked as documented, not yet proven by a drill |

Coverage levels:
- **Strong:** checked with evidence, behavior tests and negative controls.
- **Partial:** some attributes are checked; the gaps are listed below.
- **Gap:** nothing checks it yet.

---

## Quality attributes by pillar

The attribute names follow the list in [`quality-attributes`](../../plugins/ascent-architecture/skills/quality-attributes/SKILL.md), which combines ISO/IEC 25010:2023 with the operational attributes cloud reviews add. Each attribute sits under the pillar it serves most; several serve more than one.

### Driving business value

| Attribute | Checked by | Evidence | Status |
|---|---|---|---|
| Functional suitability | `ascent-delivery` (definition of done); `quality-attributes` | Each acceptance criterion mapped to a test or a recorded manual check | Partial: the rule is stated, but has no behavior tests or negative controls yet |
| Cost efficiency | `deployment-options`; `architecture-review` (ARC-C11, budget alert); `quality-attributes`; embedded `ascent-cost-posture` | A dated monthly estimate against `monthly_budget_usd`; budget alert in the IaC | Strong |
| Performance efficiency | `quality-attributes`; `ascent-ux` (Core Web Vitals) | `p95_latency_ms` target; CDN and cache policy; Core Web Vitals against a stated budget | Partial: read from design and config, not measured under load |
| Scalability (capacity) | `quality-attributes` | `peak_rps` target; autoscaling or on-demand services; throttling limits | Partial: no load test |
| Interaction capability (usability) | `ascent-ux` (`ux-review`) | Heuristic findings on core flows; error, empty and loading states | Partial: no task-success measurement |
| Maintainability | `design-principles-check`; embedded `ascent-layering-check` | Layering, coupling and twelve-factor findings with `file:line` | Partial: layering has negative controls; coupling and twelve-factor findings do not |
| Delivery speed | `ascent-delivery` release log | Lead time and change-failure rate per release (DORA) | Partial: deploy frequency and time to restore come from the log's history |
| Outcome of a change | — | — | **Gap:** nothing measures whether a change achieved what it was for |

### Compliance

| Attribute | Checked by | Evidence | Status |
|---|---|---|---|
| Accessibility (WCAG 2.2 AA) | `ascent-ux` (`accessibility-audit`, `design-system-check`) | A criterion-by-criterion table; exact token contrast in every theme; a Playwright pass | Strong, and never stated as legal compliance |
| Secure configuration | `ascent-ops` (`iac-config-check`, OPS-S1–S10) | Rules OPS-S1–S10 against the IaC with `file:line`; `trivy config` when installed | Strong |
| Decision traceability | embedded `ascent-adr-conformance`, `ascent-adr-write` | ADRs for every constraining decision, and the code checked against them | Partial: scaffolded projects only, no negative controls yet |
| Change audit trail | `ascent-delivery` | Runbooks, hash manifests and the release log for every shipped change | Partial: the rule is stated, but has no behavior tests or negative controls yet |
| Version pinning | `ascent-ops` (OPS-Z8, `sre-baseline.md`); `ascent-security` (`dependency-check`, SEC-D1–D3) | Images, packages, providers and actions pinned; npm and Python manifests pinned and locked, lockfiles in step | Strong: package manifests tested under exact and minor ([ADR-016](DECISIONS/ADR-016-dependency-checks-in-ascent-security.md)); for images, providers and actions, exact pinning is read, not tested |
| Regulatory regimes (HIPAA, PCI-DSS, SOC 2) | — | — | **Out of scope:** see [SCOPE.md](SCOPE.md). ASCENT produces evidence an auditor can use; it does not prepare certification |

### Trust and security

| Attribute | Checked by | Evidence | Status |
|---|---|---|---|
| Secret handling | `ascent-security` (`env-audit`, `security-audit`) | `.env` scope, hardcoded credentials, images built without secrets; values always redacted | Strong |
| Runtime hardening | `ascent-security` (`security-audit`) | Container privilege, nginx security headers, production URL schemes, dynamic code execution | Strong |
| Infrastructure hardening | `ascent-ops` (`iac-config-check`) | Secrets from a store, sensitive parameters masked, remote encrypted and locked state, no wildcard IAM actions, secret rotation | Strong |
| Security posture | `ascent-security` (`sec-posture`); `quality-attributes` (Security) | One rating across the surfaces, with the gaps named | Strong |
| Operator boundary and privacy | `ascent-delivery` hook and privacy rules | Claude cannot commit, push or deploy; credentials and personal data never stored | Strong |
| AI behavior | embedded `ascent-ai-evals` | Eval cases for AI features | Partial: scaffolded projects only |
| Dependency vulnerabilities and supply chain | `ascent-security` (`dependency-check`, SEC-D1–D10); embedded `ascent-dependency-health` | Lockfiles, sources and licences; an offline trivy scan of lockfiles and local images with the database date; scanner ignore entries tied to waiver ADRs | Strong with trivy and a current database; Partial without one (the scan is reported unmeasured) ([ADR-016](DECISIONS/ADR-016-dependency-checks-in-ascent-security.md)) |
| Security testing (live) | — | — | **Gap, committed:** `ascent-security` 0.3.0, operator-run ([ROADMAP.md](ROADMAP.md#committed-follow-ups)) |
| Threat model | — | — | **Gap** |

### Resilience

| Attribute | Checked by | Evidence | Status |
|---|---|---|---|
| Availability | `quality-attributes`; `ascent-ops` (Health and SLOs) | `availability` target; no single instance; health and readiness probes at `/-/health` and `/-/ready` | Partial: read from design and config |
| Operability and observability | `ascent-ops` (`ops-review`, `ops-manuals`); embedded `ascent-observability-check` | SLOs, alerts linked to runbooks, current Maintenance and Troubleshooting manuals | Strong |
| Change safety | `ascent-ops` (`runbook-check`); `ascent-delivery` | Zero-touch scripts (OPS-Z1–Z9); runbooks with pre-flight, post-flight, Expect and Stop if; beta before prod | Strong |
| Rollback | `ascent-ops` (Change and recovery) | A documented rollback for every production deploy | Strong as documentation |
| Recoverability (RPO, RTO) | `quality-attributes`; `ascent-ops` (Change and recovery) | `rpo` and `rto` targets; backups and retention; the date of the last restore test | Partial: the date is read, the restore is not proven |
| Restore and failover proof | — | — | **Gap, committed:** see [ROADMAP.md](ROADMAP.md#committed-follow-ups) |
| Drift | `ascent-ops` (OPS-S9) | A scheduled drift check | Strong |
| Flexibility (portability) | `quality-attributes`; `deployment-options` | Services with a named exit path; equivalents in other clouds | Partial |

---

## Attributes not mapped to a pillar

- **Compatibility** (browsers, clients, API versioning): `quality-attributes` scores it when the contract names a target.
- **Sustainability** (idle capacity): `quality-attributes` scores it; `deployment-options` favors scale-to-zero.
- **Safety** (harm to people or equipment): usually out of scope for web systems; `quality-attributes` says so when it is skipped.

## How this page stays true

- A new plugin, skill or rule that closes a gap updates its row here in the same pull request.
- `make test-plugins` (T13.9) fails when the "Checked by" column names a plugin, or a plugin's skill, that is not in [OWNERSHIP.md](OWNERSHIP.md) or the template.
- A status changes to **Strong** only when the check has behavior tests and negative controls, which is the bar in [CONTRIBUTING.md](../../CONTRIBUTING.md#contributing-a-plugin).
- The gaps are the input for scoping the next plugins in [ROADMAP.md](ROADMAP.md#plugin-roadmap).
