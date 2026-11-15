# ASCENT capability map

> What ASCENT can do today, what each plugin checks, and what comes next. Counts from the repository at v0.4.16. The ownership gate (`make ownership`, T13.11) checks every version and count on this page against the repository.

[At a glance](#at-a-glance) · [Plugins](#plugins) · [Parent skill](#parent-skill) · [Roadmap](#roadmap) · [Everything in one table](#everything-in-one-table)

## At a glance

| **6**<br>plugins released | **30**<br>plugin skills, agents and hooks | **28**<br>skills in every scaffolded project | **51**<br>behavior-test suites | **868**<br>negative controls | **22**<br>decision records |
|:---:|:---:|:---:|:---:|:---:|:---:|

Every behavior-test suite runs on macOS and Linux. A negative control breaks one rule on purpose, and a named test must catch it.

## Plugins

Install only what your repository needs. Each plugin works alone; one you skip leaves its review "unmeasured", never blocked. Every review is read-only, and every finding carries a plugin-qualified rule id such as `OPS-S3`.

### `ascent-security` 0.2.0 · ✅ Released v0.4.9

> "Any secrets committed? Are our dependencies safe?"

`.env` discipline, hardcoded credentials, container privilege, security headers, production URLs and dynamic code; lockfiles, pinning, sources, licences and an offline vulnerability scan of dependencies and local images.

- **Skills:** `env-audit` · `security-audit` · `sec-posture` · `dependency-check` · agent `security-auditor`
- **Rules:** `SEC-D1`–`D10`, plus the security baselines
- **Next:** 0.3.0, live operator-run security testing and a threat model

### `ascent-delivery` 0.1.3 · ✅ Released v0.4.11

> "Ship this change."

The delivery loop: decide, build with a file audit, test with negative controls, gate, an independent review checked by a finding verifier, then an operator runbook. A hook stops Claude from any git write or deploy.

- **Skills:** `delivery-loop` · agent `finding-verifier` · hook `operator-boundary`
- **Review lenses:** seven; six use an ASCENT reviewer first, and Correctness uses `engineering:code-review`
- **Next:** 0.2.0, a user acceptance sign-off record and the `delivery:` section of the contract

### `ascent-architecture` 0.2.0 · ✅ Released v0.4.8

> "Is this production-ready? What will it cost to run?"

Quality attributes scored against your targets, design principles with file evidence, deployment options with dated cost estimates, and a CloudFormation static-site blueprint.

- **Skills:** `architecture-review` · `quality-attributes` · `design-principles-check` · `deployment-options` · agent `architecture-reviewer`
- **Rules and catalogues:** `ARC-C`, `ARC-P`, `ARC-O`, `ARC-B`
- **Next:** 0.3.0 candidates, more blueprints (Fargate, Terraform), `cfn-guard` rules, Azure and Google Cloud pricing

### `ascent-ux` 0.3.0 · ✅ Released v0.4.15

> "Is this UI accessible? Do our flows work and keep the user's work?"

UX as four principles: functional, reliable, accessible, pleasant. Flows checked for broken links, dead ends, double submits and lost drafts, with a browser walk of each core flow; WCAG 2.2 AA evidence from static checks and a Playwright browser pass; exact design-token contrast; and five accessible design directions shown as mocks of your own pages.

- **Skills:** `ux-review` · `flow-check` · `accessibility-audit` · `design-system-check` · `design-directions` · agent `ux-reviewer`
- **Rules:** `UX-U1`–`U12`, `UX-H`, `UX-D`, `UX-F1`–`F7`, `UX-R1`–`R7`, `UX-P1`–`P4`
- **Next:** 0.3.1, trial calibrations and the first Firefox and WebKit run on real repositories

### `ascent-ops` 0.3.0 · ✅ Released v0.4.12

> "Is this operable? Can we restore?"

Secure IaC configuration, zero-touch scripts and runbooks, operations and troubleshooting manuals proven current, and recovery drills proven by the operator's own records.

- **Skills:** `ops-review` · `iac-config-check` · `runbook-check` · `ops-manuals` · `recovery-drill` · agent `ops-reviewer`
- **Rules:** `OPS-S1`–`S10`, `OPS-Z1`–`Z9`, `OPS-M1`–`M8`, `OPS-R1`–`R8`, `OPS-X1`–`X3`

### `ascent-quality` 0.2.0 · ✅ Released v0.4.13

> "Are we testing the right things?"

Which test types exist and whether CI runs them, boundaries no test reaches, acceptance criteria traced to tests, test hygiene, load tests against your latency and throughput targets, and mutation evidence.

- **Skills:** `quality-review` · `test-inventory` · `test-check` · `test-evidence` · agent `quality-reviewer`
- **Rules:** `QA-I1`–`I5`, `QA-T1`–`T4`, `QA-H1`–`H4`, `QA-L1`–`L5`, `QA-M1`–`M4`
- **Next:** more languages, and Gatling and JMeter, when a trial needs them

## Parent skill

`lloydbriantech-ascent` scaffolds, enhances or migrates a project to ASCENT standards. Every project gets 28 working `ascent-*` skills, from ADR writing and release readiness to standups and handoffs, and nine engineering roles: delivery lead, architect, UI/UX designer, developer, data engineer, AI engineer, tester, devops and cybersecurity. See [Scaffold a new project](../../README.md#scaffold-a-new-project).

## Roadmap

| When | What | Status |
|---|---|---|
| v0.1 – v0.4.1 | Phases 0–3: foundation, parent skill, template assets, embedded skills | ✅ Done |
| v0.4.2 – v0.4.16 | Six plugins, an ownership registry, a hardened gate and this map | ✅ Done |
| next releases | `ascent-ux` 0.3.1; live security testing and a threat model (`ascent-security` 0.3.0); acceptance sign-off (`ascent-delivery` 0.2.0); auditability for projects and a launch go/no-go conductor | Planned |
| plugin roadmap | `ascent-session`, `ascent-adr`, `ascent-docs` and `ascent-node-stack`, scoped when each starts | Planned |
| Phases 4–7 | Scaffolding scripts, eval harness, starter repository, first production project | Awaiting go-signal |

Details and exit criteria: [ROADMAP.md](ROADMAP.md). Every change: [CHANGELOG.md](../../CHANGELOG.md).

## Everything in one table

| Component | Kind | Version | Status | Since |
|---|---|---|---|---|
| `ascent-security` | Plugin · 4 skills, 1 agent | 0.2.0 | ✅ Released | v0.4.2 · dependencies in v0.4.9 |
| `ascent-delivery` | Plugin · 1 skill, 1 agent, 1 hook | 0.1.3 | ✅ Released | v0.4.3 |
| `ascent-architecture` | Plugin · 4 skills, 1 agent | 0.2.0 | ✅ Released | v0.4.4 |
| `ascent-ux` | Plugin · 5 skills, 1 agent | 0.3.0 | ✅ Released | v0.4.5 · flows in v0.4.15 |
| `ascent-ops` | Plugin · 5 skills, 1 agent | 0.3.0 | ✅ Released | v0.4.6 · drills in v0.4.12 |
| `ascent-quality` | Plugin · 4 skills, 1 agent | 0.2.0 | ✅ Released | v0.4.11 · evidence in v0.4.13 |
| `lloydbriantech-ascent` | Parent skill · 9 roles, 28 embedded skills | 0.4.16 | ✅ Released | Phase 3, v0.4.0 |
