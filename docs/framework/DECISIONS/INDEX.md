# Architectural Decision Records — Index

All architectural decisions for the ASCENT framework itself. Project-level ADRs live in scaffolded projects, not here.

The format follows Michael Nygard's ADR pattern, with one ASCENT extension: every ADR includes a **Cost implications** section in addition to the standard Context / Decision / Alternatives / Consequences.

Dates are in **America/New_York** timezone.

---

| # | Title | Status | Date | Summary |
|---|---|---|---|---|
| [001](ADR-001-single-parent-skill.md) | Single parent skill with internal role routing | Accepted | 2026-05-14 | Collapse six proposed parent skills into one to avoid trigger collision in Claude's skill system |
| [002](ADR-002-modify-not-overwrite.md) | Modify-not-overwrite contract for all skill writes | Accepted | 2026-05-14 | Skill operations on existing projects use surgical edits, never whole-file overwrites, to preserve user customization across multi-mode operation |
| [003](ADR-003-ascent-meta-marker.md) | `.ascent-meta.json` at project root as mode-detection marker | Accepted | 2026-05-14 | A flat metadata file at the project root marks ASCENT projects and drives mode selection (scaffold / enhance / migrate / bootstrap) |
| [004](ADR-004-slug-conventions.md) | Slug taxonomy — kebab-case, 2–4 segments, mechanical derivation | Accepted | 2026-05-14 | User supplies one project slug; all variants (uppercase env-var prefix, container labels, title case, package names) derive mechanically |
| [005](ADR-005-skill-naming.md) | Skill naming — `lloydbriantech-ascent` parent, `ascent-*` project-embedded | Accepted | 2026-05-14 | Distinct prefixes disambiguate scaffolding-time skills (live globally) from operational skills (live in scaffolded projects) |
| [006](ADR-006-dual-licensing.md) | Dual MIT OR Apache-2.0 license | Accepted | 2026-05-14 | Adopt the Rust-ecosystem convention to maximize adoption while providing explicit patent grant for corporate users |
| [007](ADR-007-template-repo-pairing.md) | Template repo paired with skill via CI generation | Accepted | 2026-05-14 | A separate `lloydbriantech-ascent-starter` GitHub template repo is generated from the skill on every release tag |
| [008](ADR-008-portable-skill-tests-and-negative-controls.md) | Portable skill tests and named negative controls | Accepted | 2026-10-17 | Skill tests behave the same on GNU/Linux and BSD/macOS, every check is shown to pass and fail, named mutants prove each test can fail, and CI runs the suite on both platforms |
| [009](ADR-009-plugins-generated-from-template-skills.md) | Plugins generated from the template skills | Accepted | 2026-10-17 | Plugin skills are built from the template by `make plugins`, never hand-edited; `make test-plugins` fails on drift; plugins live in this repo until the marketplace repo exists |
| [010](ADR-010-delivery-loop-plugin-and-operator-boundary-hook.md) | Delivery-loop plugin and operator-boundary hook | Proposed | 2026-10-18 | `ascent-delivery` ships the delivery loop as a hand-written plugin skill; a PreToolUse hook blocks git writes and deploys for Claude; review wraps installed providers; `.delivery-loop.yml` is the project contract |
| [011](ADR-011-architecture-plugin-and-project-contract.md) | Architecture plugin and the project contract file | Accepted | 2026-10-18 | `ascent-architecture` reviews architecture against targets in `.ascent/contract.yml`; enterprise maturity by default with waivers in ADRs; dated cost estimates; a tested CloudFormation static-site blueprint and template checks; T11 covers plugin scripts |
| [012](ADR-012-ux-plugin-design-directions-and-plugin-dependencies.md) | UX plugin, design directions and plugin dependencies | Accepted | 2026-10-24 | `ascent-ux` gathers WCAG 2.2 AA evidence (browser pass authoritative, static checks as fallback, exact token contrast), checks the design system, and offers five accessible design directions as mocks; companion plugins are dependencies; T12 checks manifest keys and the cross-marketplace allowlist |
| [013](ADR-013-ops-plugin-manuals-and-endpoint-names.md) | Operations plugin, operations manuals and health endpoint names | Proposed | 2026-10-25 | `ascent-ops` checks secure configuration (S1–S10), zero-touch scripts and runbooks (Z1–Z9) and two current operations manuals with C4 diagrams (M1–M8); health endpoints are `/-/health`, `/-/ready` and `/-/started`, overridable in the contract, renamed everywhere from `/healthz` |

---

## How to add a new ADR

1. Pick the next available number (e.g., ADR-008)
2. Create `ADR-NNN-<kebab-slug>.md` using the canonical template
3. Add a row to this index table in numeric order
4. Submit as part of the PR that implements (or proposes) the decision

If the new ADR supersedes an existing one:

- The new ADR cites the old one in its Context section
- The old ADR's status changes to `Superseded by ADR-NNN`
- The old ADR keeps its number — never renumbered

## The canonical template

```markdown
# ADR-NNN: <Title>

**Status:** Proposed | Accepted | Superseded by ADR-XXX
**Date:** YYYY-MM-DD (America/New_York)
**Decider:** lloydbriantech

## Context

What is the issue we're seeing that is motivating this decision?

## Decision

What is the change we're proposing or have agreed to implement?

## Alternatives considered

What other options were on the table? Why were they rejected?

## Consequences

What becomes easier or more difficult as a result? Trade-offs accepted?

## Cost implications

What does this decision cost — in time, money, complexity, or future flexibility?
```

Every section is required. An ADR missing a section is incomplete.
