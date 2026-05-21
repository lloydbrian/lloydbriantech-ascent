---
name: ascent-health
description: >-
  Composite health stance summarizer for <<PROJECT_TITLE>>. Synthesizes
  signals across four sub-domains (data, dependency, documentation, ADR)
  into a single stance rating: strong, moderate, weak, or partial. Does
  not invoke sub-skills at runtime — reads the same project sources they
  read, at a higher abstraction level.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-health

Composite health stance summarizer across four sub-domains: data integrity, dependency discipline, documentation freshness, and ADR conformance. This skill answers "what is the project's overall health stance?" by reading the same project sources that the four Cluster 4 enumerator skills read, then producing a stance-level summary rather than detailed findings.

This is the enumerate/summarize pattern at 1:4 fan-in — the same shape established by [ascent-adr-conformance](../ascent-adr-conformance/SKILL.md) / [ascent-self-audit](../ascent-self-audit/SKILL.md) (Cluster 4) and [ascent-security-audit](../ascent-security-audit/SKILL.md) / [ascent-sec-posture](../ascent-sec-posture/SKILL.md) (Cluster 7), now spanning four sub-domains. The four enumerators are: [ascent-data-health](../ascent-data-health/SKILL.md) (data integrity), [ascent-dependency-health](../ascent-dependency-health/SKILL.md) (dependency discipline), [ascent-doc-sweep](../ascent-doc-sweep/SKILL.md) (documentation freshness), and [ascent-adr-conformance](../ascent-adr-conformance/SKILL.md) (ADR structure). None invoke each other at runtime — they share project sources as data.

**Abstraction distinction:** ascent-health produces stance-level signals (strong / moderate / weak per sub-domain), not detailed findings. The four enumerator skills remain the canonical source for detailed enumeration. A future contributor should NOT copy enumerator logic into this skill — the two layers are different abstractions over the same sources. ascent-health asks "how does this sub-domain look overall?"; enumerators ask "what specifically is wrong?"

**Relationship to [ascent-qa](../ascent-qa/SKILL.md):** qa is a surface-level quality gate (Cluster 6) that runs lightweight checks and conditionally recommends sub-skills. health is a stance summarizer that synthesizes sub-domain signals into a composite rating. qa gates; health summarizes. They do not invoke each other.

## When this skill engages

- As a periodic health check (recommended: weekly or per-phase)
- When a developer asks "how healthy is this project?" or "what's the overall state?"
- Before a phase gate to assess project-wide health
- When onboarding to quickly understand project health across all dimensions
- After a burst of work to verify nothing degraded

## Inputs

- **`backend/storage/db.js`** — data-tier configuration (WAL, FK, migrations)
- **`backend/storage/migrations/*.sql`** — migration file ordering
- **`backend/package.json`, `frontend/package.json`** — dependency declarations
- **`docs/` directory tree** — documentation provenance and freshness
- **`docs/architecture/decisions/INDEX.md` + `ADR-*.md`** — ADR structure
- **`git log`** — recent activity context

## Outputs

- **Per-sub-domain stance** — each of the 4 sub-domains rated strong, moderate, weak, or not-assessed
- **Composite health stance** — overall project health rating
- **Summary line** — "health: [strong | moderate | weak | partial] — N/4 sub-domains assessed"

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Data integrity stance

**Action:** Read `backend/storage/db.js` and `backend/storage/migrations/`. Assess three stance signals:

- WAL mode pragma present → +1
- Foreign keys pragma present → +1
- Migration files follow NNN_ ordering (all zero-padded) → +1

**Stance classification:**
- **Strong (3/3):** all three signals present
- **Moderate (2/3):** one signal missing
- **Weak (0-1/3):** multiple signals missing
- **Not-assessed:** `backend/storage/db.js` does not exist (no data tier)

### Step 2 — Dependency discipline stance

**Action:** Read `backend/package.json` (and `frontend/package.json` if present). Assess three stance signals:

- All dependencies use exact pinned versions (no `^`, `~`, `>=`) → +1
- `engines` field present with Node version constraint → +1
- `ascent_framework_version` traceability field present → +1

**Stance classification:**
- **Strong (3/3):** all three signals present
- **Moderate (2/3):** one signal missing
- **Weak (0-1/3):** multiple signals missing
- **Not-assessed:** no `package.json` found

### Step 3 — Documentation freshness stance

**Action:** Read `docs/` directory tree. Assess three stance signals:

- At least one doc under `docs/` has a `<!-- Audience: -->` provenance comment → +1
- No stale `TODO`/`TBD` markers (files with markers modified within 30 days) → +1
- At least one doc exists under `docs/` → +1

**Stance classification:**
- **Strong (3/3):** all three signals present
- **Moderate (2/3):** one signal missing (e.g., stale TODOs but provenance present)
- **Weak (0-1/3):** multiple signals missing
- **Not-assessed:** `docs/` directory does not exist

### Step 4 — ADR conformance stance

**Action:** Read `docs/architecture/decisions/INDEX.md` and ADR files. Assess three stance signals:

- INDEX.md exists with at least one ADR listed → +1
- Spot-check: first ADR has all 5 required sections → +1
- No orphaned ADRs (every ADR file is listed in INDEX.md) → +1

**Stance classification:**
- **Strong (3/3):** all three signals present
- **Moderate (2/3):** one signal missing
- **Weak (0-1/3):** multiple signals missing
- **Not-assessed:** `docs/architecture/decisions/INDEX.md` does not exist (no ADR directory)

### Step 5 — Empty sub-domain handling

**Action:** For each sub-domain classified as not-assessed, record it distinctly from strong. A sub-domain is not-assessed when its source files don't exist — the project hasn't reached the maturity where that sub-domain is populated.

Not-assessed sub-domains are honest about partial coverage. A project with 3 strong sub-domains + 1 not-assessed has partial coverage, not falsely-strong coverage.

### Step 6 — Produce composite health stance

**Action:** Aggregate sub-domain stances into a composite:

- **Strong:** all assessed sub-domains are strong AND at least 3 sub-domains are assessed
- **Partial:** at least 1 sub-domain is not-assessed AND all assessed sub-domains are strong (healthy where covered, incomplete coverage)
- **Moderate:** at least one assessed sub-domain is moderate AND no sub-domain is weak (drift detected)
- **Weak:** any sub-domain is weak

Report:
```
health: [strong | moderate | weak | partial] — N/4 sub-domains assessed
  Data integrity:        [strong | moderate | weak | not-assessed] (N/3 signals)
  Dependency discipline: [strong | moderate | weak | not-assessed] (N/3 signals)
  Documentation:         [strong | moderate | weak | not-assessed] (N/3 signals)
  ADR conformance:       [strong | moderate | weak | not-assessed] (N/3 signals)
```

## Examples

### Example 1 — Strong across all domains

**Context:** Mature project with WAL+FK+migrations, pinned deps, tagged docs, 7 ADRs conforming.

```
health: strong — 4/4 sub-domains assessed
  Data integrity:        strong (3/3)
  Dependency discipline: strong (3/3)
  Documentation:         strong (3/3)
  ADR conformance:       strong (3/3)
```

### Example 2 — Moderate with documentation concerns

**Context:** Healthy data and deps, but docs have stale TODOs and missing provenance.

```
health: moderate — 4/4 sub-domains assessed
  Data integrity:        strong (3/3)
  Dependency discipline: strong (3/3)
  Documentation:         moderate (2/3) — stale TODO markers detected
  ADR conformance:       strong (3/3)
```

### Example 3 — Weak with multiple domains flagged

**Context:** Unpinned deps, no migration runner, ADR missing sections.

```
health: weak — 4/4 sub-domains assessed
  Data integrity:        weak (1/3) — FK pragma and migration runner missing
  Dependency discipline: weak (1/3) — unpinned versions, no engines field
  Documentation:         strong (3/3)
  ADR conformance:       moderate (2/3) — spot-check found missing section
```

### Example 4 — Partial coverage (fresh scaffold)

**Context:** Just-scaffolded project, no docs directory yet, no ADRs beyond baseline.

```
health: partial — 2/4 sub-domains assessed
  Data integrity:        strong (3/3)
  Dependency discipline: strong (3/3)
  Documentation:         not-assessed (no docs/ directory)
  ADR conformance:       not-assessed (no INDEX.md)
```

## Anti-patterns

### Anti-pattern 1 — Treating health as a replacement for sub-domain skills

health produces stance-level signals, not detailed findings. "Data integrity: moderate" doesn't tell you which pragma is missing. **What to do instead:** run [ascent-data-health](../ascent-data-health/SKILL.md) for the specific finding. health is the summary; enumerators are the detail.

### Anti-pattern 2 — Ignoring moderate stance

"Moderate" means one signal per sub-domain is missing — it's not a crisis, but it's drift. **What to do instead:** address moderate findings before they compound. A project that stays moderate across multiple phases is accumulating health debt.

### Anti-pattern 3 — Running health without ever running individual sub-skills

health gives the 30,000-foot view. If you've never run the individual sub-skills, you don't understand what the stance signals mean concretely. **What to do instead:** run each sub-skill at least once to understand its checks, then use health for ongoing monitoring.
