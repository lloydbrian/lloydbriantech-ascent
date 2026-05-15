# ADR-005: Skill naming — `lloydbriantech-ascent` parent, `ascent-*` project-embedded

**Status:** Accepted
**Date:** 2026-05-14 (America/New_York)
**Decider:** lloydbriantech

## Context

The framework ships two categories of Claude skills with different scopes and different lifecycles:

**Category A — Scaffolding-time skills** that live globally in the user's `~/.claude/skills/` directory. Used to create new ASCENT projects, enhance existing ones, or migrate non-ASCENT projects. One skill: `lloydbriantech-ascent` per [ADR-001](ADR-001-single-parent-skill.md).

**Category B — Operational skills** that live inside scaffolded projects at `.claude/skills/`. Used during the project's day-to-day work — running pre-flight checks, generating standups, auditing the project's hygiene, computing release readiness. There are 14 baseline and up to 8 conditional ones per architect interview answers.

These two categories serve different audiences:

- Category A skills are how the user *builds projects with the framework*. They're invoked once or occasionally per project (mostly at scaffold time, occasionally at enhance time).
- Category B skills are how the user *operates a scaffolded project*. They're invoked frequently — standups every morning, audits before commits, release readiness before deploys.

The naming has to distinguish them so that:

- Users browsing `~/.claude/skills/` see the framework as one entry, not 23
- Users browsing a project's `.claude/skills/` see only the project-relevant skills
- Slash commands inside a project are short and ergonomic (frequent use)
- Skill search and skill descriptions don't collide between the two categories

## Decision

**Parent (scaffolding) skill:** `lloydbriantech-ascent` — one word for the framework (no separator before "ascent"). The owner namespace (`lloydbriantech`) prefixes the framework name (`ascent`) so that users with multiple frameworks installed see each owner's contributions grouped.

**Project-embedded (operational) skills:** Prefixed `ascent-`, invoked as `/ascent-<name>`. Examples: `/ascent-reflect`, `/ascent-standup`, `/ascent-health`, `/ascent-delivery-status`.

The reasoning for the asymmetry:

- The parent skill is global and benefits from owner namespacing (multi-framework disambiguation)
- The project-embedded skills are local to a project and don't compete with other frameworks' skills — the project's `.claude/skills/` directory is its own namespace
- The `ascent-` prefix on project-embedded skills carries enough information (which framework they came from) without the longer `lloydbriantech-ascent-` becoming a typing burden for frequently-used operational commands

**Naming inside each category:**

- Project-embedded skill names use **kebab-case verbs or noun phrases describing intent**: `ascent-reflect`, `ascent-standup`, `ascent-handoff`, `ascent-onboard`, `ascent-self-audit`, `ascent-release-readiness`, `ascent-skills-doctor`
- Intent classification (used in INTENT-MAP.md) tags each skill: `context`, `diagnostic`, `sweep`, `gate`, `posture`
- Names never exceed 24 characters total — `ascent-` (7 chars) plus up to 17 for the action

## Alternatives considered

**One unified prefix for both categories** — `lloydbriantech-ascent-architect`, `lloydbriantech-ascent-reflect`, etc. Rejected because:

1. Slash commands like `/lloydbriantech-ascent-reflect` are too long for daily use
2. The parent skill ends up sharing a prefix with project-embedded skills, defeating the scope-disambiguation we want

**Inverse asymmetry** — parent skill is `ascent`, project-embedded are `lloydbriantech-ascent-<name>`. Rejected because:

1. The parent skill loses its owner namespacing (no disambiguation if another `ascent` framework exists)
2. The project-embedded skills carry the longest names where they're invoked most frequently

**Drop the framework prefix entirely from project-embedded skills** — name them `/reflect`, `/standup`, etc. Rejected because:

1. These names would collide with user-defined commands or commands from other tools the user installs
2. The `ascent-` prefix is documentation in itself — when you see `/ascent-standup`, you know which framework's discipline you're invoking

**Use a different prefix entirely for project-embedded** — e.g., `lbd-` for "lloydbriantech daily". Rejected because:

1. Adds a second mental brand to learn
2. The connection between the parent skill and the project-embedded skills becomes opaque

**Match the package-name-mangling style** — `@lloydbriantech/ascent`, `@lloydbriantech/ascent-reflect`. Rejected because:

1. Claude skill names don't support the `@scope/name` pattern
2. The mangling adds nothing the simpler prefix doesn't already give

## Consequences

**Easier:**

- Parent skill is one entry in `~/.claude/skills/`, clearly owner-namespaced
- Project-embedded skills are short to type and easy to remember
- The `ascent-` prefix is self-documenting — anyone reading slash commands knows the framework
- Two distinct prefixes mean no skill-loading collision between categories
- Cross-project consistency: every ASCENT project has the same set of `ascent-*` skills, building muscle memory

**Harder:**

- Two prefix conventions means contributors must remember which prefix applies in which context — but this is documented and infrequent
- The asymmetry might look inconsistent to a first-time observer until they understand the scope distinction

**Neutral:**

- The naming applies forward to any future framework Anthropic skills the author might author under the same owner — `lloydbriantech-<name>` for parent skills is the established pattern

## Cost implications

**Time:** Saves time on every slash-command invocation across the project's life. Each `/ascent-standup` is shorter than `/lloydbriantech-ascent-standup` would be.

**Complexity:** Two conventions to remember instead of one, but the contexts where each applies are non-overlapping, so the cost is small.

**Future flexibility:** The convention extends naturally — additional parent skills under the same owner use `lloydbriantech-<name>`; additional frameworks owned by others use their own owner namespace.

**Money:** None.
