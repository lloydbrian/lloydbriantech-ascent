# Changelog

All notable changes to the `lloydbriantech-ascent` framework will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Dates are in **America/New_York** timezone.

---

## [Unreleased]

### Planned

- Phase 3 — Project-embedded skills (22 SKILL.md scaffolds)
- Phase 4 — Scaffolding scripts (`scaffold.py`, `bootstrap.py`)
- Phase 5 — Test harness with three eval scenarios
- Phase 6 — Starter repo generation tooling
- Phase 7 — First production project scaffolded from ASCENT

See [`docs/framework/ROADMAP.md`](docs/framework/ROADMAP.md) for the full roadmap.

---

## [0.3.1] — 2026-05-17

**Session resumption protocol.** ASCENT now treats session resumption as a first-class concern. Long projects span dozens of sessions; this patch makes "where we left off" an explicit, machine-readable artifact rather than something Claude is asked to remember.

### Added

#### Framework commitments (Chunk 1)

- Principle §15: Session resumption — project state is durable, machine-readable, and inspected on every session start
- `session-protocol.md` reference module — the authoritative specification: four file states (MISSING/EMPTY/STALE/FRESH), 6-step resumption protocol, capture discipline, verification mechanism
- ROADMAP v0.3.1 entry between Phase 2 (complete) and Phase 3 (awaiting signal)

#### Template artifacts (Chunk 2)

- `docs/delivery/` directory with README, `working-memory.md` (git-tracked, accumulating), `session-state.md` (gitignored, transient), `snapshots/` archive
- `make session-snapshot` — captures current state to `session-state.md` + archives to `snapshots/YYYY-MM-DD-HHMM.md`. Reads git state and `.ascent-meta.json` automatically; prompts for human-judgment fields.
- `make session-resume` — displays both files with MISSING/EMPTY/STALE/FRESH classification. The verification mechanism: shows exactly what Claude reads on session start.
- `CLAUDE.md.tmpl` protocol section — what Claude reads on session start: file-state handling, source-citation commitment, confabulation refusal, verification via `make session-resume`
- `.gitignore.tmpl` updated: `docs/delivery/session-state.md` gitignored (transient); `working-memory.md` stays tracked
- `make/session.mk` with `SHELL := /bin/bash` pinned for `local` variable support

#### Skill scaffold extensions (Chunk 3)

- `ascent-delivery-status` operational-logic paragraph extended: reads `session-state.md` for current focus + `working-memory.md` for accumulated decisions into status synthesis
- `ascent-feature-intake` operational-logic paragraph extended: writes locked acceptance criteria as dated entries to `working-memory.md`

### Changed

- Framework version: 0.3.0 → 0.3.1
- Principles count: 14 → 15
- ROADMAP.md: v0.3.1 ✅ complete; Phase 3 status note about §15 skill extensions
- CLAUDE.md (framework): v0.3.1 complete
- `session-protocol.md` cross-references: stale "template lands in v0.3.1 Chunk 2" suffixes replaced with substantive descriptions (templates now exist)

### Decided

- **Four-state file classification** (MISSING/EMPTY/STALE/FRESH) — eliminates ambiguity; truly-empty scaffold ships as EMPTY by design
- **Dual-write architecture** — `session-state.md` (current state, overwritten) + `snapshots/YYYY-MM-DD-HHMM.md` (history, git-tracked)
- **`session-state.md` gitignored, `working-memory.md` tracked** — transient vs accumulating concerns separated cleanly
- **No make target aliases** — `make session-snapshot` is canonical; `make session-checkpoint` was considered and dropped (Principle 2: one name per operation)
- **Citation-by-filename + `make session-resume`** — the honest verification chain; Claude refuses to confabulate prior context not grounded in the files
- **`session-state.md.tmpl` ships truly empty** (title only) — classifies as EMPTY on session start until first `make session-snapshot` populates it; avoids ambiguity between EMPTY and FRESH states

### Deferred

- Full `ascent-delivery-status` skill implementation reading session state into synthesis — Phase 3
- Full `ascent-feature-intake` skill implementation writing locked criteria to working memory — Phase 3
- Automatic-on-commit capture (git hook integration) — Phase 3 design discussion
- Claude-judgment-based capture during sessions (recognizing decision-moments) — Phase 3 design discussion
- `.ascent-meta.json` extension for configurable staleness threshold — currently hardcoded at 7 days

### Statistics

- 3 PRs (#18, #19, #20) across 3 chunks of v0.3.1 work
- 1 new principle (§15) + 1 new reference module + 5 new template files + 4 surgical template edits + 2 skill scaffold extensions + 4 stale-suffix cleanups
- 80 files / 167 placeholder names validated by `make qa-template-placeholders`
- 298 internal markdown links validated by `make qa-links` across 58 files

---

## [0.3.0] — 2026-05-16

**Phase 2 — Template assets.** The substantive baseline content for every file the architect role emits at scaffold time. After this phase, a project scaffolded from these templates produces a working stack: `make dev-up` boots backend + frontend + nginx; the layered API serves CRUD operations; observability emits per contract; tests pass.

### Added

#### Root template files (Chunk 1)

- `assets/template/` directory established with README.md.tmpl, CLAUDE.md.tmpl, CHANGELOG.md.tmpl, .ascent-meta.json.tmpl, LICENSE files, .gitignore.tmpl, .dockerignore.tmpl, .env.example, .claudeignore.tmpl, .editorconfig
- `make qa-template-placeholders` validator: validates every `<<PLACEHOLDER>>` token against the canonical 20-name set
- `FRAMEWORK_VERSION` bumped to 0.3.0 (lockstep); `<<PROJECT_VERSION>>` added as 20th canonical placeholder

#### Make framework (Chunk 2)

- Project-level Makefile + 9 child `.mk` files using SDLC section order META · DEV · TEST · QA · SEC · VALIDATE · DOCS · INFRA
- Real targets: `make help`, `make version`, `make status`, `make dev-up`/`dev-down`/`dev-logs`/`dev-shell`/`dev-restart`/`dev-clean`, `make dev-status`/`dev-status-quick`, `make engine-clean-project`/`engine-clean-images`/`engine-clean-volumes`
- 17 stub targets across 6 `.mk` files using project-level `[STUB] implement when <context>` convention

#### Container topology (Chunk 3)

- docker-compose family: dev (base), prod (overrides), prod.local (local testing), dist (standalone), suite (test runner)
- nginx/ skeleton: dev (Vite proxy + HMR), prod (static + security headers + caching), dist (standalone)
- Backend healthcheck enables `depends_on: condition: service_healthy` for nginx
- All resources labeled `project=<<PROJECT_LABEL>>` per Principle 9

#### Backend skeleton (Chunk 4)

- Working `server.js` with Express + structured logging + graceful shutdown (SIGTERM + 15s drain)
- Full `routes → controllers → services → storage` layering with `/api/items` GET + POST
- `/healthz` (liveness, no DB) + `/readyz` (readiness, DB + schema check) — deliberately differentiated
- SQLite-WAL via `better-sqlite3` with migration runner (~30 lines, no library dependency)
- Middleware: request-id (W3C TraceContext extraction), pino-http logger, error handler (sanitized in prod)
- Observability: structured logger, trace utilities, metrics counter scaffold
- Multi-stage Dockerfile (builder + production + development) with `build-base python3` for native compilation
- Vitest test file (3 tests) proving the runner works
- Pinned dependencies (no `^` or `~`): express 4.21.2, better-sqlite3 11.7.0, pino 9.6.0

#### Frontend skeleton (Chunk 5)

- Vite + React 19 shell with working `/api/items` integration (GET list + POST form)
- Three-stage Dockerfile (builder + production + development) with development as last stage (compose default)
- `server.host: '0.0.0.0'` in vite.config.js + package.json dev script (Vite-in-Docker gotcha prevented)
- Plain CSS styling (system-ui font, minimal, not opinionated about framework)

#### Project ADRs (Chunk 6)

- 7 always-emitted project-level ADRs using canonical template (Context, Decision, Alternatives, Consequences, Cost implications)
- ADR-001 Container-first, ADR-002 Backend layering, ADR-003 Make vocabulary, ADR-004 SQLite-WAL, ADR-005 JSON logging, ADR-006 Dual licensing, ADR-007 Phase-gated delivery
- INDEX.md with supersession documentation ("ADR-008 supersedes ADR-004 for projects choosing Postgres")
- Cross-reference graph: ADR-002→001, ADR-004→002, ADR-005→001, ADR-007→003

#### Embedded skills (Chunk 7)

- 9 baseline `ascent-*` project-embedded skill scaffolds at substantive-scaffold standard
- Structural enforcement (5 read-only): ascent-self-audit (umbrella), ascent-layering-check, ascent-env-audit, ascent-observability-check, ascent-delivery-status
- Authoring assistance (4 write-capable): ascent-adr-write, ascent-doc-stub, ascent-make-target, ascent-feature-intake
- INTENT-MAP.md: intent→skill table with cadence column (per-commit, daily, per-feature, per-decision, per-deploy)

#### Smoke test (Chunk 8)

- `tools/scratch/scaffold-hello-world.sh` — one-shot scaffold script (cp + sed substitution)
- `tools/scratch/SMOKE-TEST-LOG.md` — durable verification evidence (14/14 steps PASS)
- 5 template bugs found and fixed during smoke test (documented in log)

### Changed

- Framework version: 0.2.0 → 0.3.0
- `ROADMAP.md`: Phase 2 marked ✅ complete; Phase 3 marked ⏸️ awaiting signal
- `CLAUDE.md` phase status: Phase 1 complete → Phase 2 complete
- `.gitignore`: `tools/scratch/` pattern adjusted to allow tracking scaffold scripts while ignoring outputs
- Backend Dockerfile: added development stage (last) + `npm ci` → `npm install` (lockfile not required at scaffold time)
- Frontend Dockerfile: `npm ci` → `npm install` (same lockfile fix)
- `docker-compose.yml`: backend data volume changed from named to bind mount for dev (host-visible for dev-status)

### Decided

- **Substantive-scaffold standard** for embedded skills: Frontmatter + Header + Inputs/Outputs + Operational-logic paragraph + Examples pointer + Anti-patterns paragraph. Phase 3 fills in full decision trees.
- **5+4 split** for project-embedded skills: 5 read-only audit/check + 4 write-capable authoring assistance
- **SQLite-WAL as default database** (ADR-004) with documented supersession path to Postgres when projects outgrow it
- **Three-stage Dockerfile pattern** (builder + production + development) with development as last stage = compose default
- **Backend healthcheck + nginx `service_healthy` dependency** closes the `make dev-up` → immediately ready gap
- **Container-first dependency management** — host `npm install` removed from scaffold; container handles deps per Principle 1
- **`npm install` over `npm ci` in Dockerfiles** — templates ship without lockfiles; `npm install` generates them at build time

### Deferred

- 22 additional project-embedded skill scaffolds (5 baseline remaining + 7 specialized + 8 conditional) — Phase 3
- Production scaffolding script (`scaffold.py`, `bootstrap.py`, `enhance.py`, `migrate.py`) — Phase 4
- Phase 4 carry-forward: how `scaffold.py` handles host Node version compatibility (container-only vs hybrid vs host-aware)
- Eval test scenarios — Phase 5
- Starter repo generation tooling — Phase 6
- First production project scaffolded from ASCENT — Phase 7

### Statistics

- 8 PRs (#9–#16) across 8 chunks of Phase 2 work
- 75+ template files scanned by `make qa-template-placeholders`; 165 unique placeholder names validated against canonical 20-name set
- 10 SKILL.md files validated by `make qa-skill-frontmatter` (1 parent + 9 embedded)
- 293 internal markdown links validated by `make qa-links` across 57 files
- 1 functional exit criterion met: 14/14 smoke test steps PASS (first in framework history)
- 5 template bugs found and fixed during smoke test (durable evidence in `tools/scratch/SMOKE-TEST-LOG.md`)

---

## [0.2.0] — 2026-05-15

**Phase 1 — Parent skill skeleton.** The framework's first executable layer. SKILL.md with routing logic, 21 reference modules, the `make` operator vocabulary, and the QA validators that keep them honest.

### Added

#### Operator vocabulary (Chunk 1)

- Root `Makefile` and `make/*.mk` SDLC-sectioned tree (META · DEV · TEST · QA · DOCS · DIST · RELEASE)
- Working targets: `make help` (default), `make version`, `make status`, `make install` / `make uninstall`, `make qa-skill-frontmatter`, `make qa-links`, `make qa`, `make release-tag`
- Stub targets per Principle 4 (stub-first naming): `make test`, `make doc-stub`, `make package`, `make release`
- Bash 3.2–compatible validator scripts: `make/qa-skill-frontmatter.sh`, `make/qa-links.sh`, `make/help.sh`

#### Parent skill (Chunks 2 + 6)

- `skills/lloydbriantech-ascent/SKILL.md` — frontmatter (name, description, version 0.2.0, allowed-tools), trigger conditions, operating modes table, nine-role mental model, references index, routing logic (3 stages per ADR-001), 13 representative examples, "does not engage when" boundary

#### Reference modules — protocols and conventions (Chunk 3)

- `references/ASCENT-INVARIANTS.md` — 14 invariants in runtime form
- `references/MAKE-NAMING.md` — make-target naming convention
- `references/SLUG-CONVENTIONS.md` — slug taxonomy and derivation
- `references/PHASE-PROTOCOL.md` — phase-gated delivery contract
- `references/ENV-DISCIPLINE.md` — `.env` handling rules
- `references/ADR-TEMPLATE.md` — canonical ADR format

#### Reference modules — practices and style (Chunk 4)

- `references/feature-lifecycle.md` — happy-path role flow
- `references/observability-contract.md` — JSON logs / Prometheus metrics / W3C traces baseline
- `references/writing-style.md` — voice, tense, anti-patterns (dogfooded with framework prose)
- `references/doc-architecture.md` — doc-graph rules, 3-click depth limit
- `references/audience-mapping.md` — canonical persona→entry-point mapping
- `references/external-services-integration.md` — vendor pattern (wrapper, retry, secrets, observability)

#### Reference modules — roles (Chunk 5)

- `references/role-delivery-lead.md` — phase plans, escalation, kill criteria
- `references/role-architect.md` — design discipline, ADR practice, specialist engagement
- `references/role-ui-ux-designer.md` — design system, accessibility-as-design
- `references/role-developer.md` — backend layering + frontend conventions (one role per ADR-001)
- `references/role-data-engineer.md` — schema, indexing, migration safety
- `references/role-ai-engineer.md` — prompts, evals, model abstraction, safety guardrails
- `references/role-tester.md` — test discipline hierarchy, NFR catalog, traceability
- `references/role-devops.md` — CI/CD, AWS, observability collection, releases
- `references/role-cybersecurity.md` — baseline, threat modeling, secret management

#### Repository hygiene (between v0.1.0-alpha and v0.2.0)

- `.github/SECURITY.md` — vulnerability disclosure policy
- `.github/CODE_OF_CONDUCT.md` — concise community expectations
- `.github/CODEOWNERS` — automatic PR review assignment

### Changed

- Repository visibility flipped from private to public for the duration of development (originally planned for v1.0)
- `CLAUDE.md` phase status: Phase 0 — Foundation → Phase 1 — Parent skill skeleton (complete)
- `docs/framework/ROADMAP.md`: Phase 1 marked ✅ complete; Phase 2 marked ⏸️ awaiting signal
- `README.md` adds "Documentation by persona" section referencing `audience-mapping.md` as canonical (per architectural review during Chunk 4)
- `CONTRIBUTING.md` adds "Cross-linking in reference modules" rule statement codifying the document-map discipline applied across all 21 reference modules
- `SKILL.md` Operating modes section: ADR-003 second mention demoted to plain text (Rule 1 violation cleanup)

### Decided

- **Cross-linking discipline for reference modules.** Each module's header carries 1–2 authoritative links; body content links to siblings, ADRs, and `docs/framework/` documents on first mention only; subsequent mentions stay as code spans or plain text. Code paths, make targets, and skill names stay as code spans regardless. Forward references to unlanded modules stay as code spans until promotion. The full 7-rule statement lives in `CONTRIBUTING.md`.
- **Routing logic operationalizes ADR-001's three-stage shape:** mode detection (`.ascent-meta.json` per ADR-003) → role inference (explicit, implicit, or multi-role expansion) → reference-module loading (always / per-mode / per-role, lazily).
- **Minimum-sufficient principle.** Engage the smallest set of roles that fully covers the task. When intent is ambiguous, ask a clarifying question; multi-role expansion is the wrong default response to ambiguity.
- **Skill talks but does not yet write.** Phase 1 constraint upheld; scaffolding scripts arrive in Phase 4.

### Deferred

- Template assets (substantive baseline content for every file the architect role emits) — Phase 2
- Project-embedded skill SKILL.md files (14 baseline + 8 conditional) — Phase 3
- Scaffolding scripts (`scaffold.py`, `bootstrap.py`, `enhance.py`, `migrate.py`) — Phase 4
- Eval test scenarios — Phase 5
- Starter repo generation tooling — Phase 6
- First production project scaffolded from ASCENT — Phase 7

### Statistics

- 7 PRs across the v0.1.0-alpha → v0.2.0 development window (PR #1 hygiene + PR #2–#7 substantive chunks)
- 21 reference modules under `skills/lloydbriantech-ascent/references/`
- `SKILL.md` grew from 0 lines to 296 lines across the phase
- `make qa-links` validates 263 internal markdown links across 39 files; `make qa-skill-frontmatter` validates 1 SKILL.md

---

## [0.1.0-alpha] — 2026-05-14

**Phase 0 — Foundation.** Meta-repository foundation. Framework identity, conventions, and architectural decisions established. No skill code yet — this release is the rationale, scope, and decisions that will guide every subsequent phase.

### Added

#### Framework identity

- `README.md` — framework overview, install paths, role inventory, mode taxonomy, project-embedded skill catalog, documentation map
- `CLAUDE.md` — working conventions for the meta-repository itself
- `LICENSE`, `LICENSE-MIT`, `LICENSE-APACHE` — dual MIT/Apache-2.0 licensing
- `CONTRIBUTING.md` — contribution model, versioning approach, review bar, role-addition criteria

#### Framework documentation

- `docs/framework/PRINCIPLES.md` — the fourteen ASCENT invariants in narrative form
- `docs/framework/PHILOSOPHY.md` — why ASCENT exists, what problems it solves, what it deliberately is not
- `docs/framework/SCOPE.md` — what ASCENT is for, what it isn't, the exit story
- `docs/framework/ROADMAP.md` — phase plan from v0.1 to v1.0 with exit criteria per phase
- `docs/framework/ARCHITECTURE.md` — the framework's own architecture: meta-repo + skill + starter + project-embedded layer

#### Framework decisions (ADRs)

- `ADR-001` — single parent skill (consolidated from six-role design) to avoid trigger collision
- `ADR-002` — modify-not-overwrite contract for all skill interactions with existing files
- `ADR-003` — `.ascent-meta.json` as project-root marker for mode detection (scaffold / enhance / migrate)
- `ADR-004` — slug conventions (kebab-case, 2–4 segments, mechanical derivations)
- `ADR-005` — skill naming convention (`lloydbriantech-ascent` parent, `ascent-*` project-embedded)
- `ADR-006` — dual MIT/Apache-2.0 licensing (Rust-ecosystem convention)
- `ADR-007` — template repo pairing (`lloydbriantech-ascent-starter` generated from skill via CI)

#### Tooling and editor conventions

- `.gitignore` — Python, Node, OS, and editor patterns
- `.editorconfig` — consistent indentation, line endings, final newlines across editors
- `.github/workflows/validate-skills.yml` — CI placeholder for Phase 1+ skill validation
- `.github/workflows/release.yml` — CI placeholder for Phase 6+ release pipeline
- `.github/ISSUE_TEMPLATE/{skill-bug, new-skill-proposal, enhancement}.md` — structured intake templates
- `.github/PULL_REQUEST_TEMPLATE.md` — PR checklist aligned with framework conventions
- `.vscode/{extensions, settings, tasks}.json` — recommended VS Code config for working on the framework

### Decided

- The framework is dual-licensed MIT OR Apache-2.0 at the user's option
- The framework dogfoods ASCENT conventions on itself wherever applicable
- The framework version applies to both the skill and the starter repo in lockstep
- Phase 0 ships no executable code — only identity, conventions, and decisions

### Deferred

- The Makefile and `make/` operator vocabulary — arrives in Phase 1
- The skill itself (`skills/lloydbriantech-ascent/SKILL.md`) — arrives in Phase 1
- Reference modules (~30 files) — arrives in Phase 1
- Template assets — arrives in Phase 2
- Project-embedded skill SKILL.md files — arrives in Phase 3
- Eval test scenarios — arrives in Phase 5

---

[Unreleased]: https://github.com/lloydbrian/lloydbriantech-ascent/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.3.1
[0.3.0]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.3.0
[0.2.0]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.2.0
[0.1.0-alpha]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.1.0-alpha
