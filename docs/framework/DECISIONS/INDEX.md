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
