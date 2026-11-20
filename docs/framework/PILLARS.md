# Pillars and quality attributes

**For:** anyone deciding whether ASCENT covers what their organization asks of software, and contributors choosing what a new plugin or rule should close.

ASCENT's checks serve four outcomes: driving business value, compliance, trust and security, and resilience. This page maps each one to the quality attributes (the "-ilities") behind it, the plugin or skill that checks each attribute, the evidence it produces, and what is not covered yet.

Every review is read-only. The architecture, ux, ops, quality and security plugins judge against the targets in the project contract, `.ascent/contract.yml`, and an attribute with no target is reported as **unmeasured**, never as met. `ascent-delivery` reads the contract's `delivery:` section for its commands and acceptors, and still reads an older `.delivery-loop.yml`. `ascent-governance` reads the `governance:` section for what each launch needs, and judges nothing itself: it checks that the other plugins' evidence exists and is current.

---

## The four pillars at a glance

| Pillar | Question it answers | Main plugins | Coverage |
|---|---|---|---|
| **Driving business value** | Does the system deliver what users need at a cost and speed the business can sustain? | `ascent-architecture`, `ascent-delivery`, `ascent-ux`, `ascent-quality`, `ascent-session`, `ascent-docs`, `ascent-governance` | Partial: cost, delivery speed and launch readiness are measured; the outcome a change achieves is not |
| **Compliance** | Can the team show evidence against the standards it must meet? | `ascent-ux`, `ascent-ops`, `ascent-security`, `ascent-adr`, `ascent-governance` | Partial by design: evidence for WCAG 2.2 AA and secure configuration, waivers with review dates, dated review records and signed launch records; no certification preparation |
| **Trust and security** | Can users and operators trust the system with their data and their infrastructure? | `ascent-security`, `ascent-delivery`, `ascent-ops` | Partial: secrets, hardening and posture are strong; the threat model and live security testing are checked, and their evidence depends on the operator's runs and a person's review |
| **Resilience** | Does the system keep running, and recover quickly when it does not? | `ascent-ops`, `ascent-architecture`, `ascent-delivery`, `ascent-quality` | Partial: restore, failover and readiness are proven by the operator's drill records; availability and portability are read from design and configuration |

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
| Functional suitability | `ascent-quality` (`test-check`, QA-T1–T4; `test-inventory`, QA-I1–I5; `test-evidence`, QA-M1–M4); `ascent-delivery` (definition of done; the acceptance record, DEL-A1–A3); `quality-attributes` | Each acceptance criterion and core rule named by a test, and accepted by a person on beta before prod; the required test types present and run in CI; no focused, assertion-less or unexplained skipped tests; a current mutation score in the repository at `min_score` | Strong: traceability, test types and hygiene have behavior tests and negative controls, and the mutation score shows the tests fail when the code is broken; whether a test checks what its criterion says is read, not measured |
| Cost efficiency | `deployment-options`; `architecture-review` (ARC-C11, budget alert); `quality-attributes`; embedded `ascent-cost-posture` | A dated monthly estimate against `monthly_budget_usd`; budget alert in the IaC | Strong |
| Performance efficiency | `quality-attributes`; `ascent-ux` (Core Web Vitals); `ascent-quality` (`test-evidence`, QA-L1–L5) | `p95_latency_ms` target; CDN and cache policy; Core Web Vitals against a stated budget; a load test whose p95 threshold is no looser than the target, with an error-rate threshold, that something runs | Partial: thresholds read from the load-test scripts; the run is the operator's |
| Scalability (capacity) | `quality-attributes`; `ascent-quality` (`test-evidence`, QA-L3) | `peak_rps` target; autoscaling or on-demand services; throttling limits; a load test whose request rate reaches `peak_rps` | Partial: the rate is read from the load-test script, not measured |
| Interaction capability (usability) | `ascent-ux` (`ux-review`, `flow-check`, UX-F1–F7) | Heuristic findings on core flows; error, empty and loading states; on each core flow, links and router targets that resolve, a way forward and a way out, a not-found route, and a browser walk with no same-origin error | Partial: no task-success measurement |
| Maintainability | `design-principles-check`; embedded `ascent-layering-check` | Layering, coupling and twelve-factor findings with `file:line` | Partial: layering has negative controls; coupling and twelve-factor findings do not |
| Delivery speed | `ascent-delivery` release log | Lead time and change-failure rate per release (DORA) | Partial: deploy frequency and time to restore come from the log's history |
| Session continuity | `ascent-session` (`session-resume`, `session-capture`, `handoff`, SES-S1–S6) | Decisions dated and only ever appended, from git history; personal session state kept out of git and current; a handoff not older than the newest decision | Partial: checks that the records are kept, not that a summary is complete |
| Documentation findability and accuracy | `ascent-docs` (`docs-review`, DOC-L1–L5, DOC-P1–P4; `doc-drift`, DOC-R1–R6; `doc-stub`, `onboard`) | Every document reachable from the README or a persona's entry point within the click limit; links and anchors resolve; markers and lagging documents dated by git; the paths, make targets, scripts, variables, version and runtimes documents name exist | Partial: checks what documents name and link, not that their descriptions are right |
| Launch readiness | `ascent-governance` (`launch-readiness`, `governance-review`, GOV-S1–S2, GOV-L1–L5) | One answer for one environment, GO, NO-GO or GO WITH CONDITIONS: every check on that environment's floor run fresh, each review within its maximum age, and, where the floor asks for sign-off, a launch record signed by a person for the code as it is | Strong for what it checks, with behavior tests and negative controls: that the evidence exists and is current, not that the system is good; a plugin that is not installed is unmeasured |
| Outcome of a change | — | — | **Gap:** nothing measures whether a change achieved what it was for |

### Compliance

| Attribute | Checked by | Evidence | Status |
|---|---|---|---|
| Accessibility (WCAG 2.2 AA) | `ascent-ux` (`accessibility-audit`, `design-system-check`) | A criterion-by-criterion table; exact token contrast in every theme; a Playwright pass | Strong, and never stated as legal compliance |
| Secure configuration | `ascent-ops` (`iac-config-check`, OPS-S1–S10) | Rules OPS-S1–S10 against the IaC with `file:line`; `trivy config` when installed | Strong |
| Decision traceability | `ascent-adr` (`adr-check`, DEC-S1–S8; `decision-drift`, DEC-C1–C3; `adr-write`); embedded `ascent-adr-conformance`, `ascent-adr-write` | ADRs in one format with alternatives and costs; numbering, index, status and supersession consistent; accepted ADRs unchanged since git first accepted them; the code checked against the constraints accepted ADRs declare | Partial: checks that decisions are recorded, kept and followed where a constraint is declared, not that they are right; constraints are confirmed by a person. Every waiver in the contract must name an accepted ADR (`ascent-governance`, GOV-W4) |
| Waivers and exceptions | `ascent-governance` (`governance-review`, GOV-W1–W4) | Every waiver in every contract section in one list: the accepted ADR that allows it, what it skips, its review date and the days left; past the date it is a finding again | Strong: the dates and the ADRs are checked, not whether the exception is wise |
| Review records | `ascent-governance` (`review-record`, `launch-readiness`, GOV-R1–R4) | One dated row per review that needs judgement: the commit, the rating, the counts, the open High rules and who asked; rows only ever added, from git history; each review within the age its environment allows | Strong for the record; a row is what a session recorded, and the script cannot tell whether it names every finding |
| Change audit trail | `ascent-delivery` (the acceptance record, DEL-A1–A3); `ascent-governance` (GOV-L3–L5) | Who accepted each change and when; who signed each launch, on which commit, and that nothing but governance records changed since; runbooks, hash manifests and the release log for every shipped change | Strong for acceptance and launch records, which have behavior tests and negative controls; runbooks and hash manifests are still a stated rule |
| Version pinning | `ascent-ops` (OPS-Z8, `sre-baseline.md`); `ascent-security` (`dependency-check`, SEC-D1–D3) | Images, packages, providers and actions pinned; npm and Python manifests pinned and locked, lockfiles in step | Strong: package manifests tested under exact and minor ([ADR-016](DECISIONS/ADR-016-dependency-checks-in-ascent-security.md)); for images, providers and actions, exact pinning is read, not tested |
| Regulatory regimes (HIPAA, PCI-DSS, SOC 2) | — | — | **Out of scope:** see [SCOPE.md](SCOPE.md). ASCENT produces evidence an auditor can use; it does not prepare certification |

### Trust and security

| Attribute | Checked by | Evidence | Status |
|---|---|---|---|
| Secret handling | `ascent-security` (`env-audit`, `security-audit`; `check-env.sh`, SEC-E1–E3) | `.env` scope, hardcoded credentials, images built without secrets; values always redacted; no `.env` file tracked, unignored or left out of a `.dockerignore`, checked by a script that never opens one | Strong |
| Runtime hardening | `ascent-security` (`security-audit`) | Container privilege, nginx security headers, production URL schemes, dynamic code execution | Strong |
| Infrastructure hardening | `ascent-ops` (`iac-config-check`) | Secrets from a store, sensitive parameters masked, remote encrypted and locked state, no wildcard IAM actions, secret rotation | Strong |
| Security posture | `ascent-security` (`sec-posture`); `quality-attributes` (Security) | One rating across the surfaces, with the gaps named | Strong |
| Operator boundary and privacy | `ascent-delivery` hook and privacy rules | Claude cannot commit, push or deploy; credentials and personal data never stored | Strong |
| AI behavior | embedded `ascent-ai-evals` | Eval cases for AI features | Partial: scaffolded projects only |
| Dependency vulnerabilities and supply chain | `ascent-security` (`dependency-check`, SEC-D1–D10); embedded `ascent-dependency-health` | Lockfiles, sources and licences; an offline trivy scan of lockfiles and local images with the database date; scanner ignore entries tied to waiver ADRs | Strong with trivy and a current database; Partial without one (the scan is reported unmeasured) ([ADR-016](DECISIONS/ADR-016-dependency-checks-in-ascent-security.md)) |
| Security testing (live) | `ascent-security` (`security-test`, SEC-L1–L10) | Headers, TRACE and CONNECT, path traversal, unauthenticated writes, oversized bodies, disclosure, a prompt-injection canary and an AI burst, run by the operator against local or beta; ZAP, nuclei and dalfox reports from pinned containers | Partial: unauthenticated only, and only as fresh as the operator's last run |
| Threat model | `ascent-security` (`threat-model`, SEC-T1–T4) | STRIDE per entry point; every contract endpoint an entry point, every threat mitigated in a named file or accepted under an ADR, reviewed by a person | Partial: checks that threats are recorded and answered, not that the answers are right |

### Resilience

| Attribute | Checked by | Evidence | Status |
|---|---|---|---|
| Availability | `quality-attributes`; `ascent-ops` (Health and SLOs) | `availability` target; no single instance; health and readiness probes at `/-/health` and `/-/ready` | Partial: read from design and config |
| Operability and observability | `ascent-ops` (`ops-review`, `ops-manuals`); embedded `ascent-observability-check` | SLOs, alerts linked to runbooks, current Maintenance and Troubleshooting manuals | Strong |
| UI reliability (as experienced) | `ascent-ux` (`flow-check`, `ux-review`, UX-R1–R7) | Double-submit guards, a visible failure for every request, retry, drafts on long forms, view state in the URL, an offline notice, optimistic rollback; static, confirmed in the browser walk | Partial: the static check reads one file at a time, so a guard in a shared hook or service is confirmed by reading it |
| Change safety | `ascent-ops` (`runbook-check`); `ascent-delivery` | Zero-touch scripts (OPS-Z1–Z9); runbooks with pre-flight, post-flight, Expect and Stop if; beta before prod | Strong |
| Rollback | `ascent-ops` (Change and recovery) | A documented rollback for every production deploy | Strong as documentation |
| Recoverability (RPO, RTO) | `quality-attributes`; `ascent-ops` (`recovery-drill`) | `rpo` and `rto` targets; backups and retention; the measured rto and rpo of the newest passing drill against the targets (OPS-R4); the manual's restore date (OPS-R7) | Strong ([ADR-020](DECISIONS/ADR-020-recovery-drills-and-readiness-exercises.md)) |
| Restore and failover proof | `ascent-ops` (`recovery-drill`) | A runbook and a current passing drill record with committed evidence for every recovery path, failed drills followed up, declared failover drilled (OPS-R1–R8) | Strong: the operator runs each drill; a record shows a drill was recorded consistently, not that it was honest |
| Operational readiness | `ascent-ops` (`recovery-drill`) | Paging alerts exercised and reaching a role, readiness shown failing with a dependency down, alert runbooks dry-run (OPS-X1–X3) | Strong, from the operator's records |
| Drift | `ascent-ops` (OPS-S9) | A scheduled drift check | Strong |
| Flexibility (portability) | `quality-attributes`; `deployment-options` | Services with a named exit path; equivalents in other clouds | Partial |

---

## Attributes not mapped to a pillar

- **Compatibility** (browsers, clients, API versioning): `quality-attributes` scores it when the contract names a target; `ascent-ux` checks build targets against the contract's `browsers` (UX-F7) and walks the core flows in every engine the operator runs (UX-F6).
- **Sustainability** (idle capacity): `quality-attributes` scores it; `deployment-options` favors scale-to-zero.
- **Safety** (harm to people or equipment): usually out of scope for web systems; `quality-attributes` says so when it is skipped.

## How this page stays true

- A new plugin, skill or rule that closes a gap updates its row here in the same pull request.
- `make test-plugins` (T13.9) fails when the "Checked by" column names a plugin, or a plugin's skill, that is not in [OWNERSHIP.md](OWNERSHIP.md) or the template.
- A status changes to **Strong** only when the check has behavior tests and negative controls, which is the bar in [CONTRIBUTING.md](../../CONTRIBUTING.md#contributing-a-plugin).
- The gaps are the input for scoping the next plugins in [ROADMAP.md](ROADMAP.md#plugin-roadmap).
