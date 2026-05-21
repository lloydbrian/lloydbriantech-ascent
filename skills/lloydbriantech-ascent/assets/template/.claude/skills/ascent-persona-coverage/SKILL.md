---
name: ascent-persona-coverage
description: >-
  Validates persona coverage for <<PROJECT_TITLE>>: every canonical
  persona has a README entry point, every entry-point file exists,
  and no doc exceeds the 3-click depth limit per §14.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
---

# ascent-persona-coverage

Validates that every canonical persona (Architect, Developer, Operator, Contributor, Learner) has a documented entry point in README.md, that each entry-point file exists, and that no doc exceeds the 3-click depth limit from its persona's root per Principle §14. An "orphaned persona" is one named in the persona mapping but missing from README's entry-point table, or one with a README row whose linked file doesn't exist.

This skill is conditional — the Phase 4 scaffolder will gate its inclusion based on project type. Until then, it ships in all scaffolded projects and exits gracefully when its subsystem is absent.

For the structural §14 check that [ascent-self-audit](../ascent-self-audit/SKILL.md) includes, see that skill's Step 15. For deeper documentation analysis (provenance, orphaned references, stale markers), see [ascent-doc-sweep](../ascent-doc-sweep/SKILL.md). This skill focuses specifically on persona coverage — the persona-to-entry-point mapping and path-depth validation.

## When this skill engages

- After restructuring documentation or adding new docs
- When a developer asks "are all personas covered?" or "can every reader find their entry point?"
- As a periodic check (recommended: per-doc-restructure)
- After adding a new persona to the project

## Inputs

- **`README.md`** — persona table with entry-point links
- **`docs/` directory tree** — entry-point files and doc-graph depth
- **`audience-mapping` reference** — canonical persona definitions (5 personas)

## Outputs

- **Per-check report** — each check marked PASS, CONCERN, or SKIP
- **Summary line** — "persona-coverage: N/4 checks passing"

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Read README persona table

**Condition:** `README.md` contains a persona table (a markdown table with "Persona" column and entry-point links).

**Action on PASS:** Extract persona names and their linked entry points. Report: "Persona table found: [N] personas mapped."

**Action on FAIL:** Report "persona-coverage: no persona table found in README.md. §14 requires persona-segmented documentation." This is a concern, not a no-op — every ASCENT project should have a persona table.

### Step 2 — Canonical persona completeness

**Condition:** The 5 canonical personas (Architect, Developer, Operator, Contributor, Learner) are all represented in the README persona table.

**Action on PASS:** Report "Persona completeness — PASS. 5/5 canonical personas mapped."

**Action on CONCERN:** List each missing persona. "Persona completeness — CONCERN. 'Operator' is not in the README persona table."

### Step 3 — Entry-point file existence

**Condition:** For each persona row in the README table, the linked entry-point file or directory exists.

**Action on PASS:** Report "Entry points — PASS. All [N] entry-point files exist."

**Action on CONCERN:** List each orphaned entry point. "Entry points — CONCERN. README maps Operator to `docs/operations/` but that directory does not exist."

### Step 4 — Depth validation

**Condition:** No doc under `docs/` is more than 3 directory levels deep from its persona's entry point per the `doc-architecture` reference module.

**Action on PASS:** Report "Depth validation — PASS. Deepest doc is [N] levels from entry point."

**Action on CONCERN:** List each violation. "Depth validation — CONCERN. docs/architecture/patterns/auth/jwt/details.md is 4 levels deep (limit: 3)."

**Fallback:** If `docs/` is empty or absent, report "Depth validation — SKIP (no docs to validate)."

## Examples

### Example 1 — Full coverage

```
persona-coverage: 4/4 checks passing
  Persona table          PASS (5 personas mapped)
  Persona completeness   PASS (5/5 canonical)
  Entry points           PASS (5/5 files exist)
  Depth validation       PASS (deepest: 2 levels)
```

### Example 2 — Orphaned persona

```
persona-coverage: 3/4 checks passing (1 concern)
  Persona table          PASS (4 personas mapped)
  Persona completeness   CONCERN — "Operator" not in README persona table
  Entry points           PASS (4/4 mapped files exist)
  Depth validation       PASS
```

## Anti-patterns

### Anti-pattern 1 — Adding a persona without updating README

Defining a new persona in `audience-mapping` without adding a README table row. **Why it's tempting:** "I'll add the row when the docs are ready." **What to do instead:** add the README row immediately, even if the entry-point doc is a stub. The row is the contract; the doc can grow.
