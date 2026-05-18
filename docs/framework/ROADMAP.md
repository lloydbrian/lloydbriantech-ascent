# ASCENT Roadmap

The phase plan from v0.1-alpha (this release) to v1.0. Each phase has explicit exit criteria. No phase begins without the literal "Proceed with Phase N" signal — the framework dogfoods its own phase-delivery discipline.

**Current state:** Phase 2 — Template assets complete, v0.3.1, May 17, 2026. Phase 3 awaiting signal.

---

## Phase 0 — Foundation

**Goal:** Establish framework identity, conventions, and architectural decisions. Ship the meta-repository foundation so future phases have a structured place to land.

**Status:** ✅ Complete (this release, May 14, 2026)

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

**Goal:** Author the SKILL.md files for all 14 baseline project-embedded skills and the 8 conditional ones. Each skill is invocable inside a scaffolded project.

**Status:** ⏸️ Awaiting signal

Note: §15 implementation extends `ascent-delivery-status` (read session state) and `ascent-feature-intake` (write to working memory) — covered as part of Phase 3 skill implementation work.

**Exit criteria:**

- [ ] 14 baseline ascent-* SKILL.md files authored with substantive content
- [ ] 8 conditional ascent-* SKILL.md files authored
- [ ] `.claude/commands/` slash-command files (one per skill)
- [ ] INTENT-MAP.md populated with all 22 skills, intent classification, cadence guidance
- [ ] Each skill's `allowed-tools` is minimal and explicit
- [ ] `ascent-skills-doctor` can self-check the skill collection inside a scaffolded project

**Version on completion:** v0.4.0

---

## Phase 4 — Scaffolding scripts

**Goal:** Ship the executable scripts that perform scaffold, enhance, and migrate operations. Until this phase, the skill describes what to do; in this phase, it actually does it.

**Status:** ⏸️ Awaiting Phase 3 completion

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
3. The owner tags the release (`git tag v0.N.0 && git push --tags`)
4. The release workflow creates the GitHub release with the CHANGELOG entry
5. The owner waits for explicit signal: **"Proceed with Phase N+1"**
6. Phase status updates in `CLAUDE.md` and this ROADMAP.md
7. Phase N+1 begins

Skipping a phase is not allowed. The dependency chain is explicit because the framework's quality depends on the earlier phases being solid before later phases build on them.

---

*This roadmap will be updated as phases complete. The latest version always reflects the current plan, not the original one — phases can be revised, but only via the explicit phase-transition protocol.*
