# ASCENT capability map

> What ASCENT can do today, what each plugin checks, and what comes next. Counts from the repository at v0.4.24. The ownership gate (`make ownership`, T13.11) checks every version and count on this page, and the figures in the README banner, against the repository.

[At a glance](#at-a-glance) · [Plugins](#plugins) · [Parent skill](#parent-skill) · [Roadmap](#roadmap) · [Everything in one table](#everything-in-one-table)

## At a glance

| **10**<br>plugins released | **48**<br>plugin skills, agents and hooks | **28**<br>skills in every scaffolded project | **74**<br>behavior-test suites | **1732**<br>negative controls | **28**<br>decision records |
|:---:|:---:|:---:|:---:|:---:|:---:|

Every behavior-test suite runs on macOS and Linux. A negative control breaks one rule on purpose, and a named test must catch it.

## Plugins

Install only what your repository needs. Each plugin works alone; one you skip leaves its review "unmeasured", never blocked. Every review is read-only, and every finding carries a plugin-qualified rule id such as `OPS-S3`.

### `ascent-security` 0.4.0 · ✅ Released v0.4.24

> "Any secrets committed? Are our dependencies safe? Is the running app hardened?"

`.env` discipline, hardcoded credentials, container privilege, security headers, production URLs and dynamic code; lockfiles, pinning, sources, licences and an offline vulnerability scan of dependencies and local images; a STRIDE threat model; and live checks of a running application that the operator runs, with ZAP, nuclei and dalfox in pinned containers. `check-env.sh` keeps `.env` files out of git and out of images, in a session or in CI.

- **Skills:** `env-audit` · `security-audit` · `sec-posture` · `dependency-check` · `threat-model` · `security-test` · agent `security-auditor`
- **Rules:** `SEC-D1`–`D10`, `SEC-E1`–`E3`, `SEC-L1`–`L10`, `SEC-T1`–`T4`, plus the security baselines
- **Next:** authenticated checks and a trial of the scanners against a real target, when a project needs them

### `ascent-delivery` 0.2.2 · ✅ Released v0.4.24

> "Ship this change. Who accepted it?"

The delivery loop: decide, build with a file audit, test with negative controls, gate, an independent review checked by a finding verifier, then an operator runbook. A person accepts each change on beta, by name and date, and prod stops until the acceptance record passes and, with a `governance` section in the contract, until the launch evidence is not a NO-GO. A hook stops Claude from any git write or deploy listed in any contract.

- **Skills:** `delivery-loop` · agent `finding-verifier` · hook `operator-boundary`
- **Rules:** `DEL-A1`–`A3`, the acceptance record
- **Review lenses:** nine; eight use an ASCENT reviewer first (Decisions uses `decision-reviewer`, Documentation `docs-reviewer`, since v0.4.23), and Correctness uses `engineering:code-review`

### `ascent-architecture` 0.2.2 · ✅ Released v0.4.24

> "Is this production-ready? What will it cost to run?"

Quality attributes scored against your targets, design principles with file evidence, deployment options with dated cost estimates, and a CloudFormation static-site blueprint.

- **Skills:** `architecture-review` · `quality-attributes` · `design-principles-check` · `deployment-options` · agent `architecture-reviewer`
- **Rules and catalogues:** `ARC-C`, `ARC-P`, `ARC-O`, `ARC-B`
- **Next:** 0.3.0 candidates, more blueprints (Fargate, Terraform), `cfn-guard` rules, Azure and Google Cloud pricing

### `ascent-ux` 0.3.2 · ✅ Released v0.4.24

> "Is this UI accessible? Do our flows work and keep the user's work?"

UX as four principles: functional, reliable, accessible, pleasant. Flows checked for broken links, dead ends, double submits and lost drafts, with a browser walk of each core flow; WCAG 2.2 AA evidence from static checks and a Playwright browser pass; exact design-token contrast; and five accessible design directions shown as mocks of your own pages.

- **Skills:** `ux-review` · `flow-check` · `accessibility-audit` · `design-system-check` · `design-directions` · agent `ux-reviewer`
- **Rules:** `UX-U1`–`U12`, `UX-H`, `UX-D`, `UX-F1`–`F7`, `UX-R1`–`R7`, `UX-P1`–`P4`

### `ascent-ops` 0.3.1 · ✅ Released v0.4.24

> "Is this operable? Can we restore?"

Secure IaC configuration, zero-touch scripts and runbooks, operations and troubleshooting manuals proven current, and recovery drills proven by the operator's own records.

- **Skills:** `ops-review` · `iac-config-check` · `runbook-check` · `ops-manuals` · `recovery-drill` · agent `ops-reviewer`
- **Rules:** `OPS-S1`–`S10`, `OPS-Z1`–`Z9`, `OPS-M1`–`M8`, `OPS-R1`–`R8`, `OPS-X1`–`X3`

### `ascent-quality` 0.2.1 · ✅ Released v0.4.24

> "Are we testing the right things?"

Which test types exist and whether CI runs them, boundaries no test reaches, acceptance criteria traced to tests, test hygiene, load tests against your latency and throughput targets, and mutation evidence.

- **Skills:** `quality-review` · `test-inventory` · `test-check` · `test-evidence` · agent `quality-reviewer`
- **Rules:** `QA-I1`–`I5`, `QA-T1`–`T4`, `QA-H1`–`H4`, `QA-L1`–`L5`, `QA-M1`–`M4`
- **Next:** more languages, and Gatling and JMeter, when a trial needs them

### `ascent-adr` 0.1.1 · ✅ Released v0.4.24

> "Do our ADRs conform? Write an ADR for this. Does the code still follow our decisions?"

ADRs written in the repository's own format (ASCENT, Nygard and adr-tools, MADR) with real alternatives and costs; the record checked for sections, numbering, the index, status, supersession both ways and dates, with accepted ADRs compared to the version git first accepted; and the code checked against the constraints accepted ADRs declare.

- **Skills:** `adr-check` · `adr-write` · `decision-drift` · agent `decision-reviewer`
- **Rules:** `DEC-S1`–`S8`, `DEC-C1`–`C3`
- **Next:** constraints proposed from more ADR formats, when a trial needs them

### `ascent-session` 0.1.0 · ✅ Released v0.4.23

> "Where did we leave off? Capture the session. Write a handoff."

Sessions resumed from the project's own records with every claim cited to its line; state and decisions captured before closing; a handoff for the next person; and the records checked: decisions dated and only ever appended, personal state kept out of git, the handoff current.

- **Skills:** `session-resume` · `session-capture` · `handoff`
- **Rules:** `SES-S1`–`S6`

### `ascent-docs` 0.1.1 · ✅ Released v0.4.24

> "Are our docs current? Do they still match the code? Onboard me."

Documents reachable from the README and each persona's entry point within a click limit, links and anchors that resolve, stale markers and lagging documents dated by git, the paths, make targets, scripts, variables, version and runtimes documents name checked against the repository, new documents from stubs, and an onboarding walkthrough.

- **Skills:** `docs-review` · `doc-drift` · `doc-stub` · `onboard` · agent `docs-reviewer`
- **Rules:** `DOC-L1`–`L5`, `DOC-P1`–`P4`, `DOC-R1`–`R6`

### `ascent-governance` 0.1.0 · ✅ Released v0.4.24

> "Are we ready for prod? Which reviews are due? Draft the launch record."

One answer for one environment at a time (local, beta, prod, or your own ladder): GO, NO-GO or GO WITH CONDITIONS, with every reason cited. The other plugins' checks run fresh at no token cost; each review that needs judgement leaves a dated record with a maximum age; every waiver is listed with its ADR and its review date; and the answer is a launch record that Claude drafts and only a person signs. The same result is a CI job summary and a one-file HTML page. It checks that the evidence exists and is current, not that the system is good.

- **Skills:** `launch-readiness` · `governance-review` · `review-record` · agent `governance-conductor`
- **Rules:** `GOV-S1`–`S2`, `GOV-L1`–`L5`, `GOV-W1`–`W4`, `GOV-R1`–`R4`
- **Next:** more than one approver per launch, when a project needs it

## Parent skill

`lloydbriantech-ascent` scaffolds, enhances or migrates a project to ASCENT standards. Every project gets 28 working `ascent-*` skills, from ADR writing and release readiness to standups and handoffs, and nine engineering roles: delivery lead, architect, UI/UX designer, developer, data engineer, AI engineer, tester, devops and cybersecurity. See [Scaffold a new project](../../README.md#scaffold-a-new-project).

## Roadmap

| When | What | Status |
|---|---|---|
| v0.1 – v0.4.1 | Phases 0–3: foundation, parent skill, template assets, embedded skills | ✅ Done |
| v0.4.2 – v0.4.24 | Ten plugins, an ownership registry, a hardened gate, CI that runs what a change can affect, acceptance sign-off, faster local verification, live security testing and a threat model, decision records, session continuity and documentation, launch readiness and auditability, and this map | ✅ Done |
| Phases 4–7 | Scaffolding scripts, eval harness, starter repository, first production project | Awaiting go-signal |
| plugin roadmap | `ascent-node-stack`, last, scoped when it starts | Planned |

Details and exit criteria: [ROADMAP.md](ROADMAP.md). Every change: [CHANGELOG.md](../../CHANGELOG.md).

## Everything in one table

| Component | Kind | Version | Status | Since |
|---|---|---|---|---|
| `ascent-security` | Plugin · 6 skills, 1 agent | 0.4.0 | ✅ Released | v0.4.2 · dependencies in v0.4.9 · live testing in v0.4.22 · `.env` check in v0.4.24 |
| `ascent-delivery` | Plugin · 1 skill, 1 agent, 1 hook | 0.2.2 | ✅ Released | v0.4.3 · acceptance in v0.4.20 · lenses in v0.4.23 · launch evidence in v0.4.24 |
| `ascent-architecture` | Plugin · 4 skills, 1 agent | 0.2.2 | ✅ Released | v0.4.4 |
| `ascent-ux` | Plugin · 5 skills, 1 agent | 0.3.2 | ✅ Released | v0.4.5 · flows in v0.4.15 |
| `ascent-ops` | Plugin · 5 skills, 1 agent | 0.3.1 | ✅ Released | v0.4.6 · drills in v0.4.12 |
| `ascent-quality` | Plugin · 4 skills, 1 agent | 0.2.1 | ✅ Released | v0.4.11 · evidence in v0.4.13 |
| `ascent-adr` | Plugin · 3 skills, 1 agent | 0.1.1 | ✅ Released | v0.4.23 |
| `ascent-session` | Plugin · 3 skills | 0.1.0 | ✅ Released | v0.4.23 |
| `ascent-docs` | Plugin · 4 skills, 1 agent | 0.1.1 | ✅ Released | v0.4.23 |
| `ascent-governance` | Plugin · 3 skills, 1 agent | 0.1.0 | ✅ Released | v0.4.24 |
| `lloydbriantech-ascent` | Parent skill · 9 roles, 28 embedded skills | 0.4.24 | ✅ Released | Phase 3, v0.4.0 |
