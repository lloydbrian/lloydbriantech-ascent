# Changelog

All notable changes to the `lloydbriantech-ascent` framework will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Dates are in **America/New_York** timezone.

---

## [Unreleased]

### Added

- `.github/SECURITY.md` — vulnerability disclosure policy
- `.github/CODE_OF_CONDUCT.md` — concise community expectations
- `.github/CODEOWNERS` — automatic PR review assignment

### Changed

- Repository visibility flipped from private to public for the duration of development (originally planned for v1.0)

### Planned

- Phase 1 — Parent skill SKILL.md, reference modules, role routing
- Phase 2 — Template assets (substantive baseline content)
- Phase 3 — Project-embedded skills (22 SKILL.md scaffolds)
- Phase 4 — Scaffolding scripts (`scaffold.py`, `bootstrap.py`)
- Phase 5 — Test harness with three eval scenarios
- Phase 6 — Starter repo generation tooling
- Phase 7 — First production project scaffolded from ASCENT

See [`docs/framework/ROADMAP.md`](docs/framework/ROADMAP.md) for the full roadmap.

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

[Unreleased]: https://github.com/lloydbrian/lloydbriantech-ascent/compare/v0.1.0-alpha...HEAD
[0.1.0-alpha]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.1.0-alpha
