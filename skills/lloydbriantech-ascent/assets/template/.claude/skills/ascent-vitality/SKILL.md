---
name: ascent-vitality
description: >-
  Project activity and momentum signals for <<PROJECT_TITLE>>. Measures
  git activity (commit frequency, stale branches), open-work-item age
  (TODOs, Draft ADRs), and CHANGELOG recency. Activity/momentum, not
  quality — see ascent-qa for quality aggregation.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-vitality

Measures project activity and momentum — "is this project actively maintained and making progress?" This is distinct from quality: a project can be structurally perfect but stalled (no commits, no progress on exit criteria, forgotten TODOs). [ascent-qa](../ascent-qa/SKILL.md) covers quality aggregation; vitality covers momentum.

**Scope boundary:** vitality checks activity signals: git commit frequency, stale branches, open-work-item age, CHANGELOG recency. Quality concerns (structural integrity, dependency pinning, doc provenance, security) belong to qa and the Cluster 4/7 health-check skills. vitality stays out of that lane.

## When this skill engages

- When a developer asks "is this project still active?" or "are we stalling?"
- As a periodic momentum check (recommended: monthly or per-phase)
- Before a phase gate to verify sustained activity
- When onboarding to a project of unknown status

## Inputs

- **`git log`** — commit history for frequency and recency analysis
- **`git branch`** — branch list for stale-branch detection
- **Source files under `docs/`, `backend/`, `frontend/`** — scanned for TODO/TBD/FIXME markers
- **`docs/architecture/decisions/ADR-*.md`** — scanned for `Status: Proposed` (Draft ADRs)
- **`CHANGELOG.md`** — latest entry date

## Outputs

- **Per-signal report** — each signal marked ACTIVE, STALE, or SKIP with specific findings
- **Summary line** — "vitality: [active | slowing | stalled] — N signals assessed"

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Git activity signals

**Action:** Assess three git-based signals:

**Last commit age:** Run `git log -1 --format=%ct` to get the most recent commit timestamp. Compute days since last commit.
- **ACTIVE:** last commit within 14 days
- **STALE:** last commit more than 14 days ago

**Commit frequency:** Run `git log --oneline --since="30 days ago"` and count commits.
- Report: "[N] commits in the last 30 days."

**Stale branches:** Run `git branch --no-merged main` to list unmerged branches. For each, check if its latest commit is older than 30 days.
- Report: "[N] stale branches (unmerged, last commit >30 days ago)."

### Step 2 — Open-work-item age

**Action:** Assess two work-item signals:

**Stale TODOs:** Scan all source files (`backend/`, `frontend/`, `docs/`) for lines containing `TODO`, `TBD`, `FIXME`, or `PLACEHOLDER`. For each match, check the containing file's modification timestamp via `stat`. Files last modified more than **30 days** ago have stale work items. Report: "[N] stale work items across [M] files (>30 days untouched)."

Detection mechanism: `grep -rn 'TODO\|TBD\|FIXME\|PLACEHOLDER'` across source directories, excluding `node_modules/`, `.git/`, `dist/`. File age computed via `stat -f %m` (macOS) or `stat -c %Y` (Linux).

**Draft ADRs:** Scan `docs/architecture/decisions/ADR-*.md` for files whose `**Status:**` field contains `Proposed` (not yet accepted). These are decisions in limbo — deliberated but not resolved. Report: "[N] ADRs in Proposed status."

Detection mechanism: `grep -l '^\*\*Status:\*\* Proposed'` across ADR files.

### Step 3 — CHANGELOG recency

**Condition:** `CHANGELOG.md` exists.

**Action:** Extract the date from the most recent version section header or the most recent dated entry. Compute days since that date.

- **ACTIVE:** CHANGELOG entry within 60 days
- **STALE:** CHANGELOG entry more than 60 days ago

**Fallback:** If CHANGELOG.md doesn't exist, report "CHANGELOG recency — SKIP (no CHANGELOG.md)."

### Step 4 — Produce vitality summary

**Action:** Aggregate signals into a vitality rating:

- **Active:** last commit within 14 days AND no more than 2 stale work items
- **Slowing:** last commit within 14 days but 3+ stale work items, OR last commit 14-30 days ago
- **Stalled:** last commit more than 30 days ago, OR 5+ stale work items with no recent commits

Report:
```
vitality: [active | slowing | stalled] — N signals assessed
  Last commit:       [N days ago] [ACTIVE | STALE]
  Commit frequency:  [N] commits in last 30 days
  Stale branches:    [N] unmerged branches >30 days
  Stale work items:  [N] TODOs/TBDs >30 days across [M] files
  Draft ADRs:        [N] in Proposed status
  CHANGELOG recency: [N days since last entry] [ACTIVE | STALE]
```

## Examples

### Example 1 — Active project

```
vitality: active — 6 signals assessed
  Last commit:       2 days ago (ACTIVE)
  Commit frequency:  23 commits in last 30 days
  Stale branches:    0 unmerged branches >30 days
  Stale work items:  1 TODO >30 days across 1 file
  Draft ADRs:        0 in Proposed status
  CHANGELOG recency: 12 days since last entry (ACTIVE)
```

### Example 2 — Stalling project

```
vitality: slowing — 6 signals assessed
  Last commit:       18 days ago (STALE)
  Commit frequency:  3 commits in last 30 days
  Stale branches:    2 unmerged branches >30 days
  Stale work items:  7 TODOs >30 days across 4 files
  Draft ADRs:        2 in Proposed status
  CHANGELOG recency: 45 days since last entry (ACTIVE)
```

## Anti-patterns

### Anti-pattern 1 — Treating low vitality as failure

Some projects are mature and stable — infrequent commits and few open work items may mean the project is done, not stalled. **What to do instead:** interpret vitality in context. A Phase 0 project with low vitality is likely stalled. A production project with low vitality may be in maintenance mode — which is fine.
