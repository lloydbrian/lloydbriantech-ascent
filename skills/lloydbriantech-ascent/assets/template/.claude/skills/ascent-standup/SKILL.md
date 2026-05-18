---
name: ascent-standup
description: >-
  Generates a brief, time-scoped standup summary for <<PROJECT_TITLE>>:
  recent activity (last 24 hours of git history + working-memory decisions),
  current focus, plan for next actions, and blockers. The standup reads
  the same project state as ascent-delivery-status but produces a concise
  output a developer reads in 30 seconds.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-standup

Generates a brief standup summary for <<PROJECT_TITLE>>: what happened recently, what's the current focus, what's planned next, and what's blocking. The standup reads the same project state as [ascent-delivery-status](../ascent-delivery-status/SKILL.md) (`.ascent-meta.json`, session artifacts, git log) but produces a concise, time-scoped output — not a comprehensive status report. A developer reads it in 30 seconds.

## When this skill engages

- Daily standup — "give me a quick summary"
- Start of a working session — "what was I doing?"
- When explicitly asked for a standup, summary, or brief update
- When preparing a status message for a teammate or stakeholder
- NOT for comprehensive project status (use ascent-delivery-status instead)
- NOT for feature scoping or planning (use ascent-feature-intake instead)

## Inputs

- **`git log`** — last 24 hours of commit history (the default standup window)
- **`docs/delivery/session-state.md`** — transient working state per §15 (four-state classified)
- **`docs/delivery/working-memory.md`** — accumulating decisions per §15 (four-state classified)
- **`.ascent-meta.json`** — current phase and project identity
- **`docs/delivery/PHASE-PLAN.md`** (optional) — exit criteria for context on what matters

## Outputs

Framework-canonical standup format with four sections:

```markdown
## Standup — <<PROJECT_TITLE>> (YYYY-MM-DD)

### Recent activity (last 24 hours)
- [git-derived activity summary]
- [decisions from working-memory.md made in the last 24 hours]

### Current focus
[from session-state.md if FRESH; from .ascent-meta.json current_focus otherwise]

### Plan
[from session-state.md next actions if FRESH; from PHASE-PLAN pending criteria otherwise]

### Blockers
[from session-state.md blockers if FRESH; "none identified" otherwise]
```

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill. The standup window is **24 hours** — activity older than 24 hours is excluded from "Recent activity" (irregular-cadence support deferred to v0.4.x).

### Step 1 — Read project identity

**Condition:** `.ascent-meta.json` exists with `phase` and `project_slug`.

**Action on PASS:** Extract phase and slug for the standup header.

**Action on FAIL:** Use "<<PROJECT_TITLE>>" as the header. Proceed without phase context.

### Step 2 — Gather recent git activity (24-hour window)

**Condition:** Git repository exists.

**Action:** Run `git log --oneline --since="24 hours ago"`. Count commits. Extract the commit messages.

**Action on commits found:** Summarize: "N commits in the last 24 hours" with a 1-line summary per commit (max 5; truncate with "and N more" if >5).

**Action on no commits:** Report "No commits in the last 24 hours."

**Action on no git:** Report "Not a git repository — skipping git activity."

### Step 3 — Read session-state.md per §15 four-state protocol

**Condition:** Check `docs/delivery/session-state.md` for existence, content, and freshness.

**Action on FRESH:** Extract current focus, next actions, and blockers. These become the "Current focus," "Plan," and "Blockers" sections of the standup.

**Action on STALE:** Extract the same fields but prefix with "Last recorded [date]:" to signal the information may be outdated. Recommend running `make session-snapshot` to refresh.

**Action on EMPTY or MISSING:** Fall back to `.ascent-meta.json` `current_focus` field (if present) for "Current focus." Use PHASE-PLAN.md pending criteria for "Plan." Report "Blockers: none identified (no session state available)."

### Step 4 — Read recent working-memory.md decisions

**Condition:** `docs/delivery/working-memory.md` exists and has entries.

**Action:** Extract entries from `## Decisions` dated within the last 24 hours. Include in "Recent activity" alongside git commits.

**Action on no recent entries:** Omit working-memory decisions from "Recent activity." The git log carries the activity signal.

**Action on EMPTY or MISSING:** Omit entirely.

### Step 5 — Read PHASE-PLAN.md for context

**Condition:** `docs/delivery/PHASE-PLAN.md` exists with exit criteria.

**Action:** Count DONE vs PENDING criteria. If session-state.md was EMPTY or MISSING (Step 3 fallback), use the top pending criterion as the "Plan" section.

**Action on MISSING:** Omit phase-plan context. Report "Plan: define exit criteria via ascent-feature-intake."

### Step 6 — Compose the standup

**Action:** Assemble the four-section standup:

1. **Recent activity (last 24 hours):** Git commits (from Step 2) + working-memory decisions (from Step 4). Interleaved chronologically if both sources have entries.

2. **Current focus:** From session-state.md (Step 3) if FRESH. From `.ascent-meta.json` current_focus if session state unavailable. "Not recorded — run `make session-snapshot`" if neither source has focus data.

3. **Plan:** From session-state.md next actions (Step 3) if FRESH. From PHASE-PLAN.md top pending criterion (Step 5) if session state unavailable. "Define exit criteria via ascent-feature-intake" if no plan source exists.

4. **Blockers:** From session-state.md blockers (Step 3) if FRESH. "None identified" if session state is EMPTY/MISSING and no stalled criteria are detected.

### Step 7 — Output

**Action:** Print the standup in the canonical format. The output is complete — no follow-up questions, no interactive prompts. The standup is a read-and-go artifact.

## Examples

### Example 1 — Active development day with fresh session state

**Input state:** 5 commits in the last 24 hours. session-state.md FRESH (updated 3 hours ago). 1 working-memory decision from today. Phase 2 with 4/8 criteria met.

**Skill output:**
```
## Standup — <<PROJECT_TITLE>> (2026-05-18)

### Recent activity (last 24 hours)
- 5 commits: feat(template): backend skeleton, feat(template): frontend skeleton, 3 more
- Decision: chose Vitest over Jest for test runner (from working-memory.md)

### Current focus
Implementing the frontend skeleton with Vite + React shell (from session-state.md)

### Plan
1. Complete frontend Dockerfile with three-stage build
2. Run smoke test on hello-world scaffold
3. Write CHANGELOG entry for v0.3.0

### Blockers
None
```

### Example 2 — Quiet day, no session state

**Input state:** 0 commits in the last 24 hours. session-state.md MISSING. Phase 1 with 6/8 criteria met. PHASE-PLAN.md has 2 pending criteria.

**Skill output:**
```
## Standup — <<PROJECT_TITLE>> (2026-05-18)

### Recent activity (last 24 hours)
No commits in the last 24 hours.

### Current focus
Not recorded — run `make session-snapshot` to capture focus.

### Plan
Next pending criterion: "Skill answers 'what role handles X?' correctly" (from PHASE-PLAN.md)

### Blockers
None identified (no session state available)
```

### Example 3 — Stale session state with active git

**Input state:** 3 commits in the last 24 hours. session-state.md STALE (last modified 10 days ago). working-memory.md has no recent entries.

**Skill output:**
```
## Standup — <<PROJECT_TITLE>> (2026-05-18)

### Recent activity (last 24 hours)
- 3 commits: fix(template): backend Dockerfile dev stage, chore: update deps, docs: README

### Current focus
Last recorded 2026-05-08: implementing backend healthcheck differentiation (from session-state.md, STALE)
→ Session state may be outdated. Run `make session-snapshot` to refresh.

### Plan
Last recorded 2026-05-08: complete healthcheck implementation, then run smoke test
→ Recommend refreshing plan via `make session-snapshot`.

### Blockers
Last recorded 2026-05-08: better-sqlite3 Node 26 compatibility
→ This blocker may be resolved. Verify current state.
```

### Example 4 — Empty project (freshly scaffolded)

**Input state:** 1 commit (initial scaffold). No session state. No PHASE-PLAN. No working memory.

**Skill output:**
```
## Standup — <<PROJECT_TITLE>> (2026-05-18)

### Recent activity (last 24 hours)
- 1 commit: initial scaffold from ASCENT v0.3.1

### Current focus
Not recorded — run `make session-snapshot` to capture focus.

### Plan
Define exit criteria via ascent-feature-intake (no PHASE-PLAN.md found).

### Blockers
None identified
```

## Anti-patterns

### Anti-pattern 1 — Using standup as a comprehensive status report

The standup is time-scoped (24 hours) and brief. For comprehensive project state, use [ascent-delivery-status](../ascent-delivery-status/SKILL.md). **Why it's tempting:** standup shows enough to feel like a full picture. **What to do instead:** standup for daily check-ins; delivery-status for phase reviews and stakeholder updates.

### Anti-pattern 2 — Ignoring the "run make session-snapshot" recommendation

When session state is STALE or MISSING, the standup recommends refreshing. Ignoring this means the next standup will have the same gap. **Why it's tempting:** the standup is useful even without session state. **What to do instead:** end each working session with `make session-snapshot` so the next standup has fresh data.

### Anti-pattern 3 — Treating the standup as a commitment

The "Plan" section shows what's next based on available state. It's a suggestion, not a promise. **Why it's tempting:** teams read "Plan: X" as "the developer commits to X today." **What to do instead:** the plan is derived from project state; the developer decides what to work on. The standup informs the decision, doesn't make it.

### Anti-pattern 4 — Running standup without reading the blockers

Blockers from session-state.md may be resolved but not cleared. The standup surfaces them honestly (including STALE blockers). **Why it's tempting:** "I know there are no blockers; I don't need to read that section." **What to do instead:** read the blockers section. If a blocker is resolved, update session-state.md (via `make session-snapshot`) so it doesn't appear in the next standup.
