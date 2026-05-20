---
name: ascent-reflect
description: >-
  End-of-session capture for <<PROJECT_TITLE>>. Interviews the developer
  for current focus, decisions made, blockers, and next actions, then
  writes to session-state.md (overwrite) and working-memory.md (append)
  per §15 session resumption protocol.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
  - Edit
---

# ascent-reflect

Captures end-of-session state through a structured interview. While `make session-snapshot` provides quick mechanical capture (branch, commit, dirty count, scaffold prompts for fill-in), this skill produces richer content by interviewing the developer directly. Both paths write to the same §15 artifacts using the same template format defined in the `session-protocol` reference module — reflect fills in the content during the interview rather than leaving `(fill in:)` prompts.

This is a sibling skill to [ascent-delivery-status](../ascent-delivery-status/SKILL.md) and [ascent-feature-intake](../ascent-feature-intake/SKILL.md) — all three interact with §15 artifacts. delivery-status reads session-state.md; feature-intake appends to working-memory.md; reflect writes session-state.md and appends to working-memory.md. The artifacts are the shared data layer; the skills do not invoke each other. The artifacts written here are subsequently read by [ascent-handoff](../ascent-handoff/SKILL.md) and [ascent-onboard](../ascent-onboard/SKILL.md).

## When this skill engages

- At end-of-session — the developer is about to close the conversation
- Before a significant context switch (moving from one feature to another)
- After a significant decision has been made and should be recorded durably
- At phase boundaries — capturing the state before transitioning to the next phase
- When explicitly asked to "capture session state" or "reflect on this session"
- NOT for quick mid-session checkpoints — use `make session-snapshot` for those

## Inputs

- **Developer interview responses** — current focus, decisions, blockers, next actions (required; the skill asks)
- **`docs/delivery/session-state.md`** — existing transient state per §15 (optional; four-state classified)
- **`docs/delivery/working-memory.md`** — existing accumulated decisions per §15 (optional; four-state classified)
- **`.ascent-meta.json`** — project identity and current phase (for phase context section)
- **`git` state** — current branch, recent commits (for phase context)

## Outputs

- **Updated `docs/delivery/session-state.md`** — overwritten with current session state (same template format as `make session-snapshot`: Captured timestamp, Current focus, Active decisions, Blockers, Next actions, Phase context)
- **Updated `docs/delivery/working-memory.md`** — new decisions appended under `## Decisions` with dated entries

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Read current session-state.md per §15

**Condition:** Check `docs/delivery/session-state.md` for existence and content.

**Action on FRESH:** Read and present to developer: "Previous session state (from [date]): [summary]. I'll capture the current state — confirm what's changed."

**Action on STALE:** Read and flag: "Session state is from [N] days ago. I'll capture fresh state — review what may have changed since then."

**Action on EMPTY or MISSING:** Report: "No prior session state. Starting fresh capture."

### Step 2 — Read current working-memory.md per §15

**Condition:** Check `docs/delivery/working-memory.md` for existence and content.

**Action on FRESH or STALE:** Read existing decisions to provide context. Report: "Working memory has [N] prior decisions on record."

**Action on EMPTY or MISSING:** Note: "No working memory yet — this session's decisions will be the first entries."

### Step 3 — Interview: Current focus

**Action:** Ask the developer: "What are you working on right now? One sentence."

Capture the response as the Current focus section. If the developer's answer is multi-sentence, distill to one sentence and confirm.

### Step 4 — Interview: Decisions made

**Action:** Ask: "What decisions did you make this session that should persist? These go in working-memory.md — they're the things the next session shouldn't re-litigate."

Capture each decision as a dated entry: `- YYYY-MM-DD: [decision summary]`. If the developer says "none," record no new decisions (working-memory.md is not modified).

### Step 5 — Interview: Blockers

**Action:** Ask: "Anything blocking progress? What's preventing forward motion, and who or what can unblock it?"

Capture as the Blockers section. "None currently" is a valid answer.

### Step 6 — Interview: Next actions

**Action:** Ask: "What are the immediate next steps when you (or someone else) resumes this work?"

Capture as the Next actions section. These should be concrete and actionable, not aspirational.

### Step 7 — Present combined preview

**Action:** Present both files' proposed changes in a single preview:

**session-state.md** (overwrite):
```markdown
# Session state

Captured: YYYY-MM-DD-HHMM

## Current focus
[from Step 3]

## Active decisions
[from Step 4, or "(none pending)"]

## Blockers
[from Step 5]

## Next actions
[from Step 6]

## Phase context
- Phase: [from .ascent-meta.json]
- Branch: [current branch] ([short SHA])
- Uncommitted changes: [count]
```

**working-memory.md** (append — only if Step 4 produced decisions):
```markdown
## Decisions
[existing entries preserved]
- YYYY-MM-DD: [new decision 1]
- YYYY-MM-DD: [new decision 2]
```

**Gate:** Developer must confirm before writing. "Review both files. Confirm to write, or adjust any section."

### Step 8 — Write both files atomically

**Condition:** Developer has confirmed the preview.

**Action:** Two writes, both or neither:

1. **Write** `docs/delivery/session-state.md` — overwrite with the complete session-state content from Step 7. This replaces any prior content (overwrite semantics per `session-protocol` reference module).
2. **Edit** `docs/delivery/working-memory.md` — append new decision entries below existing content under `## Decisions`.

**Four-state handling for working-memory.md:**
- FRESH or STALE: append below existing entries
- EMPTY: add entries as the first items under `## Decisions`
- MISSING: create the file with standard structure (title + three section headers: Decisions, Patterns adopted, Patterns rejected) then append

**Valid paths:** This skill writes only to `docs/delivery/session-state.md` and `docs/delivery/working-memory.md`. Any other path is a step failure.

If Step 4 produced no new decisions, only session-state.md is written (working-memory.md is untouched).

Report: "Session state captured. session-state.md overwritten. working-memory.md [updated with N new entries | unchanged (no new decisions)]."

## Examples

### Example 1 — End-of-session capture

**Context:** Developer finishing a day's work on Phase 2 template assets.

**Interview responses:**
- Focus: "Building the nginx config variants for dev, prod, and dist"
- Decisions: "Chose to put security headers in nginx.prod.conf only (not dev)" and "Decided against gzip for dev — adds complexity, no benefit for localhost"
- Blockers: "None"
- Next actions: "1. Add caching rules to nginx.prod.conf. 2. Wire up dist variant for the smoke test."

**Result:** session-state.md overwritten with filled content. working-memory.md gets two new dated entries under Decisions.

### Example 2 — First session (no prior state)

**Context:** Developer just scaffolded a new project. No session-state.md or working-memory.md exist.

**Skill output:** "No prior session state. Starting fresh capture." Interviews as normal. Creates both files — session-state.md with first state, working-memory.md with standard structure plus first decisions.

### Example 3 — Session with no new decisions

**Context:** Developer spent the session fixing bugs, no architectural decisions made.

**Interview responses:**
- Focus: "Fixing the healthz endpoint regression"
- Decisions: "None this session"
- Blockers: "None"
- Next actions: "Run the full test suite and commit"

**Result:** session-state.md overwritten. working-memory.md unchanged (no append).

## Anti-patterns

### Anti-pattern 1 — Deferring capture "until later"

Closing the session without reflecting because "I'll remember." **Why it's tempting:** the session was productive and the developer feels the context is fresh. **What to do instead:** context decays fast. Reflect takes 2-3 minutes; re-deriving context next session takes 10-15.

### Anti-pattern 2 — Capturing without the interview

Writing session-state.md directly (or via `make session-snapshot`) without articulating decisions and blockers. **Why it's tempting:** it's faster. **What to do instead:** the interview is the value. Decisions and blockers that aren't articulated don't get recorded. Use `make session-snapshot` for quick captures; use reflect for thorough ones.

### Anti-pattern 3 — Overwriting working-memory.md

Replacing the entire working-memory.md with just this session's decisions. **Why it's tempting:** the file feels cluttered with old entries. **What to do instead:** working-memory.md is append-only. Old decisions are historical context — they explain why the project is the way it is. If an entry is wrong, supersede it with a new dated entry; don't delete the original.
