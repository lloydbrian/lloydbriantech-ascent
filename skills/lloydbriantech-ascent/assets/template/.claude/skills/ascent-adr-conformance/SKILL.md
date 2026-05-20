---
name: ascent-adr-conformance
description: >-
  Validates ADR structural conformance for <<PROJECT_TITLE>>: every ADR
  has the 5 required sections, every ADR is listed in INDEX.md, no
  orphaned ADRs exist, supersession links are bidirectional, and status
  fields are consistent between INDEX.md and ADR files.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
---

# ascent-adr-conformance

Validates the structural conformance of every ADR in the project's decision record. Beyond the §7 check that [ascent-self-audit](../ascent-self-audit/SKILL.md) performs (Step 8: INDEX.md exists, ADRs listed, 5 sections present), this skill checks deeper invariants: supersession bidirectionality, status consistency between INDEX.md and ADR files, and orphaned-ADR detection.

This is a sibling skill to self-audit, not a component. Self-audit provides the structural §7 gate; this skill provides deeper conformance analysis invoked independently when the ADR set needs thorough validation.

## When this skill engages

- After writing a new ADR (especially a supersession)
- Before a phase gate to verify the decision record is clean
- When a developer suspects ADR numbering or status drift
- As a deeper follow-up when self-audit's §7 check reports FAIL

## Inputs

- **`docs/architecture/decisions/INDEX.md`** — the ADR index table (required)
- **`docs/architecture/decisions/ADR-NNN-*.md`** — all ADR files (required)

## Outputs

- **Per-check report** — each of the 5 checks marked PASS or FAIL with specific findings
- **Summary line** — "adr-conformance: N/5 checks passing"

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Five-section completeness

**Condition:** Every `ADR-NNN-*.md` file contains all 5 required sections: `## Context`, `## Decision`, `## Alternatives considered`, `## Consequences`, `## Cost implications`.

**Action on PASS:** Report "Section completeness — PASS. N ADRs, all with 5 sections."

**Action on FAIL:** List each ADR missing sections. Example: "Section completeness — FAIL. ADR-003 is missing `## Cost implications`."

### Step 2 — INDEX.md listing

**Condition:** Every `ADR-NNN-*.md` file in `docs/architecture/decisions/` has a corresponding row in INDEX.md. The row's link resolves to the correct filename.

**Action on PASS:** Report "INDEX listing — PASS. N ADRs, all indexed."

**Action on FAIL:** List each unindexed ADR. Example: "INDEX listing — FAIL. ADR-008-redis-session-store.md exists but has no INDEX.md row."

### Step 3 — Orphaned INDEX entries

**Condition:** Every row in INDEX.md links to an ADR file that exists in `docs/architecture/decisions/`.

**Action on PASS:** Report "Orphaned entries — PASS. All INDEX rows link to existing files."

**Action on FAIL:** List each orphaned entry. Example: "Orphaned entries — FAIL. INDEX.md links to `ADR-009-removed.md` which does not exist."

### Step 4 — Supersession bidirectionality

**Condition:** For every ADR whose Status field contains `Superseded by ADR-NNN`:
1. The referenced `ADR-NNN` file must exist.
2. The referenced `ADR-NNN`'s Context section must open with the canonical supersession phrase: `This ADR supersedes ADR-MMM` (where MMM is the old ADR's number).

This ensures supersession links go both ways — the old ADR points forward, the new ADR points backward. The canonical phrase pattern is established by the `adr-template` reference module and enforced by [ascent-adr-write](../ascent-adr-write/SKILL.md) Step 4.

**Action on PASS:** Report "Supersession links — PASS. N supersessions, all bidirectional."

**Action on FAIL:** Report each broken link. Example: "Supersession links — FAIL. ADR-004 says 'Superseded by ADR-008' but ADR-008's Context does not contain 'This ADR supersedes ADR-004'."

**Fallback:** If no ADRs are superseded, report "Supersession links — PASS (0 supersessions)."

### Step 5 — Status consistency

**Condition:** For every ADR, the status in the ADR file's `**Status:**` field matches the status in its INDEX.md row.

**Action on PASS:** Report "Status consistency — PASS. All N ADRs match their INDEX.md status."

**Action on FAIL:** List each mismatch. Example: "Status consistency — FAIL. ADR-004 file says `Superseded by ADR-008` but INDEX.md row says `Accepted`."

## Examples

### Example 1 — Conforming ADR set

**Skill output:**
```
ascent-adr-conformance: 5/5 checks passing
  Section completeness   PASS (7 ADRs, all with 5 sections)
  INDEX listing          PASS (7 ADRs, all indexed)
  Orphaned entries       PASS (all INDEX rows resolve)
  Supersession links     PASS (0 supersessions)
  Status consistency     PASS (all 7 match)
```

### Example 2 — Missing Cost implications

**Skill output:**
```
ascent-adr-conformance: 4/5 checks passing (1 failure)
  Section completeness   FAIL
    → ADR-003-make-vocabulary.md is missing "## Cost implications"
  INDEX listing          PASS
  Orphaned entries       PASS
  Supersession links     PASS
  Status consistency     PASS
```

## Anti-patterns

### Anti-pattern 1 — One-paragraph ADRs

"We chose X." without Context, Alternatives, Consequences, or Cost implications. **Why it's tempting:** the decision feels obvious in the moment. **What to do instead:** every section is required per the `adr-template` reference module. If there's nothing to write under Alternatives, the decision didn't need an ADR.

### Anti-pattern 2 — Renumbering on supersession

Renaming `ADR-005` when `ADR-042` supersedes it. **Why it's tempting:** clean numbering. **What to do instead:** ADR-005 stays as ADR-005 forever. Its Status changes; its number and filename never do. Renumbering breaks every cross-reference.
