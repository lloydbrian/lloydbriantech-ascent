---
name: ascent-skills-doctor
description: >-
  Validates the project-embedded skill collection integrity for
  <<PROJECT_TITLE>>. Checks SKILL.md frontmatter, INTENT-MAP.md sync,
  cross-skill reference integrity, and allowed-tools honesty across
  all ascent-* skills.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
---

# ascent-skills-doctor

Validates the integrity of the project's embedded skill collection. Skills are the project's self-maintenance layer — if the collection is inconsistent (broken cross-references, stale INTENT-MAP, invalid frontmatter), the project's ability to self-audit and self-correct degrades silently. This skill catches collection-level drift.

This is a sibling skill to [ascent-self-audit](../ascent-self-audit/SKILL.md), not a component. Self-audit validates the 15 framework principles; skills-doctor validates the skill collection itself. Self-audit doesn't check skills — skills-doctor fills that gap.

## When this skill engages

- After adding or modifying a skill SKILL.md
- After updating INTENT-MAP.md
- As a periodic health check on the skill collection
- When a skill invocation fails and the cause may be structural

## Inputs

- **`.claude/skills/ascent-*/SKILL.md`** — all skill definition files (required)
- **`.claude/skills/INTENT-MAP.md`** — the intent routing table (required)

## Outputs

- **Per-check report** — each of the 5 checks marked PASS or FAIL with specific findings
- **Summary line** — "skills-doctor: N/5 checks passing"

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Frontmatter validation

**Condition:** Every `SKILL.md` under `.claude/skills/ascent-*/` has YAML frontmatter with the 4 required fields: `name`, `description`, `version`, `allowed-tools`.

Validation rules:
- `name` must match the directory name (e.g., `ascent-env-audit/SKILL.md` must have `name: ascent-env-audit`)
- `description` must be non-empty
- `version` must be present (typically `<<PROJECT_VERSION>>`)
- `allowed-tools` must be a non-empty list

**Action on PASS:** Report "Frontmatter — PASS. N skills, all with valid frontmatter."

**Action on FAIL:** List each invalid skill. Example: "Frontmatter — FAIL. ascent-foo/SKILL.md is missing `version` field."

### Step 2 — INTENT-MAP sync

**Condition:** Every skill directory under `.claude/skills/ascent-*/` has a corresponding entry in INTENT-MAP.md. Every skill referenced in INTENT-MAP.md has a corresponding directory with a SKILL.md file.

**Action on PASS:** Report "INTENT-MAP sync — PASS. N skills in directory, N in INTENT-MAP."

**Action on FAIL:** List each mismatch. Examples:
- "INTENT-MAP sync — FAIL. ascent-health/ exists but is not listed in INTENT-MAP.md."
- "INTENT-MAP sync — FAIL. INTENT-MAP.md lists ascent-foo but no ascent-foo/ directory exists."

**Note:** Skills listed under the "Phase 3 additions" section of INTENT-MAP (not yet scaffolded) are exempt from the directory-existence check. Only skills in the main intent-routing table are verified.

### Step 3 — Cross-skill reference integrity

**Condition:** Every markdown link in a SKILL.md that references another skill (pattern: `../ascent-*/SKILL.md`) resolves to an existing file.

**Action on PASS:** Report "Cross-references — PASS. N inter-skill links, all resolve."

**Action on FAIL:** List each broken reference. Example: "Cross-references — FAIL. ascent-self-audit/SKILL.md links to `../ascent-nonexistent/SKILL.md` which does not exist."

### Step 4 — Allowed-tools honesty

**Condition:** Each skill's `allowed-tools` frontmatter declares only the tools its operational logic actually uses. Checks:
- Skills with `Write` or `Edit` in allowed-tools must have operational steps that describe file creation or modification.
- Skills without `Write`/`Edit` must not describe file-writing operations in their operational logic.
- `Bash` should only appear when the skill needs shell operations (timestamp computation, file traversal, CLI tool invocation).

**Action on PASS:** Report "Allowed-tools — PASS. N skills, all declarations match operational logic."

**Action on FAIL:** List each mismatch. Example: "Allowed-tools — FAIL. ascent-foo declares `Write` but no operational step describes file creation."

**Note:** This check is heuristic — it looks for Write/Edit/Bash keywords in operational logic sections. False positives are possible for skills with nuanced tool usage. The developer should verify flagged skills.

### Step 5 — Skill directory completeness

**Condition:** Every directory under `.claude/skills/ascent-*/` contains a `SKILL.md` file. Empty directories or directories with only non-SKILL.md files are incomplete.

**Action on PASS:** Report "Directory completeness — PASS. N skill directories, all contain SKILL.md."

**Action on FAIL:** List each incomplete directory. Example: "Directory completeness — FAIL. ascent-foo/ exists but contains no SKILL.md."

## Examples

### Example 1 — Healthy skill collection

**Skill output:**
```
ascent-skills-doctor: 5/5 checks passing
  Frontmatter            PASS (15 skills, all valid)
  INTENT-MAP sync        PASS (9 in routing table, 9 in directory)
  Cross-references       PASS (12 inter-skill links, all resolve)
  Allowed-tools          PASS (15 skills, all honest)
  Directory completeness PASS (15 directories, all have SKILL.md)
```

### Example 2 — INTENT-MAP mismatch

**Skill output:**
```
ascent-skills-doctor: 4/5 checks passing (1 failure)
  Frontmatter            PASS
  INTENT-MAP sync        FAIL
    → ascent-health/ exists but is not listed in INTENT-MAP.md
  Cross-references       PASS
  Allowed-tools          PASS
  Directory completeness PASS
```

## Anti-patterns

### Anti-pattern 1 — Adding a skill without updating INTENT-MAP

Creating a new `ascent-*/SKILL.md` directory but forgetting to add the intent-routing entry. **Why it's tempting:** the skill "works" when invoked directly. **What to do instead:** INTENT-MAP.md is the routing table — if the skill isn't listed, Claude doesn't know when to invoke it. Always update INTENT-MAP.md in the same PR that adds the skill.
