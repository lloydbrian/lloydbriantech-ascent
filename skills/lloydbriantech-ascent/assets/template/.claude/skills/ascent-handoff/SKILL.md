---
name: ascent-handoff
description: >-
  Documents <<PROJECT_TITLE>>'s current state for another developer or
  session takeover. Produces a progressive-depth HANDOFF.md artifact at
  docs/delivery/HANDOFF.md covering current work, recent decisions,
  phase progress, and project conventions.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
---

# ascent-handoff

Documents the project's current state for another developer or for the same developer returning after a long break. Produces a single `HANDOFF.md` artifact with progressive depth: the top section serves a returning developer who just needs to remember what they were doing; the middle section serves an ASCENT-aware engineer who needs project-specific context; the bottom section serves a generic engineer who needs orientation on conventions and architecture.

This is a sibling skill to [ascent-reflect](../ascent-reflect/SKILL.md) and [ascent-delivery-status](../ascent-delivery-status/SKILL.md). reflect writes the §15 artifacts that handoff reads; delivery-status reads the same sources handoff reads. None invoke each other — they share data through the §15 artifact layer and project files.

## When this skill engages

- When handing a project to another developer (team handoff, contractor transition)
- Before a long break (vacation, leave, project pause)
- When a stakeholder asks "where is this project?"
- When explicitly asked to "write a handoff" or "document the project state"
- NOT for session-to-session continuity — use [ascent-reflect](../ascent-reflect/SKILL.md) for that

## Inputs

- **`.ascent-meta.json`** — project identity, current phase (required)
- **`docs/delivery/session-state.md`** — current focus and blockers per §15 (optional; four-state classified)
- **`docs/delivery/working-memory.md`** — accumulated decisions per §15 (optional; four-state classified)
- **`docs/delivery/PHASE-PLAN.md`** — exit criteria and feature tracking (optional)
- **`docs/architecture/decisions/INDEX.md`** — ADR inventory (optional)
- **`git log`** — recent commit activity
- **`README.md`** — project identity and conventions summary

## Outputs

- **`docs/delivery/HANDOFF.md`** — progressive-depth project state document

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Read project identity

**Condition:** `.ascent-meta.json` exists.

**Action on PASS:** Extract project slug, current phase, framework version. Report: "Generating handoff for [project] at phase [phase]."

**Action on FAIL:** Report: "No .ascent-meta.json — cannot determine project identity. Proceeding with available context."

### Step 2 — Read §15 artifacts

**Condition:** Check both `docs/delivery/session-state.md` and `docs/delivery/working-memory.md` per §15 four-state protocol.

**Action on FRESH:** Extract current focus, blockers, next actions (from session-state.md) and recent decisions (from working-memory.md). These populate the top and middle sections.

**Action on STALE:** Extract with staleness warning. Flag in the handoff: "Session state is [N] days old — verify current accuracy."

**Action on EMPTY or MISSING:** Note absence. Top section will rely on git activity and .ascent-meta.json current_focus for "where to start."

### Step 3 — Read phase progress

**Condition:** `docs/delivery/PHASE-PLAN.md` exists.

**Action on PASS:** Count checked vs unchecked exit criteria. Report: "Phase progress: N/M criteria met."

**Action on FAIL:** Omit phase progress from handoff. Note: "No PHASE-PLAN.md — phase progress not available."

### Step 4 — Read recent git activity

**Action:** Extract from `git log --oneline --since="14 days ago"` the recent commit summary. Count commits, identify active branches.

### Step 5 — Read project conventions

**Action:** Scan for convention indicators:
- ADR count from `docs/architecture/decisions/INDEX.md`
- Skill count from `.claude/skills/ascent-*/SKILL.md`
- Make target count from `make/*.mk`
- README.md presence and persona table

### Step 6 — Synthesize HANDOFF.md

**Action:** Build the progressive-depth document:

```markdown
# Handoff — <<PROJECT_TITLE>>

Generated: YYYY-MM-DD

## Where to start

[Current focus from session-state.md or .ascent-meta.json]
[Open blockers, if any]
[Immediate next actions]
[Active branch and recent commit summary]

## Project state

- Phase: [current phase] — [N/M exit criteria met]
- Recent decisions (from working-memory.md):
  - [dated decision entries, last 5-10]
- Recent activity: [N commits in last 14 days]
- Open work: [unchecked PHASE-PLAN items]

## Project conventions

- Framework: ASCENT v[version] — [N] principles enforced
- Architecture decisions: [N] ADRs at docs/architecture/decisions/
- Embedded skills: [N] ascent-* skills at .claude/skills/
- Operator vocabulary: `make help` — [N] targets across [sections]
- Backend: [stack summary from package.json]
- Session resumption: session-state.md + working-memory.md per §15
```

### Step 7 — Present and write

**Condition:** HANDOFF.md content is synthesized.

**Action:** Present the complete document to the developer for review.

**If `docs/delivery/HANDOFF.md` already exists:** Present existing content alongside proposed content. Ask: "(A) Overwrite with new handoff. (B) Abort." The skill never silently overwrites.

**Gate:** Developer must confirm before writing.

**Write** to `docs/delivery/HANDOFF.md`. Valid path: `docs/delivery/HANDOFF.md` only.

Report: "Handoff written to docs/delivery/HANDOFF.md."

## Examples

### Example 1 — Mature project handoff

**Context:** Phase 2 project with 5/8 criteria met, 47 commits, 7 ADRs, 15 skills.

**HANDOFF.md top section:**
```
## Where to start

Current focus: Building nginx config variants for dev, prod, and dist.
Blockers: None.
Next actions: Add caching rules to nginx.prod.conf, wire up dist variant.
Active branch: feat/phase-2-container-topology (3 commits ahead of main).
```

### Example 2 — Fresh scaffold handoff

**Context:** Just-scaffolded project, no session state, no decisions.

**HANDOFF.md top section:**
```
## Where to start

This is a freshly scaffolded project. No session state or working memory on record.
Start with: `make dev-up` to verify the scaffold boots, then review README.md.
Phase: 0-foundation (0/0 exit criteria — no PHASE-PLAN.md yet).
```

### Example 3 — Handoff with existing HANDOFF.md

**Skill output:** "HANDOFF.md already exists (generated 2026-05-15). Options: (A) Overwrite with fresh handoff. (B) Abort."

## Anti-patterns

### Anti-pattern 1 — Handoff without current state

Writing a handoff when session-state.md is MISSING and no recent commits exist. **Why it's tempting:** "better than nothing." **What to do instead:** run [ascent-reflect](../ascent-reflect/SKILL.md) first to capture current state, then generate the handoff. A handoff built from stale or empty data misleads the reader.

### Anti-pattern 2 — Handoff as documentation substitute

Using HANDOFF.md as the project's primary documentation. **Why it's tempting:** the handoff is comprehensive and well-structured. **What to do instead:** HANDOFF.md is a snapshot of current state, not permanent documentation. It goes stale within days. Project documentation lives in docs/, ADRs, and README.md.

### Anti-pattern 3 — Stale handoff left in repo

Generating HANDOFF.md before a break but never updating it. **Why it's tempting:** the handoff was accurate when written. **What to do instead:** delete or regenerate HANDOFF.md when resuming work. A stale handoff is worse than no handoff — it gives false confidence about project state.
