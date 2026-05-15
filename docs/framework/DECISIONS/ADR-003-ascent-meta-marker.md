# ADR-003: `.ascent-meta.json` at project root as mode-detection marker

**Status:** Accepted
**Date:** 2026-05-14 (America/New_York)
**Decider:** lloydbriantech

## Context

The parent skill operates in four modes — scaffold, enhance, migrate, bootstrap. The skill must determine which mode applies to any given invocation without asking the user to specify the mode in every prompt. The decision needs a reliable, fast signal that the skill can read at the start of every operation.

The signal must be:

- Present in every ASCENT project
- Absent in non-ASCENT projects (so the skill can offer to scaffold or migrate)
- Cheap to read (a single file open, no parsing of large structures)
- Tamper-resistant to common refactoring (renaming directories, restructuring code)
- Version-aware (the marker records which framework version scaffolded the project, enabling version-specific behavior)
- Discoverable to humans (a human inspecting the repo can see "yes, this is an ASCENT project" without running a tool)

The signal also needs to carry enough information that the skill's enhance mode can make informed decisions — what options were chosen at scaffold, what phase the project is in, what skills have been run, what's currently being worked on.

## Decision

Every ASCENT project carries a `.ascent-meta.json` file at the project root. The file is:

- **Flat** at the project root (not hidden in a `.ascent/` directory) for discoverability
- **JSON** (not YAML or TOML) for the simplest possible parsing and the broadest tool support
- **Versioned** in its schema, so older projects can be migrated when the schema evolves
- **Git-tracked** (committed to the repo, not gitignored) so the project's framework lineage is part of its history
- **Marked `linguist-generated`** in `.gitattributes` so it doesn't pollute GitHub's language statistics
- **Source of truth for mode detection** — the skill checks for its presence first thing on invocation

The schema for v1 of the meta file:

```json
{
  "framework": "lloydbriantech-ascent",
  "framework_version": "0.3.0",
  "schema_version": "1",
  "project_slug": "lawn-care-app",
  "project_title": "Lawn Care App",
  "brand": "lloydbriantech",
  "gh_owner": "lloydbrian",
  "scaffolded_at": "2026-05-14T22:30:00-04:00",
  "options": {
    "runtime": "node22",
    "db": "sqlite-wal",
    "deploy_target": ["podman-local", "ecs-fargate"],
    "use_agent": true,
    "ai_provider": "anthropic",
    "frontend": "react-vite"
  },
  "skills_run": [
    {
      "skill": "lloydbriantech-ascent",
      "version": "0.3.0",
      "mode": "scaffold",
      "role": "architect",
      "at": "2026-05-14T22:30:00-04:00"
    }
  ],
  "phase": "0-foundation",
  "current_focus": "Setting up local dev environment"
}
```

Mode detection logic:

| `.ascent-meta.json` state | Mode |
|---|---|
| Not present | `scaffold` (or `migrate` if user asks) |
| Present, `project_slug` is `ascent-starter` | `bootstrap` (user cloned the starter, hasn't personalized yet) |
| Present, `project_slug` is anything else | `enhance` |
| Present, user passes `--migrate` flag | `migrate` |

## Alternatives considered

**Hidden `.ascent/` directory containing multiple files.** Rejected because it splits metadata across multiple files (more I/O), adds discovery friction (humans don't notice hidden directories as readily as flat files at the root), and provides no benefit since the metadata is small enough to fit in a single file comfortably.

**`pyproject.toml`-style — append a `[tool.ascent]` section to an existing file like `package.json` or a generic config file.** Rejected because it couples ASCENT to a specific stack's config file. A non-Node project wouldn't have `package.json`; a Python-stack ASCENT project would have `pyproject.toml`. Multiple file conventions per stack would make the marker inconsistent and the detection logic stack-specific.

**A magic comment in the README.** Rejected because READMEs are user-modifiable in ways that would unintentionally break detection. Easy to lose, easy to commit-out, no schema for richer metadata.

**Environment variable or git config.** Rejected because these aren't repo-portable. A user cloning the repo to a new machine wouldn't carry the marker. The marker must travel with the repo.

**No marker file — infer ASCENT-ness from structure.** Rejected because structure-based detection produces false positives (non-ASCENT projects with similar layouts) and false negatives (ASCENT projects that have evolved away from the default structure). A deliberate marker is precise.

**YAML or TOML instead of JSON.** Rejected because JSON has the lowest parsing overhead and the broadest tool support. The marker is read by Claude (which handles JSON natively), shell scripts (`jq`), CI workflows (every CI tool reads JSON), and humans. JSON wins on portability.

## Consequences

**Easier:**

- Mode detection is one file existence check plus a JSON parse — fast, reliable
- Humans inspecting a repo can immediately tell it's an ASCENT project
- Migration paths between framework versions can use `schema_version` to gate behavior
- `skills_run` log enables "what's been done to this project" introspection
- The marker is git-tracked, so the project's framework lineage is preserved in history

**Harder:**

- One more file at the project root (minor cosmetic overhead)
- Schema evolution requires migration logic in the framework
- Users might be tempted to edit the file manually; the framework should warn against this (it's owned by the skill, not by direct edit)

**Neutral:**

- Adding metadata fields is forward-compatible — readers ignore unknown fields
- Removing or renaming fields is breaking — schema_version bump required

## Cost implications

**Time:** Negligible. One extra file write at scaffold time; one extra file read per skill invocation.

**Complexity:** Slight increase in the skill's startup logic. Net decrease in system complexity because mode detection is now explicit instead of implicit.

**Future flexibility:** The `schema_version` field provides a clean evolution path. The current schema is intentionally simple — fields can be added without breaking older versions.

**Money:** No financial cost.

## Operational note

The framework's own meta-repository does not contain a `.ascent-meta.json` file. The framework repo is the source of the framework, not an instance of it. Scaffolded *projects* have the marker; the framework itself does not need one.
