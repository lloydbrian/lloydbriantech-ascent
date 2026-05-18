---
name: ascent-delivery-status
description: >-
  Surfaces the current phase, outstanding work, exit-criteria progress,
  and recommended next actions for <<PROJECT_TITLE>>. The delivery-lead's
  at-a-glance view of where the project is and what's needed to close
  the current phase gate.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-delivery-status

Synthesizes <<PROJECT_TITLE>>'s delivery state: current phase, exit-criteria checklist progress, outstanding work items, blockers, and recommended next actions. This is the answer to "where are we and what's next?"

## When this skill engages

- Daily standup — "what's the project state?"
- Before a phase-gate review — "are we ready to close?"
- When the delivery-lead needs a status synthesis for stakeholders
- After a burst of work — "did that close anything?"

## Inputs

- `.ascent-meta.json` (phase field, current_focus)
- `CHANGELOG.md` (recent entries)
- `docs/delivery/PHASE-PLAN.md` (exit criteria, if present)
- `git log` (recent commit activity)

## Outputs

- Current phase name and number
- Exit-criteria checklist with DONE/PENDING status per item
- Outstanding work summary (what's left)
- Recommended next actions (ordered by impact)
- Blockers (if any identified from git stale branches or failing checks)

## Operational logic

The skill reads `.ascent-meta.json` for the current phase identifier, then locates the phase plan to extract exit criteria. Each criterion is checked against the project's current state — file existence checks, test-passing status, documentation presence. The output surfaces what's done, what's pending, and what action would close the most criteria. When [ascent-feature-intake](../ascent-feature-intake/SKILL.md) produces new work items, delivery-status will surface them as outstanding. Per §15 (session resumption), the skill also reads `docs/delivery/session-state.md` for the current focus and blockers, and `docs/delivery/working-memory.md` for accumulated decisions — incorporating both into the status synthesis so the "where are we?" answer includes session-level context, not just phase-level progress. The full decision tree for criteria-checking heuristics lands in Phase 3.

## Examples

Examples land in Phase 3. Each example will show a project at mid-phase with specific pending criteria, and the skill's recommended actions.

## Anti-patterns

The primary failure mode is **treating delivery-status as a monitoring dashboard rather than an action trigger**. The output should prompt a decision (close the phase, add work, unblock a dependency) — not just report state passively. If the output doesn't end with "→ do this next," the skill isn't earning its invocation.
