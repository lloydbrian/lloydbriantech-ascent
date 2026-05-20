---
name: ascent-doc-sweep
description: >-
  Validates documentation freshness and consistency for <<PROJECT_TITLE>>.
  Checks persona provenance comments, orphaned references, stale TODO/TBD
  markers (30-day threshold), and doc-graph integrity per §14.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-doc-sweep

Validates the documentation graph for freshness, consistency, and persona compliance. Documentation debt is invisible until someone reads a stale doc and makes a wrong decision. This skill makes doc-debt visible: orphaned references, missing provenance comments, and forgotten TODO markers all surface before they mislead.

For the structural §14 check that [ascent-self-audit](../ascent-self-audit/SKILL.md) includes, see that skill's Step 15. This skill provides deeper documentation analysis beyond what the umbrella check covers.

## When this skill engages

- After adding or reorganizing documentation
- As a periodic health check (recommended: per-phase or monthly)
- When a doc-sweep finding from `ascent-self-audit` needs deeper investigation
- Before a handoff to verify docs are current

## Inputs

- **`docs/` directory tree** — all markdown files in the documentation hierarchy
- **`README.md`** — project root readme (persona entry point validation)
- **File modification timestamps** — for staleness detection (via `stat`)

## Outputs

- **Per-check report** — each check marked PASS or FAIL with specific findings
- **Summary line** — "doc-sweep: N/5 checks passing"

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Persona provenance comments

**Condition:** Every markdown file under `docs/` (excluding INDEX.md files and CHANGELOG entries) has a `<!-- Audience: <persona> -->` comment, where persona is one of Architect, Developer, Operator, Contributor, or Learner.

**Action on PASS:** Report "Persona provenance — PASS. N docs, all with audience tags."

**Action on FAIL:** List each doc missing the provenance comment. Example: "Persona provenance — FAIL. docs/operations/runbook.md has no `<!-- Audience: -->` tag."

**Fallback:** If no docs exist under `docs/`, report "Persona provenance — PASS (0 docs — directory not yet populated)."

### Step 2 — Orphaned doc references

**Condition:** Every internal markdown link in docs under `docs/` resolves to an existing file. Internal links are those with `.md` targets (not external URLs).

**Action on PASS:** Report "Orphaned references — PASS. N links validated."

**Action on FAIL:** List each broken reference. Example: "Orphaned references — FAIL. docs/architecture/overview.md links to `security-model.md` which does not exist."

### Step 3 — Stale TODO/TBD markers

**Condition:** Scan all markdown files under `docs/` for lines containing `TODO`, `TBD`, `FIXME`, or `PLACEHOLDER`. For each match, check the file's modification timestamp. If the file was last modified more than **30 days** ago, the marker is stale.

The 30-day threshold is distinct from §15's 7-day session-state staleness. Documentation placeholders are expected to persist across development sprints; session state is transient. A TODO that's been untouched for a month is likely forgotten.

**Action on PASS:** Report "Stale markers — PASS. N markers found, none older than 30 days." (Or "0 markers found.")

**Action on FAIL:** List each stale marker with file path, line number, and age. Example: "Stale markers — FAIL. docs/operations/deploy.md:14 has 'TODO: add rollback procedure' — file last modified 47 days ago."

### Step 4 — Audience-mapping cross-references

**Condition:** If `README.md` contains a persona table (linking personas to entry points), verify each linked entry point file exists.

**Action on PASS:** Report "Audience mapping — PASS. All persona entry points resolve."

**Action on FAIL:** List each broken persona entry point. Example: "Audience mapping — FAIL. README persona table links to `docs/operations/` but directory does not exist."

**Fallback:** If README has no persona table, report "Audience mapping — SKIP (no persona table in README)."

### Step 5 — Depth validation

**Condition:** No doc under `docs/` is more than 3 directory levels deep from its persona's entry point per the `doc-architecture` reference module.

**Action on PASS:** Report "Depth validation — PASS. Deepest doc is N levels from root."

**Action on FAIL:** List each doc exceeding the 3-click limit. Example: "Depth validation — FAIL. docs/architecture/patterns/auth/jwt/details.md is 4 levels deep."

## Examples

### Example 1 — Clean doc tree

**Skill output:**
```
ascent-doc-sweep: 5/5 checks passing
  Persona provenance     PASS (12 docs, all tagged)
  Orphaned references    PASS (34 links validated)
  Stale markers          PASS (2 TODOs, none older than 30 days)
  Audience mapping       PASS (all persona entry points resolve)
  Depth validation       PASS (deepest: 2 levels)
```

### Example 2 — Doc with stale TODO

**Skill output:**
```
ascent-doc-sweep: 4/5 checks passing (1 failure)
  ...
  Stale markers          FAIL
    → docs/operations/deploy.md:14 — "TODO: add rollback procedure" (47 days stale)
    → docs/architecture/caching.md:8 — "TBD: evaluate Redis vs Memcached" (63 days stale)
  ...
```

## Anti-patterns

### Anti-pattern 1 — Docs without named audiences

Creating docs that "serve everyone" and therefore serve no one well. **Why it's tempting:** the topic feels cross-cutting. **What to do instead:** per §14, every doc names one primary audience. The provenance comment makes this enforceable.

### Anti-pattern 2 — TODO markers as permanent fixtures

Using TODO as a section heading style rather than a temporary placeholder. **Why it's tempting:** "it reminds me to come back." **What to do instead:** track work in the phase plan, not in doc markers. A TODO older than 30 days is a forgotten promise, not a reminder.
