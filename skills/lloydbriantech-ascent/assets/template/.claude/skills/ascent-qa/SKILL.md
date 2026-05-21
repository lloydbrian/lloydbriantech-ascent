---
name: ascent-qa
description: >-
  Surface-level quality gate for <<PROJECT_TITLE>>. Runs lightweight
  checks across structural integrity, ADR discipline, dependency health,
  documentation freshness, and skill collection integrity. Conditionally
  recommends deeper sub-skills when concerns are flagged.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-qa

Surface-level quality gate that answers "is the project healthy across all dimensions?" Runs lightweight checks across five quality areas, then conditionally recommends deeper analysis via specific sub-skills when a surface check flags a concern. This is a hybrid pattern — qa executes its own surface checks (file existence, structural shape, spot-checks) but does not invoke other skills at runtime. Deeper analysis is opt-in via the recommended sub-skills.

This is a sibling skill to [ascent-self-audit](../ascent-self-audit/SKILL.md) and the Cluster 4 health-check skills. self-audit validates the 15 framework principles; qa provides a broader quality sweep across structural, ADR, dependency, documentation, and skill-collection dimensions. Neither invokes the other — they share project sources as data.

**Scope boundary:** qa covers structural, ADR, dependency, documentation, and skill-collection health. Data-tier health (stack-specific to SQLite-WAL) and delivery progress (phase-context synthesis) are surfaced via their own skills — see [ascent-data-health](../ascent-data-health/SKILL.md) and [ascent-delivery-status](../ascent-delivery-status/SKILL.md). These are intentionally outside qa's scope because data-health is stack-specific (not every project uses SQLite) and delivery-status is a status synthesis, not a quality check.

## When this skill engages

- Before a commit or PR to verify overall project quality
- As a periodic health sweep (recommended: weekly or per-phase)
- When a developer asks "is this project healthy?" or "what should I fix?"
- As a pre-release sanity check before running [ascent-release-readiness](../ascent-release-readiness/SKILL.md)

## Inputs

- **Project root directory** — reads files across the entire project structure
- No user input required — the gate is autonomous

## Outputs

- **Per-area report** — each of the 5 areas marked PASS or CONCERN with specific findings
- **Conditional recommendations** — sub-skill invocations recommended only when concerns are flagged
- **Summary line** — "qa: N/5 areas passing"

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Structural integrity

**Surface checks:**
- `backend/Dockerfile` exists
- `Makefile` exists at project root with `make/` directory
- `docker-compose.yml` exists
- `.ascent-meta.json` exists with `phase` field

**Action on PASS (all present):** Report "Structural integrity — PASS."

**Action on CONCERN (any missing):** Report each missing artifact. Recommend: "Run `/ascent-self-audit` for full 15-invariant structural validation."

### Step 2 — ADR discipline

**Surface checks:**
- `docs/architecture/decisions/INDEX.md` exists
- At least 1 ADR file exists in the directory
- Spot-check: pick the first ADR file and verify it contains all 5 required sections (`## Context`, `## Decision`, `## Alternatives considered`, `## Consequences`, `## Cost implications`)

**Action on PASS:** Report "ADR discipline — PASS. N ADRs indexed."

**Action on CONCERN:** Report the specific finding. Recommend: "Run `/ascent-adr-conformance` for full ADR structural analysis (section completeness, supersession bidirectionality, status consistency)."

### Step 3 — Dependency discipline

**Surface checks:**
- `backend/package.json` exists
- `engines` field is present
- Spot-check: scan `dependencies` for any unpinned version (contains `^`, `~`, `>=`, `*`, or `latest`)

**Action on PASS:** Report "Dependency discipline — PASS. All dependencies pinned."

**Action on CONCERN:** Report the finding. Recommend: "Run `/ascent-dependency-health` for full dependency analysis (pinned versions, traceability, unused deps)."

### Step 4 — Documentation health

**Surface checks:**
- `docs/` directory exists with at least 1 markdown file
- Spot-check: pick the first doc file under `docs/` and verify it has a `<!-- Audience: -->` provenance comment
- Scan all docs for `TODO` or `TBD` markers (count only, no age check — that's doc-sweep's depth)

**Action on PASS:** Report "Documentation health — PASS. N docs, provenance tags present."

**Action on CONCERN:** Report the finding. Recommend: "Run `/ascent-doc-sweep` for full documentation analysis (provenance coverage, orphaned references, stale markers, depth validation)."

### Step 5 — Skill collection integrity

**Surface checks:**
- `.claude/skills/INTENT-MAP.md` exists
- At least 1 skill directory exists under `.claude/skills/ascent-*/`
- Spot-check: pick the first skill SKILL.md and verify it has frontmatter with `name`, `description`, `version`, `allowed-tools`

**Action on PASS:** Report "Skill collection — PASS. N skills, INTENT-MAP present."

**Action on CONCERN:** Report the finding. Recommend: "Run `/ascent-skills-doctor` for full skill collection analysis (frontmatter validation, INTENT-MAP sync, cross-references, allowed-tools honesty)."

### Step 6 — Aggregate and report

**Action:** Collect results from Steps 1-5. Report summary:

```
ascent-qa: 5/5 areas passing
```

Or with concerns:

```
ascent-qa: 4/5 areas passing (1 concern)
  Structural integrity   PASS
  ADR discipline         CONCERN — ADR-003 missing Cost implications section
    → Run /ascent-adr-conformance for full ADR analysis
  Dependency discipline  PASS
  Documentation health   PASS
  Skill collection       PASS
```

Recommendations appear only for areas with concerns. Clean areas show PASS with no additional output.

## Examples

### Example 1 — Clean project

**Skill output:**
```
ascent-qa: 5/5 areas passing
  Structural integrity   PASS
  ADR discipline         PASS (7 ADRs indexed)
  Dependency discipline  PASS (all pinned)
  Documentation health   PASS (12 docs, provenance present)
  Skill collection       PASS (15 skills, INTENT-MAP present)
```

### Example 2 — Project with ADR concern

**Skill output:**
```
ascent-qa: 4/5 areas passing (1 concern)
  Structural integrity   PASS
  ADR discipline         CONCERN — spot-check: ADR-003 missing "## Cost implications"
    → Run /ascent-adr-conformance for full ADR analysis
  Dependency discipline  PASS
  Documentation health   PASS
  Skill collection       PASS
```

## Anti-patterns

### Anti-pattern 1 — Treating qa as an exhaustive audit

qa is a surface-level gate, not a deep audit. PASS means "no surface-level concerns found," not "the project is perfect." **What to do instead:** use qa as a triage tool. When everything passes, the project is likely healthy. When something flags, run the recommended sub-skill for deeper analysis.

### Anti-pattern 2 — Ignoring conditional recommendations

Seeing a CONCERN but not running the recommended sub-skill. **Why it's tempting:** "it's probably fine." **What to do instead:** each recommendation is triggered by a specific finding. The sub-skill provides the detail needed to understand and fix the issue.
