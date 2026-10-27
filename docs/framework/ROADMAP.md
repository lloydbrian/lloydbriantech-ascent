# ASCENT Roadmap

The phase plan from v0.1-alpha to v1.0. Each phase has explicit exit criteria. No phase begins without the literal "Proceed with Phase N" signal — the framework dogfoods its own phase-delivery discipline.

**Current state:** v0.4.8 (ownership registry and plugin-qualified rule ids), October 27, 2026. Next: `ascent-security` 0.2.0 (dependency check, v0.4.9), then `ascent-quality` (v0.4.10); Phase 4 awaits its go-signal.

## Plugin roadmap

Since v0.4.2, ASCENT also ships its checks as Claude Code plugins that work in any repository. The order was decided on 2026-10-18 and confirmed on 2026-10-24. Each plugin clears the same bar before release: hardened source, behavior tests, negative controls, the plugin gate with its version check, a read-only trial on real repositories, and a release record.

| Rank | Plugin | Scope | Status |
|---|---|---|---|
| — | `ascent-security` | `.env` discipline, credentials, container privilege, headers, dynamic code; 0.2.0 adds a dependency and vulnerability check (`SEC-D`, ADR-014) | ✅ v0.4.2, 0.1.1 in v0.4.3; 0.2.0 ⏳ Next (v0.4.9) |
| — | `ascent-delivery` | The delivery loop and the operator-boundary hook | ✅ v0.4.3 |
| 1 | `ascent-architecture` | Quality attributes, design principles, deployment options and cost | ✅ v0.4.4 |
| 2 | `ascent-ux` | WCAG 2.2 evidence, design tokens, design directions | ✅ v0.4.5 |
| 3 | `ascent-ops` | Secure IaC configuration, zero-touch runbooks, operations manuals; 0.3.0 adds recovery drills and readiness exercises (`OPS-R`, `OPS-X`, ADR-014) | ✅ v0.4.6; 0.3.0 ⏳ Planned (v0.4.11) |
| 4 | `ascent-quality` | Test strategy: test inventory, criterion-to-test traceability and test hygiene (`QA-I`, `QA-T`, `QA-H`, ADR-014) | ⏳ Scoped (v0.4.10) |
| 5 | `ascent-session` | To be scoped when it starts | ⏳ Planned |
| 6 | `ascent-adr` | To be scoped when it starts | ⏳ Planned |
| 7 | `ascent-docs` | To be scoped when it starts | ⏳ Planned |
| 8 | `ascent-node-stack` | To be scoped when it starts | ⏳ Planned |

### Committed follow-ups

These close gaps listed in [PILLARS.md](PILLARS.md). Each is scoped, with an ADR, when it starts.

| Follow-up | Pillar | Why | Status |
|---|---|---|---|
| Restore and failover proof | Resilience | `ascent-ops` and `quality-attributes` read the date of the last restore test but do not prove a restore or a failover works. A drill runbook the operator runs, with the measured recovery time checked against the contract's `rto` and `rpo`, would make recovery evidence rather than documentation | ⏳ Scoped in ADR-014: `ascent-ops` 0.3.0, v0.4.11 |
| Auditability for projects | Compliance | Project-facing governance: a waiver ledger with expiry dates, dated review records, a required-plugin floor in the contract (a floor, never a ceiling) and a bash checker a project can run in its own CI. Closes the Partial rows "Decision traceability" and "Change audit trail" (ADR-015) | ⏳ Committed on 2026-10-27, to be scoped |
| The governance conductor | Business value | `ascent-governance` (agent `governance-conductor`, skills `governance-review` and `launch-readiness`) reads the ownership registry and the auditability evidence for a go or no-go. Ships when launch readiness is scoped (ADR-015) | ⏳ Deferred; name and code `GOV` reserved |
| Recommended next names missing plugins | Business value | Each plugin's "Recommended next" line also names an uninstalled plugin whose signals the repository shows, from [OWNERSHIP.md](OWNERSHIP.md#which-plugins-do-i-need) | ⏳ Committed on 2026-10-27 |
| Navigational integrity and cross-browser | Business value | `ascent-ux` 0.3.0: broken links, dead ends and lost state across flows, and a cross-browser pass (ADR-014) | ⏳ Planned |
| User acceptance sign-off | Business value | `ascent-delivery` 0.2.0 records who accepted each criterion and when (ADR-014) | ⏳ Planned |

Plugin releases are patch versions of the framework (v0.4.x) and do not need a phase signal. The phases below still do.

---

## Phase 0 — Foundation

**Goal:** Establish framework identity, conventions, and architectural decisions. Ship the meta-repository foundation so future phases have a structured place to land.

**Status:** ✅ Complete (May 14, 2026)

**Exit criteria:**

- [x] Repository identity files (README, CLAUDE.md, CHANGELOG, CONTRIBUTING, LICENSE files)
- [x] Framework documentation foundation (PHILOSOPHY, PRINCIPLES, SCOPE, ROADMAP, ARCHITECTURE)
- [x] Framework ADRs 001 through 007 capturing the foundational decisions
- [x] Tooling and CI scaffolding (.github workflows, issue/PR templates, .vscode config)
- [x] No skill code, no template assets, no scripts — those are subsequent phases

**Version on completion:** v0.1.0-alpha

---

## Phase 1 — Parent skill skeleton

**Goal:** Ship the parent skill `lloydbriantech-ascent` with role-routing logic and the reference modules each role consumes. The skill won't yet scaffold anything; it can answer questions about ASCENT and route to roles.

**Status:** ✅ Complete (May 15, 2026)

**Exit criteria:**

- [x] `skills/lloydbriantech-ascent/SKILL.md` with frontmatter and role-routing logic
- [x] `skills/lloydbriantech-ascent/references/` populated with reference modules:
  - `role-delivery-lead.md`, `role-architect.md`, `role-ui-ux-designer.md`, `role-developer.md`, `role-data-engineer.md`, `role-ai-engineer.md`, `role-tester.md`, `role-devops.md`, `role-cybersecurity.md`
  - `ASCENT-INVARIANTS.md`, `MAKE-NAMING.md`, `SLUG-CONVENTIONS.md`, `PHASE-PROTOCOL.md`, `ENV-DISCIPLINE.md`, `ADR-TEMPLATE.md`
  - `feature-lifecycle.md`, `observability-contract.md`, `writing-style.md`, `doc-architecture.md`, `audience-mapping.md`, `external-services-integration.md`
- [x] Root `Makefile` and `make/` directory with the SDLC-sectioned help working
- [x] `make qa-skill-frontmatter` validates every SKILL.md
- [x] `make qa-links` validates internal links
- [x] Skill can answer "what role handles X?" correctly for representative prompts
- [x] No scaffolding yet — the skill can talk but not yet write files

**Version on completion:** v0.2.0

---

## Phase 2 — Template assets (substantive baseline)

**Goal:** Author the substantive baseline content for every file the architect role emits. After this phase, the architect role's scaffold mode can produce a working project.

**Status:** ✅ Complete (May 16, 2026)

**Exit criteria:**

- [x] `skills/lloydbriantech-ascent/assets/template/` contains:
  - Root files: README.md.tmpl, CLAUDE.md.tmpl, CHANGELOG.md.tmpl, LICENSE files, .gitignore, .dockerignore, .env.example, .claudeignore
  - Makefile + 8 child .mk files (dev, dev-status, test, quality, security, validate, podman, infra, docs)
  - docker-compose family (yml, prod.yml, prod.local.yml, dist.yml, suite.yml)
  - nginx/ skeleton with three config variants
  - backend/ skeleton with working server.js, Dockerfile, package.json, middleware, db setup
  - frontend/ skeleton with working Vite shell
  - 7 always-emitted ADRs + INDEX.md template
  - 9 baseline project-embedded skill SKILL.md scaffolds + INTENT-MAP.md
- [x] Every template file uses slug placeholders consistently
- [x] A test scaffold of a hello-world project using these templates runs `make dev-up` successfully
- [x] No `// TODO` files — every file ships substantive content

**Version on completion:** v0.3.0

---

### v0.3.1 — Session resumption protocol

**Status:** ✅ Complete (May 17, 2026)

Adds Principle §15 (session resumption) and the artifacts/protocol that operationalize it. The framework now treats session resumption as a first-class concern: `session-state.md` for transient working state, `working-memory.md` for accumulating decisions, `make session-snapshot` for user-prompted capture, and `session-protocol.md` as the authoritative reference module.

Skill scaffold extensions: `ascent-delivery-status` reads session state; `ascent-feature-intake` writes to working memory. Full skill implementations land in Phase 3.

---

## Phase 3 — Project-embedded skills

**Goal:** Author the SKILL.md files for all 14 baseline project-embedded skills and the 14 specialized/conditional ones. Each skill is invocable inside a scaffolded project.

**Status:** ✅ Complete (May 20, 2026)

Note: §15 implementation extends `ascent-delivery-status` (read session state) and `ascent-feature-intake` (write to working memory) — covered as part of Phase 3 skill implementation work. The `.claude/commands/` slash-command files are deferred to Phase 4: the scaffolder is responsible for generating them when producing a scaffolded project, since they're project-level artifacts rather than parent-skill artifacts. Phase 3 ships the 28 skills they invoke. See [`PHASE-3-PLAN.md`](PHASE-3-PLAN.md) for the full 28-skill implementation plan across 8 clusters.

**Exit criteria:**

- [x] 14 baseline ascent-* SKILL.md files authored with substantive content
- [x] 14 specialized/conditional ascent-* SKILL.md files authored
- [ ] `.claude/commands/` slash-command files (one per skill) — deferred to Phase 4 (scaffolder generates these)
- [x] INTENT-MAP.md populated with all 28 skills, intent classification, cadence guidance
- [x] Each skill's `allowed-tools` is minimal and explicit
- [x] `ascent-skills-doctor` can self-check the skill collection inside a scaffolded project

**Version on completion:** v0.4.0

---

### v0.4.1 — Phase 3 retrospective

**Status:** ✅ Complete (May 21, 2026)

Captures the 5 durable lessons from Phase 3 as framework artifacts: cluster-based PR discipline, four architectural patterns, process-leak class detection, behavior verification as Principle §16, and phase-plan discipline. Matches the v0.3.1 precedent — focused patch adding framework discipline between phase releases. See [`CHANGELOG.md`](../../CHANGELOG.md) for delivery record and [`RETROSPECTIVES/PHASE-3.md`](RETROSPECTIVES/PHASE-3.md) for the narrative account.

### v0.4.2 — Skill hardening and the first plugin

**Status:** ✅ Complete (October 18, 2026)

Two delivery loops. Loop 1 made the 28 embedded-skill tests portable across macOS and Linux, proved each one can fail with named negative controls, and runs the suite in CI on both platforms ([ADR-008](DECISIONS/ADR-008-portable-skill-tests-and-negative-controls.md)). Loop 2 hardened the three security skills and shipped them as the first plugin, `ascent-security`, generated from the template so there is one source of truth ([ADR-009](DECISIONS/ADR-009-plugins-generated-from-template-skills.md)). A trial run on a real repository found two calibration gaps, fixed before release. See [`CHANGELOG.md`](../../CHANGELOG.md).

### v0.4.3 — Security rules, version gate and the delivery-loop plugin

**Status:** ✅ Complete (October 18, 2026)

`ascent-security` 0.1.1 adds two rules surfaced by the trial run: short hardcoded secrets and dynamic code execution. A plugin version gate (`make/plugins.lock`, T10) makes sure installed copies receive every change. `ascent-delivery` 0.1.0 packages the delivery loop with a hook that blocks Claude from git writes and deploys, hardened after an adversarial review and verified on macOS and Linux ([ADR-010](DECISIONS/ADR-010-delivery-loop-plugin-and-operator-boundary-hook.md), Proposed). The plugin roadmap that follows — architecture, ux, ops, quality, session, adr, docs, node-stack — was decided the same day. See [`CHANGELOG.md`](../../CHANGELOG.md).

### v0.4.4 — Architecture plugin

**Status:** ✅ Complete (October 24, 2026)

`ascent-architecture` 0.1.0 reviews a repository's architecture against the project contract, `.ascent/contract.yml`, which every plugin will share. It maps the system, checks quality attributes, design principles, deployment and cost, and rates findings strong, moderate or weak. It compares deployment options with dated cost estimates and hands over a static-site blueprint on AWS ([ADR-011](DECISIONS/ADR-011-architecture-plugin-and-project-contract.md)). A read-only trial on a real repository ran five times and drove two calibration rounds before release. Among the fixes: severities only from the table, a pricing path the review skill could not find, and a missed High for secrets in client code. Thirty-two plugin controls pin the result. See [`CHANGELOG.md`](../../CHANGELOG.md).

### v0.4.5 — UX plugin

**Status:** ✅ Complete (October 25, 2026)

`ascent-ux` 0.1.0 rates a web UI against the `ux:` section of the project contract, with WCAG 2.2 AA evidence from static checks, exact token contrast in every theme, and a Playwright browser pass that overrides both. It checks the design system and offers five predefined design directions as mocks of the project's own pages, each verified before it is shown ([ADR-012](DECISIONS/ADR-012-ux-plugin-design-directions-and-plugin-dependencies.md)). It is the first ASCENT plugin with dependencies: `design`, `frontend-design` and `playwright` install with it. A read-only trial on two real repositories and a re-trial drove two calibration rounds before release. Among the fixes: single-page-app views read from JS template literals, focus outlines judged per selector, line numbers that stay right after non-ASCII text, and delegated click handlers. Forty-six plugin controls (P62–P117) pin the result. See [`CHANGELOG.md`](../../CHANGELOG.md).

### v0.4.6 — Operations plugin

**Status:** ✅ Complete (October 26, 2026)

`ascent-ops` 0.1.0 rates how a system is run, changed and recovered against the `ops:` section of the project contract: secure-by-design IaC configuration (S1–S10), zero-touch scripts and runbooks with pre-flight and post-flight checks (Z1–Z9), and a Maintenance and Operations Manual and a Troubleshooting Manual that a script can prove are current (M1–M8). Health endpoints become `/-/health` and `/-/ready` across the scaffold template ([ADR-013](DECISIONS/ADR-013-ops-plugin-manuals-and-endpoint-names.md), Proposed). A read-only trial on three real repositories drove a calibration round before release.


### v0.4.7 — Housekeeping

**Status:** ✅ Complete (October 26, 2026)

Patch releases `ascent-architecture` 0.1.2, `ascent-delivery` 0.1.1 and `ascent-ux` 0.1.1, shipped in one pull request with the version bump: a stale "planned" mention, the stacked pull request rule in the delivery runbook template, and `--help` for every script in the repository.

---

## Phase 4 — Scaffolding scripts

**Goal:** Ship the executable scripts that perform scaffold, enhance, and migrate operations. Until this phase, the skill describes what to do; in this phase, it actually does it.

**Status:** ⏸️ Awaiting signal

**Exit criteria:**

- [ ] `scripts/scaffold.py` — copies template assets, performs slug substitution, writes `.ascent-meta.json`
- [ ] `scripts/bootstrap.py` — runs after `gh repo create --template` to personalize the starter
- [ ] `scripts/enhance.py` — additive changes for existing ASCENT projects
- [ ] `scripts/migrate.py` — brings non-ASCENT projects to ASCENT
- [ ] All three modes are non-destructive (modify-not-overwrite invariant)
- [ ] Dry-run mode (`--dry-run`) shows planned changes without writing
- [ ] Three test scaffold operations succeed (one per mode) on representative inputs

**Version on completion:** v0.5.0

---

## Phase 5 — Test harness

**Goal:** Build the eval scenario suite that proves the skill produces working projects. After this phase, regressions in skill behavior fail in CI.

**Status:** ⏸️ Awaiting Phase 4 completion

**Exit criteria:**

- [ ] `tests/scenarios/scaffold-basic.md` — eval a basic scaffold operation, verify ~30 assertions
- [ ] `tests/scenarios/enhance-add-endpoint.md` — eval adding an endpoint to a scaffolded project
- [ ] `tests/scenarios/migrate-from-bare.md` — eval migrating a non-ASCENT project
- [ ] `make test` runs all scenarios via Claude with the skill installed
- [ ] CI workflow `.github/workflows/eval-scenarios.yml` runs the test harness on every PR
- [ ] Variance analysis identifies flaky assertions; flakes either fixed or marked

**Version on completion:** v0.6.0

---

## Phase 6 — Starter repo generation

**Goal:** Generate the paired `lloydbriantech-ascent-starter` repository from the skill via CI. Users can `gh repo create --template` for a 5-second working project.

**Status:** ⏸️ Awaiting Phase 5 completion

**Exit criteria:**

- [ ] `tools/build-starter.sh` produces a complete starter repo from the skill's assets
- [ ] The starter repo's `ascent-starter` slug is replaceable via the bootstrap script
- [ ] CI workflow `.github/workflows/release.yml` force-pushes the generated starter to `lloydbrian/lloydbriantech-ascent-starter` on every framework tag
- [ ] The starter repo is marked as a "Template repository" on GitHub
- [ ] `gh repo create --template lloydbrian/lloydbriantech-ascent-starter` produces a working project after running bootstrap

**Version on completion:** v0.7.0

---

## Phase 7 — First production project

**Goal:** Use ASCENT to scaffold and ship a real project to production. This is the framework's first real-world validation. The project's success or failure determines whether v1.0 is warranted.

**Status:** ⏸️ Awaiting Phase 6 completion

**Exit criteria:**

- [ ] A real project (TBD — likely lawn-care-app, family tooling, or NHPTC platform) scaffolded from ASCENT
- [ ] The project completes its own first phase gate per ASCENT phase-delivery protocol
- [ ] The project ships to production (ECS Fargate or local Podman deployment, depending on scope)
- [ ] At least one bug, gap, or rough edge in ASCENT identified and patched as a result of real use
- [ ] A `case-study.md` writeup of the experience added to `docs/framework/`

**Version on completion:** v1.0.0

This is the version that exits alpha. After v1.0, semver protections apply — breaking changes only at major version bumps.

---

## Post-v1.0 ideas (not committed)

Things the author has considered but is not committing to:

- A `lloydbriantech-ascent-python` variant for Python-backend projects (FastAPI + SQLite + React)
- A `lloydbriantech-ascent-mobile` variant for React Native projects (unclear if ASCENT's invariants port cleanly)
- An IDE extension that surfaces `ascent-*` skills as commands and shows phase status in the status bar
- A web-based starter that runs the bootstrap interactively
- Multi-region deployment patterns
- Service-mesh integration patterns

These are speculation. The roadmap from v1.0 onward will be driven by real needs from real projects, not by hypothetical features.

---

## What happens at each phase gate

The phase-delivery protocol applies here too:

1. The owner verifies all exit criteria for the current phase
2. The owner updates `CHANGELOG.md` with the phase summary
3. The owner tags the release (`git tag v0.N.0 && git push origin v0.N.0`)
4. The release workflow creates the GitHub release with the CHANGELOG entry
5. The owner waits for explicit signal: **"Proceed with Phase N+1"**
6. Phase status updates in `CLAUDE.md` and this ROADMAP.md
7. Phase N+1 begins

Skipping a phase is not allowed. The dependency chain is explicit because the framework's quality depends on the earlier phases being solid before later phases build on them.

---

*This roadmap will be updated as phases complete. The latest version always reflects the current plan, not the original one — phases can be revised, but only via the explicit phase-transition protocol.*
