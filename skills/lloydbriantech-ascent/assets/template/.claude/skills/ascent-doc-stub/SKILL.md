---
name: ascent-doc-stub
description: >-
  Generates persona-targeted documentation skeletons for <<PROJECT_TITLE>>.
  Each generated doc has a named audience, a clear navigation path from
  the persona's entry point, and section headings that match the audience's
  needs — not blank files or generic templates.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
---

# ascent-doc-stub

Generates documentation skeletons that are persona-targeted from creation. Every doc this skill produces has a named primary audience (Architect, Developer, Operator, Contributor, or Learner), section headings appropriate to that audience, and a placement that respects the 3-click depth limit from the persona's entry point. Per the `audience-mapping` reference module, each doc serves one primary audience; cross-references suit the originating audience's needs.

## When this skill engages

- When a developer needs to create a new doc and wants it properly structured from the start
- When explicitly asked to "create docs for X" or "stub a doc for Y"
- When a feature intake identifies documentation deliverables
- When a new persona-targeted doc is needed and placement isn't obvious
- NOT for ADRs (use [ascent-adr-write](../ascent-adr-write/SKILL.md))
- NOT for CHANGELOG entries (those follow the project's CHANGELOG format)
- NOT for filling existing documents or replacing markers — this skill creates new files only

## Inputs

- **Topic** — what the doc documents (required)
- **Primary audience** — one of: Architect, Developer, Operator, Contributor, Learner (required; the skill asks if not provided)
- **Placement path** (optional) — where in `docs/` the file should live. If not provided, the skill infers from the persona's entry point.

## Outputs

- **A new markdown file** at the specified or inferred path with:
  - A `<!-- Audience: <persona> -->` provenance comment on line 1
  - A title derived from the topic
  - Section headings tailored to the primary persona (not generic "Overview" / "Details")
  - Placeholder prose under each heading indicating what content belongs there

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Identify primary persona

**Condition:** The developer has specified one of the five personas (Architect, Developer, Operator, Contributor, Learner).

**Action on PASS:** Lock the persona for all subsequent steps. Report: "Primary audience: [persona]."

**Action on FAIL (no persona specified):** Ask: "Who reads this doc first, and what question are they answering?" Map the answer to one of the five personas. If the developer says "it's for everyone," push back: "Every doc serves one primary audience. Which persona reads this doc on Day 1? That's your primary."

**Action on FAIL (invalid persona):** Report the five valid options and ask the developer to choose.

### Step 2 — Determine placement path

**Condition:** The developer has provided a path, or the persona's entry-point mapping provides a default.

**Action when path provided:** Validate the path is under `docs/` (the only valid write target for this skill). Normalize to `.md` extension if missing.

**Action when path not provided:** Infer from the persona's canonical location per the `doc-architecture` reference module:
- Architect → `docs/architecture/`
- Developer → `docs/development/` (or `docs/` root for cross-cutting developer guides)
- Operator → `docs/operations/`
- Contributor → project root (adjacent to `CONTRIBUTING.md`)
- Learner → `docs/` root or `docs/guides/`

Report: "Proposed placement: [path]. Confirm or specify a different location."

### Step 3 — Validate depth (3-click rule)

**Condition:** The placement path is determined.

**Action:** Count the navigation depth from the persona's entry point to the proposed path. Per the `doc-architecture` reference module, no doc may be more than 3 clicks from its persona's root.

Depth calculation: count directory levels between the persona's entry point and the target file. Each directory level is one click.

**Action on PASS (depth ≤ 3):** Proceed.

**Action on FAIL (depth > 3):** Report: "This placement is [N] clicks from the [persona]'s entry point (limit: 3). Move it closer or add a shortcut link from the entry point." Propose an alternative path at depth ≤ 3.

### Step 4 — Check target file doesn't exist

**Condition:** The target file path is finalized.

**Action on PASS (file does not exist):** Proceed to skeleton generation.

**Action on FAIL (file exists):** Report: "[path] already exists. Options: (A) Abort — the doc is already started. (B) Create at [path-v2] as a companion doc. Choose A or B." The skill never overwrites an existing file.

### Step 5 — Select section headings for persona

**Action:** Choose section headings from the persona-to-heading mapping:

**Architect:**
- Constraints — what limits the design space
- Alternatives — what other approaches were considered
- Trade-offs — what this approach gives up
- Dependencies — what this decision connects to
- Open questions — what remains unresolved

**Developer:**
- Implementation — how to build this
- Integration — how this connects to existing code
- Testing — how to verify this works
- Edge cases — what can go wrong
- Related code — where to look in the codebase

**Operator:**
- Commands — make targets and CLI operations
- Failure modes — what breaks and how to detect it
- Escalation — when and how to escalate
- Monitoring — what to watch
- Recovery — how to restore normal operation

**Contributor:**
- Conventions — formatting, naming, structure rules
- Quality bar — what "done" looks like for a contribution
- PR mechanics — branch naming, commit format, review process
- Testing expectations — what tests a contribution needs
- Scope boundaries — what's in scope vs. out of scope

**Learner:**
- Why — why this exists and what problem it solves
- What — what it does, in concrete terms
- How — how to use it (step by step)
- Cost — what adopting this costs (time, complexity, dependencies)
- Next steps — where to go after reading this doc

The mapping selects all headings for the persona. The developer can remove headings that don't apply to the specific topic during review (Step 7).

### Step 6 — Generate doc skeleton

**Action:** Build the skeleton:

```markdown
<!-- Audience: <persona> -->
# <Title derived from topic>

<One-sentence description of what this doc covers and who it's for.>

## <Heading 1>

<Placeholder: describe what content belongs here.>

## <Heading 2>

<Placeholder: describe what content belongs here.>

[... remaining headings ...]
```

Each placeholder is a single sentence describing what the section should contain — specific to the topic, not generic. "Describe the make targets for database operations" is good; "Add content here" is not.

### Step 7 — Present skeleton for review

**Action:** Present the complete skeleton to the developer. Report: "Review this skeleton. Confirm to write, or specify headings to add/remove/rename."

**Gate:** Developer must explicitly approve before writing. This is the same show-plan-then-execute pattern used by [ascent-adr-write](../ascent-adr-write/SKILL.md).

### Step 8 — Write file

**Condition:** Developer has approved the skeleton.

**Action:** Write the file to the approved path. Report: "Doc created at [path] for [persona] audience."

**Valid paths:** This skill writes only to the `docs/` subtree (or project root for Contributor docs adjacent to `CONTRIBUTING.md`). Any other path is a step failure.

## Examples

### Example 1 — Operator runbook

**Input:** "Create a doc for database backup procedures" + audience: Operator

**Skill output:**
```markdown
<!-- Audience: Operator -->
# Database backup procedures

Backup and restore operations for <<PROJECT_TITLE>>'s SQLite-WAL database.

## Commands

Describe the make targets for backup operations: `make data-backup`, `make data-restore`, expected arguments and options.

## Failure modes

Describe what happens when a backup fails mid-write, when disk space is exhausted, and when WAL checkpointing conflicts with a running backup.

## Escalation

Describe when a failed backup requires developer intervention vs. operator retry, and the notification channel for backup failures.

## Monitoring

Describe how to verify backups completed successfully: file size checks, integrity validation, backup-age alerting thresholds.

## Recovery

Describe the restore procedure step by step: stop the service, replace the database file, verify integrity, restart the service.
```

**Placement:** `docs/operations/database-backup.md` (depth 2 from Operator root)

### Example 2 — Developer integration guide

**Input:** "Create a doc for integrating with the items API" + audience: Developer

**Skill output:**
```markdown
<!-- Audience: Developer -->
# Items API integration guide

How to integrate with the /api/items endpoint in <<PROJECT_TITLE>>.

## Implementation

Describe the request/response format for GET and POST /api/items, including required headers and content types.

## Integration

Describe how the items API connects to the backend layering: routes/items.js → controllers/items.js → services/items.js → storage/items.js.

## Testing

Describe how to test items API integration: curl examples for manual testing, Vitest patterns for automated testing, expected response shapes.

## Edge cases

Describe behavior on empty database, malformed request bodies, concurrent writes, and items with special characters in names.

## Related code

List the files involved: backend/routes/items.js, backend/controllers/items.js, backend/services/items.js, backend/storage/items.js.
```

**Placement:** `docs/development/items-api-integration.md` (depth 2 from Developer root)

### Example 3 — Architect constraints doc

**Input:** "Create a doc about our API versioning strategy" + audience: Architect

**Placement:** `docs/architecture/api-versioning-strategy.md` (depth 2 from Architect root)

**Skeleton headings:** Constraints, Alternatives, Trade-offs, Dependencies, Open questions — each with topic-specific placeholder prose about API versioning concerns.

## Anti-patterns

### Anti-pattern 1 — Universal audience

Creating a doc "for everyone" that serves no persona well. **Why it's tempting:** the topic feels cross-cutting. **What to do instead:** pick the persona who reads it first and on Day 1. Write for them. Other personas reach it via cross-reference.

### Anti-pattern 2 — Generic section headings

Using "Overview," "Details," "Miscellaneous" for every doc regardless of audience. **Why it's tempting:** generic headings are always "right." **What to do instead:** the persona-to-heading mapping in Step 5 produces audience-specific headings. An Operator reading "Failure modes" gets more value than an Operator reading "Details."

### Anti-pattern 3 — Stub without intent

Creating a doc skeleton and never filling it in. The skeleton accumulates as graph noise. **Why it's tempting:** creating the structure feels productive. **What to do instead:** only stub a doc when there's a concrete plan to fill it. Per Principle §14, "a doc exists only if someone reads it." A skeleton nobody fills is documentation theater.
