# Changelog

All notable changes to the `lloydbriantech-ascent` framework will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Dates are in **America/New_York** timezone.

---

## [Unreleased]

### Planned

- Phase 2 — Template assets (substantive baseline content)
- Phase 3 — Project-embedded skills (22 SKILL.md scaffolds)
- Phase 4 — Scaffolding scripts (`scaffold.py`, `bootstrap.py`)
- Phase 5 — Test harness with three eval scenarios
- Phase 6 — Starter repo generation tooling
- Phase 7 — First production project scaffolded from ASCENT

See [`docs/framework/ROADMAP.md`](docs/framework/ROADMAP.md) for the full roadmap.

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

[Unreleased]: https://github.com/lloydbrian/lloydbriantech-ascent/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.2.0
[0.1.0-alpha]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.1.0-alpha
