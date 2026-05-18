---
name: ascent-delivery-status
description: >-
  Surfaces the current phase, outstanding work, exit-criteria progress,
  and recommended next actions for <<PROJECT_TITLE>>. The delivery-lead's
  at-a-glance view of where the project is and what's needed to close
  the current phase gate. Per §15, incorporates session-state.md and
  working-memory.md into the synthesis when present.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-delivery-status

Synthesizes <<PROJECT_TITLE>>'s delivery state: current phase, exit-criteria checklist progress, outstanding work items, blockers, and recommended next actions. This is the answer to "where are we and what's next?" Per §15 (session resumption), the synthesis incorporates transient session state and accumulated decisions when those artifacts are present and fresh.

## When this skill engages

- Daily standup — "what's the project state?"
- Before a phase-gate review — "are we ready to close?"
- When the delivery-lead needs a status synthesis for stakeholders
- After a burst of work — "did that close anything?"
- On session start — Claude reads delivery-status context as part of §15 resumption
- When explicitly asked for project status in any form

## Inputs

- **`.ascent-meta.json`** — project identity, current phase, framework version (required)
- **`docs/delivery/PHASE-PLAN.md`** — phase exit criteria and feature tracking (optional; may not exist yet)
- **`docs/delivery/session-state.md`** — transient working state per §15 (optional; four-state classified)
- **`docs/delivery/working-memory.md`** — accumulating decisions per §15 (optional; four-state classified)
- **`CHANGELOG.md`** — recent entries showing what shipped
- **`git log`** — recent commit activity (last 7 days)

## Outputs

- **Phase summary** — current phase name, number, and how long it's been active
- **Exit-criteria checklist** — each criterion marked DONE or PENDING with evidence
- **Session context** (when §15 artifacts are FRESH or STALE) — current focus, active decisions, blockers from session-state.md; recent decisions from working-memory.md
- **Outstanding work** — what's left to close the phase
- **Recommended next actions** — ordered by impact (what would close the most criteria)
- **Blockers** — identified from session state, stale branches, or failing checks

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Read project identity from .ascent-meta.json

**Condition:** `.ascent-meta.json` exists and contains `phase`, `project_slug`, and `framework_version` fields.

**Action on PASS:** Extract phase identifier (e.g., `"0-foundation"`), project slug, and framework version. Report "Project: <<PROJECT_SLUG>>, Phase: [phase], Framework: v[version]."

**Action on FAIL:** Report "FAIL: .ascent-meta.json missing or malformed — cannot determine project phase." Exit with error.

### Step 2 — Read session-state.md per §15 four-state protocol

**Condition:** Check `docs/delivery/session-state.md` for existence, content, and freshness.

**Action on FRESH (modified within 7 days):** Extract current focus, active decisions, blockers, and next actions. Include in synthesis: "Current focus: [from session-state.md]. Active decisions: [list]. Blockers: [list]."

**Action on STALE (modified >7 days ago):** Extract the same fields but flag staleness: "Session state from [date] — may be outdated. Current focus was: [content]."

**Action on EMPTY or MISSING:** Omit session context from synthesis entirely. No mention of session state — the status report covers phase-level progress only.

### Step 3 — Read working-memory.md per §15 four-state protocol

**Condition:** Check `docs/delivery/working-memory.md` for existence, content, and freshness.

**Action on FRESH:** Extract recent decisions (last 7 days' entries under `## Decisions`). Include in synthesis: "Recent decisions: [list with dates]."

**Action on STALE:** Extract decisions but flag: "Working memory last updated [date] — recent decisions may not be captured."

**Action on EMPTY or MISSING:** Omit working-memory context. Report phase progress without decision overlay.

### Step 4 — Locate and parse PHASE-PLAN.md

**Condition:** `docs/delivery/PHASE-PLAN.md` exists and contains exit criteria (items prefixed with `- [ ]` or `- [x]`).

**Action on PASS:** Parse each criterion. For `- [x]` items, mark DONE. For `- [ ]` items, mark PENDING. Count totals.

**Action on FAIL (file missing):** Report "No PHASE-PLAN.md found — phase exit criteria not yet defined. Recommend running ascent-feature-intake to structure the phase plan."

**Action on FAIL (no criteria):** Report "PHASE-PLAN.md exists but contains no exit criteria checkboxes."

**Fallback:** If the file uses a different checkbox format (e.g., `* [ ]` or numbered lists), attempt to parse those as well.

### Step 5 — Scan recent git activity

**Condition:** Git repository exists. Read `git log --oneline --since="7 days ago"` for recent commits.

**Action on PASS:** Summarize: "N commits in the last 7 days. Most recent: [commit message] ([date])." Identify which exit criteria the recent commits may have addressed (keyword matching against criteria text).

**Action on FAIL (no git):** Report "Not a git repository — cannot assess recent activity."

**Action on FAIL (no recent commits):** Report "No commits in the last 7 days. The project may be stalled."

### Step 6 — Synthesize outstanding work

**Condition:** Exit criteria from Step 4 are available.

**Action:** List each PENDING criterion. For each, estimate what work remains (based on file existence, test results, or git activity). Order by estimated impact — the criterion that would close with the least remaining work goes first.

**Fallback:** If no PHASE-PLAN.md exists, infer outstanding work from the project's structural state (e.g., "backend/ exists but no tests yet" → "test infrastructure is outstanding").

### Step 7 — Generate recommended next actions

**Action:** Produce an ordered list of 3-5 recommended actions. Each action names:
- What to do (specific, not vague)
- Which exit criterion it addresses (if applicable)
- Estimated effort (small/medium/large)

Priority order: (1) actions that close exit criteria, (2) actions that unblock other work, (3) actions that address session-state blockers.

### Step 8 — Aggregate and report

Compile the full status report with sections:
1. **Project identity** (from Step 1)
2. **Session context** (from Steps 2-3, if available)
3. **Phase progress** (from Step 4: N/M criteria met)
4. **Recent activity** (from Step 5)
5. **Outstanding work** (from Step 6)
6. **Recommended next actions** (from Step 7)
7. **Blockers** (from session state or inferred from stalled criteria)

## Examples

### Example 1 — Mid-phase project with fresh session state

**Input state:** Phase 1 with 5/8 exit criteria met. session-state.md is FRESH (updated yesterday). working-memory.md has 3 recent decisions. 12 commits in the last week.

**Skill output:**
```
Delivery status — <<PROJECT_TITLE>>
Phase: 1-parent-skill-skeleton (active 5 days)

Session context (from session-state.md, FRESH):
  Current focus: implementing routing logic for the parent skill
  Active decisions: whether to split Chunk 5 or ship as single PR
  Blockers: none

Recent decisions (from working-memory.md):
  - 2026-05-16: Accepted all 6 recommendations for backend Dockerfile
  - 2026-05-16: Chose Vitest over Jest for test runner
  - 2026-05-15: Approved 7-chunk Phase 1 decomposition

Phase progress: 5/8 exit criteria met
  [x] SKILL.md with frontmatter
  [x] Reference modules populated
  [x] Root Makefile with SDLC help
  [x] make qa-skill-frontmatter validates
  [x] make qa-links validates
  [ ] Skill answers "what role handles X?" correctly
  [ ] No scaffolding yet (talk, not write)
  [ ] CHANGELOG v0.2.0 entry

Recent activity: 12 commits in last 7 days (most recent: "feat(references): nine role modules")

Recommended next actions:
  1. Implement routing logic in SKILL.md (closes criterion 6) — medium effort
  2. Write CHANGELOG v0.2.0 entry (closes criterion 8) — small effort
  3. Verify "no scaffolding" constraint holds (closes criterion 7) — small effort
```

### Example 2 — New project, no PHASE-PLAN

**Input state:** Freshly scaffolded project. No PHASE-PLAN.md. session-state.md is MISSING. working-memory.md is EMPTY (just title).

**Skill output:**
```
Delivery status — <<PROJECT_TITLE>>
Phase: 0-foundation (active 0 days)

No PHASE-PLAN.md found — phase exit criteria not yet defined.
Recommend: run ascent-feature-intake to structure the phase plan.

Recent activity: 1 commit in last 7 days (initial scaffold)

Recommended next actions:
  1. Define Phase 0 exit criteria via ascent-feature-intake — medium effort
  2. Verify scaffold health via ascent-self-audit — small effort
  3. Create .env from .env.example and configure — small effort
```

### Example 3 — Stale session state

**Input state:** Phase 2 with 3/6 criteria met. session-state.md modified 12 days ago. working-memory.md has entries but last entry is 14 days old.

**Skill output:**
```
Delivery status — <<PROJECT_TITLE>>
Phase: 2-template-assets (active 18 days)

Session state from 2026-05-04 — may be outdated.
  Current focus was: backend Dockerfile optimization
  Blockers were: better-sqlite3 Node 26 compatibility

Working memory last updated 2026-05-02 — recent decisions may not be captured.

Phase progress: 3/6 exit criteria met
  ...

Recommended next actions:
  1. Run make session-snapshot to update session state — small effort
  2. ...
```

### Example 4 — Phase gate review (all criteria met)

**Input state:** Phase 1 with 8/8 criteria met. session-state.md FRESH. No blockers.

**Skill output:**
```
Delivery status — <<PROJECT_TITLE>>
Phase: 1-parent-skill-skeleton (active 12 days)

Phase progress: 8/8 exit criteria met ✅
All exit criteria satisfied. Ready for phase-gate review.

Recommended next actions:
  1. Update CHANGELOG.md with phase summary — small effort
  2. Tag the release — small effort
  3. Wait for "Proceed with Phase 2" signal
```

## Anti-patterns

### Anti-pattern 1 — Treating delivery-status as a monitoring dashboard

The output should prompt a **decision** (close the phase, add work, unblock a dependency) — not just report state passively. If the output doesn't end with "→ do this next," the skill isn't earning its invocation. **What to do instead:** always include recommended next actions, even if the recommendation is "wait for the go-signal."

### Anti-pattern 2 — Running delivery-status without reading the output

Invoking the skill to "check the box" without acting on the recommendations. **Why it's tempting:** the skill runs, the output scrolls by, the developer moves on. **What to do instead:** read the recommended actions. If none are actionable, the project is either done or stalled — both deserve attention.

### Anti-pattern 3 — Ignoring stale session state

Seeing "session state from [date] — may be outdated" and ignoring it. **Why it's tempting:** the status report is useful even without session context. **What to do instead:** run `make session-snapshot` to update session state. Stale state is worse than no state — it creates false confidence about what the developer was working on.

### Anti-pattern 4 — Using delivery-status instead of ascent-feature-intake for new features

Asking delivery-status "what should I build next?" when the answer is "define the feature first." **Why it's tempting:** delivery-status shows outstanding work, which feels like a todo list. **What to do instead:** use [ascent-feature-intake](../ascent-feature-intake/SKILL.md) to decompose the feature into testable criteria, then delivery-status will surface the criteria as outstanding work.

### Anti-pattern 5 — Manually editing PHASE-PLAN.md to make criteria pass

Changing `- [ ]` to `- [x]` without doing the work. **Why it's tempting:** the checkbox is the gate; flipping it feels like progress. **What to do instead:** delivery-status verifies criteria against project state where possible (file existence, test results). Manual checkbox-flipping without evidence is detectable by the skill.
