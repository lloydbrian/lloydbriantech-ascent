# Ownership registry

**For:** contributors adding a plugin, skill, agent, rule family or review lens, and project owners choosing which plugins to install.

Every plugin, component, rule-id family, contract section, domain and review lens in ASCENT has exactly one owner. This page records them. It is the document and the data: `make test-plugins` reads the marked tables below (check T13, [ADR-015](DECISIONS/ADR-015-ownership-registry-and-gate.md)) and fails when the repository disagrees with them. Run `make ownership` to see every T13 result on its own.

How to change it:
- **Add the row first.** A new plugin, skill, agent, hook, rule family, contract section or lens starts with a row here, in the same pull request.
- **Planned work is reserved.** A planned plugin, code or rule family gets a row before it is built, so no one else takes its name. Roadmap plugins that are not scoped yet (`ascent-session`, `ascent-adr`, `ascent-docs`, `ascent-node-stack`) get their rows when scoping starts.
- **Ownership decisions live in ADRs.** This page records them; T13 keeps them from drifting. T13 cannot tell whether an owner is the right one.

Table format: one row per line, cells separated by `|`. A name is in backticks; `—` means none. Several names in one cell are separated by commas.

---

## Which plugins do I need?

Install the plugins whose signals your repository shows. Each one works on its own; a plugin you do not install makes its review "unmeasured", never blocked. Required plugins are a floor, never a ceiling: any other plugin or agent stays usable.

<!-- ownership:signals:start -->
| Signal in the repository | Plugin | Why |
|---|---|---|
| any repository with git | `ascent-delivery` | ship each change through the delivery loop, with the operator running every git write and deploy |
| `.env` files, configuration, a `Dockerfile`, `nginx.conf`, server or client code, package manifests and lockfiles | `ascent-security` | secrets, credentials, container privilege, security headers, dynamic code, and dependency vulnerabilities and supply chain |
| infrastructure as code (CloudFormation, CDK, Terraform), a deployed service, a budget | `ascent-architecture` | quality attributes against targets, design principles, deployment options and cost |
| HTML, JSX, Vue or Svelte templates, CSS, design tokens | `ascent-ux` | WCAG 2.2 AA evidence, design tokens and contrast, design directions |
| infrastructure as code, operator scripts, runbooks, Compose files, health endpoints | `ascent-ops` | secure configuration, zero-touch scripts and runbooks, operations manuals |
<!-- ownership:signals:end -->

---

## Plugins

`Code` prefixes every rule id the plugin reports (`OPS-S3`). `Build` says whether its skills are generated from the template skills (`make plugins`, [ADR-009](DECISIONS/ADR-009-plugins-generated-from-template-skills.md)), hand-written, or hybrid: generated skills beside hand-written ones ([ADR-016](DECISIONS/ADR-016-dependency-checks-in-ascent-security.md)).

<!-- ownership:plugins:start -->
| Plugin | Code | Status | Build | Contract section | Severity marker |
|---|---|---|---|---|---|
| `ascent-security` | `SEC` | released | hybrid | `security` | `severity-table`, `dep-severity` |
| `ascent-delivery` | `DEL` | released | hand-written | — | — |
| `ascent-architecture` | `ARC` | released | hand-written | `architecture` | `arch-severity` |
| `ascent-ux` | `UX` | released | hand-written | `ux` | `ux-severity` |
| `ascent-ops` | `OPS` | released | hand-written | `ops` | `ops-severity` |
| `ascent-quality` | `QA` | planned | hand-written | `quality` | — |
| `ascent-governance` | `GOV` | planned | hand-written | — | — |
<!-- ownership:plugins:end -->

`ascent-delivery` reads its own contract, `.delivery-loop.yml`, not a section of `.ascent/contract.yml`.

## Components

Every skill, agent and hook a released plugin ships.

<!-- ownership:components:start -->
| Plugin | Kind | Name |
|---|---|---|
| `ascent-security` | skill | `env-audit` |
| `ascent-security` | skill | `security-audit` |
| `ascent-security` | skill | `sec-posture` |
| `ascent-security` | skill | `dependency-check` |
| `ascent-security` | agent | `security-auditor` |
| `ascent-delivery` | skill | `delivery-loop` |
| `ascent-delivery` | agent | `finding-verifier` |
| `ascent-delivery` | hook | `operator-boundary` |
| `ascent-architecture` | skill | `architecture-review` |
| `ascent-architecture` | skill | `quality-attributes` |
| `ascent-architecture` | skill | `design-principles-check` |
| `ascent-architecture` | skill | `deployment-options` |
| `ascent-architecture` | agent | `architecture-reviewer` |
| `ascent-ux` | skill | `ux-review` |
| `ascent-ux` | skill | `accessibility-audit` |
| `ascent-ux` | skill | `design-system-check` |
| `ascent-ux` | skill | `design-directions` |
| `ascent-ux` | agent | `ux-reviewer` |
| `ascent-ops` | skill | `ops-review` |
| `ascent-ops` | skill | `iac-config-check` |
| `ascent-ops` | skill | `runbook-check` |
| `ascent-ops` | skill | `ops-manuals` |
| `ascent-ops` | agent | `ops-reviewer` |
<!-- ownership:components:end -->

## Rule-id families

A rule id is `<CODE>-<family><n>`, for example `OPS-S3` or `UX-D2`. A **rule** passes or fails and produces findings; a **catalogue** entry names an item in a reference list (an option, a principle, a direction). Both appear in reports, so both are registered. `Defined in` is the file that holds the family's table or header; it must mention the family's first id.

**Internal** namespaces belong to this repository's tooling and never appear in a plugin report: `T1`–`T13` (gate checks in `make/test-plugins.sh`), `P01` onward (negative controls) and `V00` onward (validator cases, both in `make/test-mutants.sh`). Test-case ids inside a test file (R1, D1 and so on) are local to that file and are not registered.

<!-- ownership:families:start -->
| Prefix | Plugin | Kind | Defined in |
|---|---|---|---|
| `ARC-C` | `ascent-architecture` | rule | `plugins/ascent-architecture/scripts/check-cfn-static-site.sh` |
| `ARC-P` | `ascent-architecture` | catalogue | `plugins/ascent-architecture/references/architecture-principles.md` |
| `ARC-O` | `ascent-architecture` | catalogue | `plugins/ascent-architecture/skills/deployment-options/SKILL.md` |
| `ARC-B` | `ascent-architecture` | catalogue | `plugins/ascent-architecture/references/cloud-component-mapping.md` |
| `OPS-S` | `ascent-ops` | rule | `plugins/ascent-ops/references/secure-config-rules.md` |
| `OPS-Z` | `ascent-ops` | rule | `plugins/ascent-ops/scripts/check-ops-scripts.sh` |
| `OPS-M` | `ascent-ops` | rule | `plugins/ascent-ops/scripts/check-ops-manuals.sh` |
| `SEC-D` | `ascent-security` | rule | `plugins/ascent-security/scripts/check-dependencies.sh` |
| `UX-U` | `ascent-ux` | rule | `plugins/ascent-ux/scripts/check-web-accessibility.sh` |
| `UX-H` | `ascent-ux` | catalogue | `plugins/ascent-ux/references/usability-heuristics.md` |
| `UX-D` | `ascent-ux` | catalogue | `plugins/ascent-ux/skills/design-directions/SKILL.md` |
| `T` | — | internal | `make/test-plugins.sh` |
| `P` | — | internal | `make/test-mutants.sh` |
| `V` | — | internal | `make/test-mutants.sh` |
<!-- ownership:families:end -->

## Reserved

Names, codes and rule-id families taken for planned work ([ADR-014](DECISIONS/ADR-014-testing-ownership-and-dependency-scan.md), [ADR-015](DECISIONS/ADR-015-ownership-registry-and-gate.md); release numbers from [ADR-017](DECISIONS/ADR-017-faster-negative-controls.md)).

<!-- ownership:reserved:start -->
| Reserved | For | Release |
|---|---|---|
| `QA-I` | `ascent-quality` | v0.4.11 |
| `QA-T` | `ascent-quality` | v0.4.11 |
| `QA-H` | `ascent-quality` | v0.4.11 |
| `OPS-R` | `ascent-ops` | v0.4.12 |
| `OPS-X` | `ascent-ops` | v0.4.12 |
<!-- ownership:reserved:end -->

## Domains and testing types

Each domain has up to three owners: the plugin that sets the **target**, the plugin that checks a test or check is **present**, and the operator, who runs anything live. `operator` and `—` are allowed owners; every other owner must be a registered plugin or an embedded template skill.

<!-- ownership:domains:start -->
| Domain | Target owner | Test-present owner | Status |
|---|---|---|---|
| secrets and credentials | `ascent-security` | `ascent-security` | released |
| runtime hardening | `ascent-security` | `ascent-security` | released |
| security posture | `ascent-security` | `ascent-security` | released |
| dependency vulnerabilities and supply chain | `ascent-security` | `ascent-security` | released |
| threat model | `ascent-security` | `ascent-security` | planned |
| security testing (live, operator-run) | `ascent-security` | `ascent-security` | planned |
| change delivery and the operator boundary | `ascent-delivery` | `ascent-delivery` | released |
| smoke tests after a deploy | `ascent-delivery` | `ascent-delivery` | released |
| user acceptance sign-off | `ascent-delivery` | `ascent-delivery` | planned |
| quality attributes and targets | `ascent-architecture` | `ascent-architecture` | released |
| design principles | `ascent-architecture` | `ascent-architecture` | released |
| deployment options and cost | `ascent-architecture` | `ascent-architecture` | released |
| load and performance (server) | `ascent-architecture` | `ascent-quality` | planned |
| restore and failover | `ascent-architecture` | `ascent-ops` | planned |
| accessibility (WCAG 2.2 AA) | `ascent-ux` | `ascent-ux` | released |
| design tokens and contrast | `ascent-ux` | `ascent-ux` | released |
| front-end performance | `ascent-ux` | `ascent-ux` | released |
| navigational integrity | `ascent-ux` | `ascent-ux` | planned |
| cross-browser compatibility | `ascent-architecture` | `ascent-ux` | planned |
| secure IaC configuration | `ascent-ops` | `ascent-ops` | released |
| operator scripts and runbooks | `ascent-ops` | `ascent-ops` | released |
| operations manuals | `ascent-ops` | `ascent-ops` | released |
| operational readiness exercises | `ascent-ops` | `ascent-ops` | planned |
| unit, integration and contract tests | — | `ascent-quality` | planned |
| regression and end-to-end tests | `ascent-delivery` | `ascent-quality` | planned |
| criterion-to-test traceability | `ascent-delivery` | `ascent-quality` | planned |
| mutation evidence | — | `ascent-quality` | planned |
| launch readiness | `ascent-governance` | `ascent-governance` | planned |
| AI behavior evals | — | `ascent-ai-evals` | released |
<!-- ownership:domains:end -->

## Review lenses

The delivery loop (`ascent-delivery`, Step 4) runs one reviewer per lens. It uses the first provider installed in the session, in the order below, and the lens's fallback prompt when none is. Both lens tables in `ascent-delivery` must match this one.

<!-- ownership:lenses:start -->
| Lens | Providers, first installed wins | Fallback |
|---|---|---|
| Correctness | `engineering:code-review` | fallback prompt |
| Security and privacy | `ascent-security:security-auditor` | fallback prompt |
| Architecture and cost | `ascent-architecture:architecture-reviewer` | fallback prompt |
| Accessibility | `ascent-ux:ux-reviewer`, `design:accessibility-review` | fallback prompt |
| UX and navigation | `ascent-ux:ux-reviewer` | fallback prompt |
| Operational and deploy impact | `ascent-ops:ops-reviewer`, `engineering:deploy-checklist` | fallback prompt |
| Tests | `engineering:testing-strategy` | fallback prompt |
<!-- ownership:lenses:end -->
