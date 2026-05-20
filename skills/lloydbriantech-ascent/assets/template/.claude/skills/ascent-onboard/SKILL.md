---
name: ascent-onboard
description: >-
  Guides a new developer through <<PROJECT_TITLE>> with a structured
  "first hour" walkthrough. Read-only synthesis — detects project
  maturity from state and adapts depth accordingly. Covers identity,
  conventions, current state, key decisions, and where to start.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-onboard

Guides a new developer through the project with a structured "first hour" walkthrough. The skill detects project maturity from state (not from the developer's self-reported experience) and adapts: a fresh scaffold gets heavier framework orientation; a mature project gets heavier project-specific context. The output is structured prose delivered in the conversation — no file is created.

This is a sibling skill to [ascent-handoff](../ascent-handoff/SKILL.md) and [ascent-delivery-status](../ascent-delivery-status/SKILL.md). All three read from the same project sources (§15 artifacts, `.ascent-meta.json`, `PHASE-PLAN.md`, ADRs). None invoke each other. handoff produces a written artifact for async handoff; onboard produces a conversational walkthrough for live onboarding.

## When this skill engages

- When a new developer joins the project (any experience level)
- When returning to a project after a long absence (weeks or months)
- When explicitly asked "where do I start?" or "walk me through this project"
- When a developer asks "what is this project?" or "how does this work?"
- NOT for session-to-session continuity — use [ascent-reflect](../ascent-reflect/SKILL.md) for capture and the §15 resumption protocol for re-entry

## Inputs

- **`.ascent-meta.json`** — project identity, current phase, framework version (required)
- **`README.md`** — project overview and persona entry points
- **`docs/architecture/decisions/INDEX.md`** — ADR inventory and decision history
- **`docs/delivery/PHASE-PLAN.md`** — current phase progress (optional)
- **`docs/delivery/working-memory.md`** — accumulated decisions per §15 (optional; four-state classified)
- **`.claude/skills/INTENT-MAP.md`** — skill collection overview
- **`Makefile` + `make/*.mk`** — operator vocabulary

## Outputs

- **Structured conversational walkthrough** covering five orientation areas:
  1. Project identity — what this project is, who owns it, what phase it's in
  2. Conventions — framework principles, make vocabulary, ADR discipline
  3. Current state — phase progress, recent decisions, active work
  4. Key decisions — the most important ADRs the developer should read
  5. Where to start — concrete first actions for the developer

No file is written. The output is conversation-only.

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Read project identity

**Condition:** `.ascent-meta.json` exists.

**Action on PASS:** Extract project slug, phase, framework version. This anchors the entire walkthrough.

**Action on FAIL:** Report: "No .ascent-meta.json found. This may not be an ASCENT project, or it hasn't been scaffolded yet." Proceed with available context from README.md.

### Step 2 — Detect project maturity

**Action:** Assess project maturity from state indicators:

- **Fresh scaffold** (maturity: low): `.ascent-meta.json` exists but `working-memory.md` is MISSING or EMPTY, `PHASE-PLAN.md` doesn't exist or has 0 checked items, ADR INDEX has only the 7 baseline ADRs.
- **Established project** (maturity: high): `working-memory.md` has entries, `PHASE-PLAN.md` has checked items, ADR count exceeds baseline 7, git log shows sustained activity.
- **Mid-development** (maturity: medium): some history but not yet mature. Between the two extremes.

This detection drives the balance of framework orientation vs project-specific context in the walkthrough.

### Step 3 — Read project conventions

**Action:** Scan for convention indicators:
- ADR count and titles from `docs/architecture/decisions/INDEX.md`
- Skill count from `.claude/skills/ascent-*/`
- Make section count from `make/*.mk` files
- Backend stack from `backend/package.json` (if present)
- Frontend stack from `frontend/package.json` (if present)

### Step 4 — Read current state

**Condition:** Check `docs/delivery/PHASE-PLAN.md` and `docs/delivery/working-memory.md` per §15 four-state protocol.

**Action on FRESH or STALE:** Extract phase progress (N/M criteria), recent decisions, active work items. For STALE, note: "Working memory last updated [N] days ago."

**Action on EMPTY or MISSING:** Note: "No phase plan or working memory on record. This project may be freshly scaffolded or pre-planning."

### Step 5 — Identify key decisions

**Action:** From the ADR INDEX, identify the most important decisions for a new developer:
- All ADRs with status "Accepted" (the currently-active decisions)
- Any ADR that constrains daily development work (backend layering, database choice, logging format)
- Prioritize by impact: architecture > data > tooling > process

Present the top 3-5 ADRs with one-line summaries and links.

### Step 6 — Determine "where to start"

**Action:** Based on project maturity:

**Fresh scaffold:** "Start with `make dev-up` to verify the scaffold boots. Then read README.md for the project overview. Run `make help` to see available operations. The 7 baseline ADRs explain why the project is structured this way."

**Established project:** "Start by reading the current PHASE-PLAN.md to understand what's in progress. Review the last 5 entries in working-memory.md for recent decisions. Run `make dev-status` to check the stack. The open PHASE-PLAN items are your immediate task candidates."

**Mid-development:** Blend of both — framework orientation where conventions aren't yet visible, project-specific context where state exists.

### Step 7 — Deliver walkthrough

**Action:** Present the walkthrough as structured prose in the conversation, organized into the five orientation areas:

1. **Project identity** — "[project] is at Phase [N], built on ASCENT v[version]. [One sentence from README or .ascent-meta.json description]."
2. **Conventions** — "[N] principles enforced, [N] ADRs, `make help` for operations. Backend: [stack]. Frontend: [stack]."
3. **Current state** — "Phase [N]: [progress]. Recent decisions: [last 3 from working-memory]. [Blockers if any from session-state]."
4. **Key decisions** — "Read these ADRs first: [top 3-5 with links]."
5. **Where to start** — "[Maturity-appropriate guidance from Step 6]."

The walkthrough is concise (target: 20-30 lines of prose). A new developer should be oriented in under 5 minutes of reading.

## Examples

### Example 1 — Mature project onboard

**Context:** Phase 2 project, 12 ADRs, 47 commits, working-memory with 8 decisions.

**Walkthrough excerpt:**
```
Project identity: hello-world is at Phase 2 (template assets), built on ASCENT v0.3.1.

Conventions: 15 principles enforced. 12 ADRs at docs/architecture/decisions/.
  `make help` shows 34 targets across DEV/TEST/QA/SEC/VALIDATE/DOCS/INFRA.
  Backend: Express + SQLite-WAL. Frontend: React + Vite.

Current state: Phase 2 — 5/8 exit criteria met. 3 remaining:
  nginx config variants, smoke test, skill scaffolds.
  Recent decisions: chose security headers in prod only, rejected gzip for dev.

Key decisions to read first:
  ADR-001: Container-first development
  ADR-002: Backend layering (routes → controllers → services → storage)
  ADR-004: SQLite-WAL as default database

Where to start: Read PHASE-PLAN.md for open work items. Run `make dev-status`
  to check the stack. The 3 unchecked exit criteria are your task candidates.
```

### Example 2 — Fresh scaffold onboard

**Context:** Just-scaffolded project, no working memory, no phase plan.

**Walkthrough excerpt:**
```
Project identity: my-app is at Phase 0 (foundation), built on ASCENT v0.3.1.

Conventions: 15 principles enforced. 7 baseline ADRs explain the scaffold's
  architecture. `make help` shows the full operator vocabulary.

Current state: Freshly scaffolded. No phase plan or working memory on record.

Key decisions: All 7 baseline ADRs are relevant — they explain why the project
  uses containers (ADR-001), four-layer backend (ADR-002), make vocabulary
  (ADR-003), SQLite-WAL (ADR-004), JSON logging (ADR-005).

Where to start: Run `make dev-up` to verify the scaffold boots. Open
  http://localhost:3000 to see the frontend. Read README.md for the overview.
```

### Example 3 — Mid-phase project onboard

**Context:** Phase 1, 3/6 criteria met, 2 decisions in working memory.

**Walkthrough excerpt:** Blends framework orientation (for conventions not yet exercised) with project-specific state (for work already in progress).

## Anti-patterns

### Anti-pattern 1 — Onboard as replacement for reading docs

Using the onboard walkthrough as the only orientation, skipping README, ADRs, and PHILOSOPHY.md. **Why it's tempting:** the walkthrough covers everything briefly. **What to do instead:** the walkthrough is an index, not a substitute. It points to the docs that matter; reading those docs is still necessary.

### Anti-pattern 2 — Onboard without framework context

Running onboard in a project where `.claude/skills/` doesn't exist or ASCENT conventions aren't in place. **Why it's tempting:** the skill "runs" on any project. **What to do instead:** onboard assumes ASCENT conventions. For non-ASCENT projects, the output will reference conventions that don't exist. Use it only in ASCENT-scaffolded projects.
