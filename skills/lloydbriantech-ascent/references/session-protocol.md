# session-protocol

> The session resumption protocol for ASCENT-scaffolded projects. [PRINCIPLES.md §15](../../../docs/framework/PRINCIPLES.md#15-session-resumption) is authoritative.

## The problem

A project's work spans sessions. Sessions end for reasons unrelated to the work — laptop reboots, conversation disconnects, end-of-day. When the next session begins, the developer faces a choice: re-explain everything from scratch, or rely on Claude to "remember" (which it can't — conversation context doesn't persist across sessions).

The result without a protocol: every new session pays an orientation tax. Context that was hard-won in session N must be re-derived in session N+1. Decisions that were explicitly made get re-litigated because no one recorded them durably. Blockers that were identified get re-discovered.

The session resumption protocol eliminates this class of waste by making prior state explicit, durable, and machine-readable.

## The two artifacts

### `docs/delivery/session-state.md` — transient working state

Captures what's in-flight right now: current focus, active decisions pending resolution, blockers, next actions. This file is **gitignored** — it's a working scratchpad, not a permanent record. Each `make session-snapshot` overwrites it with the current state.

Contents at snapshot time:

- **Current focus** — what the developer is working on (one sentence)
- **Active decisions** — questions being deliberated but not yet resolved
- **Blockers** — what's preventing progress and who/what can unblock
- **Next actions** — the immediate next steps when the session resumes
- **Phase context** — current phase, exit-criteria progress (references `.ascent-meta.json`)

This file is transient by design. It captures "where we are right now" — not "where we've been." When the current focus shifts, the old state is overwritten. Historical state belongs in `working-memory.md`.

### `docs/delivery/working-memory.md` — accumulating decisions

Captures decisions that have been made and should persist across sessions: architectural commitments, resolved design questions, patterns adopted, patterns rejected, lessons learned. This file is **git-tracked** — it's a durable record that grows over the project's lifetime.

Contents are append-only. Each entry has a date and a one-line summary:

```markdown
## Decisions

- 2026-05-16: Chose SQLite-WAL over Postgres for Phase 0 (see ADR-004)
- 2026-05-16: Backend layering uses four layers, not three (controllers separate from services)
- 2026-05-17: Session resumption protocol adopted per ASCENT §15

## Patterns adopted

- Structured JSON logging via pino (not console.log)
- Three-stage Dockerfile (builder + production + development)

## Patterns rejected

- Host-level npm install (Principle 1: container handles deps)
- npm ci in Dockerfiles (templates ship without lockfiles)
```

The distinction: `session-state.md` is "what's happening now" (volatile); `working-memory.md` is "what we've decided" (permanent).

## The four file states

When Claude reads these artifacts at session start, each file is in one of four states:

| State | Definition | Protocol response |
|---|---|---|
| **MISSING** | File does not exist | Proceed without prior state. Note the clean start: "No session state found — starting fresh." |
| **EMPTY** | File exists but contains no meaningful content | Same as MISSING. No prior state to resume from. |
| **STALE** | File's last-modified date is more than 7 days ago | Read the file but flag staleness: "Session state is from [date] — confirm this is still current before I act on it." |
| **FRESH** | File modified within the last 7 days | Read and resume: "Resuming from: [state summary]. Confirm or correct before we proceed." |

The 7-day staleness threshold is the default. Projects can adjust via `.ascent-meta.json` configuration (Phase 3 extension).

In all four states, Claude explicitly announces what it found (or didn't find). The framework refuses to silently assume context.

## Resumption protocol

When a new session begins in an ASCENT-scaffolded project, Claude executes these steps before responding to the user's first prompt:

1. **Read `.ascent-meta.json`** — confirm project identity, current phase, framework version. This is the same mode-detection step from [SKILL.md's routing logic](../SKILL.md#stage-1--mode-detection).

2. **Read `docs/delivery/session-state.md`** (if present) — load transient working state. Apply the four-state protocol above.

3. **Read `docs/delivery/working-memory.md`** (if present) — load accumulating decisions. Apply the four-state protocol above.

4. **Synthesize a resumption summary** — one paragraph stating: current focus (from session-state), key active decisions (from session-state), recent durable decisions (from working-memory), and the project's current phase (from .ascent-meta.json).

5. **Present the summary to the user** — "I'm resuming from: [summary]. Confirm or correct before we proceed." The user validates or adjusts before work begins.

6. **Proceed with the user's first prompt** — grounded in the validated state.

If both artifacts are MISSING or EMPTY, step 4 becomes: "No prior session state found. Starting fresh. What are we working on?"

## Capture discipline

State is captured by `make session-snapshot` — the primary mechanism in v0.3.1. The user explicitly decides when to capture.

**When to capture:**

- At end-of-session (the developer is about to close the conversation)
- Before a significant context switch (moving from one feature to another)
- After a significant decision is made (append to `working-memory.md`)
- Before a long break (end of day, weekend, vacation)

**What `make session-snapshot` does:**

1. Prompts Claude to summarize the current session state
2. Writes the summary to `docs/delivery/session-state.md` (overwrite)
3. Optionally appends new decisions to `docs/delivery/working-memory.md` (append)
4. Confirms the snapshot was written

**Phase 3 extensions** (not in v0.3.1):

- Automatic-on-commit: a git hook that prompts for a session-state update when committing
- Claude-judgment-based: Claude recognizes decision-moments during a session and proactively suggests "this decision should go in working-memory.md"
- `ascent-delivery-status` reads `session-state.md` to include "current focus" in its status synthesis
- `ascent-feature-intake` writes to `working-memory.md` when a feature's acceptance criteria are locked

## Verification

The user can verify that Claude is reading durable state (not confabulating) through two mechanisms:

**`make session-resume`** — displays the contents of both artifacts exactly as Claude would read them. The user sees what Claude sees, with no transformation.

**Source citations** — Claude's resumption summary (step 4 above) must cite the artifact it read. "Current focus: [from session-state.md]" and "Recent decision: [from working-memory.md, dated 2026-05-16]." If Claude cannot cite the artifact, it says "I don't have prior state for this" rather than guessing.

The framework's commitment: Claude never claims to know something from a prior session unless it can point to the line in `session-state.md` or `working-memory.md` where that information lives.

## Cross-references

- [PRINCIPLES.md §15](../../../docs/framework/PRINCIPLES.md#15-session-resumption) — the framework commitment this protocol operationalizes
- `docs/delivery/session-state.md` — transient state artifact (gitignored; overwritten each snapshot)
- `docs/delivery/working-memory.md` — accumulating decisions artifact (git-tracked; append-only)
- `make session-snapshot` — primary capture mechanism (writes session-state.md + archives to snapshots/)
- `make session-resume` — verification mechanism (classifies + displays both files)
- [ascent-delivery-status](../assets/template/.claude/skills/ascent-delivery-status/SKILL.md) — Phase 3 extension: reads session state into status synthesis
- [ascent-feature-intake](../assets/template/.claude/skills/ascent-feature-intake/SKILL.md) — Phase 3 extension: appends locked acceptance criteria to working-memory
