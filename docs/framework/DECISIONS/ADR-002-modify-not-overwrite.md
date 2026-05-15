# ADR-002: Modify-not-overwrite contract for all skill writes

**Status:** Accepted
**Date:** 2026-05-14 (America/New_York)
**Decider:** lloydbriantech

## Context

The parent skill operates in three modes after scaffolding: `enhance` (adding new things), `migrate` (bringing an existing project to ASCENT standards), and the scaffolding itself for new projects. Each mode writes to a target directory that may already contain user customizations.

A naive implementation would re-emit template files whenever the skill runs. This produces three problems:

**User customizations are lost.** A user who has edited their `nginx.prod.conf` to add a custom redirect, or their `server.js` to add a feature, would see those edits vanish when the skill re-runs in enhance mode. The framework would feel hostile and fragile.

**Diffs are unreadable.** Even when the skill's output is technically the same as before, re-emitting the file produces a diff covering the whole file rather than just the intended change. Code review becomes harder. Git history becomes noisy.

**Surgical understanding is impossible.** The skill's intent in any given operation is to add a specific endpoint, register a specific service, or insert a specific make target. When the skill re-emits whole files, the *intent* is buried in noise. Reviewers can't tell what changed deliberately versus what was carried over.

The OpenClaw codebase that informed ASCENT already exhibits the modify-not-overwrite pattern in practice — its phase deliveries add to existing files rather than replace them, and the resulting git history is readable as a record of intentional changes.

## Decision

Every skill operation that touches an existing file uses **surgical edits** — typically `str_replace`-style operations that target a specific anchor in the file and insert, modify, or remove around it. Whole-file overwrites are forbidden except in the initial `scaffold` mode, where no prior content exists.

The contract applies to all four modes:

- **scaffold** — writes files that don't exist yet; no overwrite risk because the target is empty
- **enhance** — adds new content; existing files modified surgically, new files created fresh
- **migrate** — same as enhance but with more aggressive transformation; surgical edits preferred, whole-file replacement requires a project-level ADR
- **bootstrap** — applies slug substitution to a freshly-cloned template; this is the only mode where whole-file overwrites are normal, because the template's placeholder slugs are being replaced en masse

A skill that needs to rewrite a file entirely must capture the rationale in an ADR at the affected project's `docs/architecture/decisions/` level. The framework refuses to perform a whole-file rewrite silently.

## Alternatives considered

**Idempotent re-emission with diff suppression.** The skill always re-emits whole files; tooling detects unchanged content and skips writes. Rejected because user customizations would still be lost the moment a template changes between framework versions. The git-diff problem persists.

**Three-way merge on every operation.** The skill keeps a copy of what it last wrote, compares against current state, and merges intelligently. Rejected as massively over-engineered for the use case. Three-way merge tools are entire systems unto themselves; building one as part of a scaffolding framework is the wrong place for that complexity.

**User opt-in to overwrite via prompt.** Every operation that would touch an existing file prompts the user to confirm overwrite. Rejected because it converts a clean automation into a constant interruption. Surgical edits don't need confirmation because they're scoped enough that the intent is clear.

**Lock files to mark user-customized regions.** Users mark sections of files as "do not touch" with comment markers. Skill respects the markers. Rejected because it shifts maintenance burden onto users and is easy to forget. Surgical edits achieve the same result without user-visible bookkeeping.

## Consequences

**Easier:**

- Multi-mode operation coexists cleanly with user customization
- Git diffs show genuine intent, not re-emission noise
- Code reviews are scoped to the actual change
- The framework feels like a respectful collaborator rather than a steamroller
- Phase-delivery records accumulate as readable git history

**Harder:**

- Skill implementations must use anchor-based editing (str_replace, regex insertion, AST manipulation) instead of template rendering
- Template files must include stable anchors that survive across versions — comment markers, deterministic structure, etc.
- When a template's structure changes incompatibly between framework versions, the migration is more complex than "render the new version on top"

**Neutral:**

- Initial scaffold remains simple (no existing content to preserve)
- Bootstrap mode (slug substitution on a freshly-cloned starter) is a special case where whole-file rewrite is normal and acknowledged

## Cost implications

**Time:** Adds implementation cost to every skill operation in enhance/migrate modes. The cost is paid once per operation type — the patterns are reusable. Saves time over the framework's life by preventing the "skill destroyed my work" support burden that would otherwise occur.

**Complexity:** Slightly higher per-operation complexity in exchange for substantially lower system-level complexity. The framework can be trusted; user customization is a first-class concern; the overall system is less brittle.

**Future flexibility:** Constrains future template authors to design files with stable anchors. This is a constructive constraint — anchor-friendly file design tends to produce clearer, more modular files anyway.

**Money:** No financial cost difference.
