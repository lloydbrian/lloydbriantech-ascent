---
name: session-capture
description: >-
  Use when closing a session, before a context switch or a long break, or
  when asked to "capture the session", "save where we are", "snapshot the
  session", "record what we decided", or "update the working memory". Asks
  for the current focus, the open questions, the blockers and the next
  actions, and for the decisions made this session that the next one should
  not re-litigate; shows the new session state and the dated entries to be
  appended, and writes them only after approval: the session state is
  overwritten, the working memory is only ever appended to. Suggests an ADR
  for a decision that constrains the architecture. Never commits.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# session-capture

Writes down where the session stands and what it decided, so the next session, by anyone, starts from the record rather than from memory.

Shared sources:
- [session-rules.md](../../references/session-rules.md): the records' formats and why the working memory is only appended
- [contract-template.yml](../../references/contract-template.yml): `session.memory`, `state`

## Rules

- **Write only after approval, and only these files:** the session state (overwritten) and the working memory (new entries appended under their section; created with its three sections if missing). Any other path is a failure of this skill. Never commit.
- **Never change or remove a working-memory entry.** A changed decision is a new dated entry that names what it replaces ("replaces the 2026-10-02 entry"). The old entry stays.
- **The person's words.** Record what the person says, made concise; never invent a decision, a blocker or a next action. Mark anything you inferred from the session as a question in the preview.
- **Decisions, not activity.** An entry is something the next session should not re-litigate: a choice, a rule, a pattern adopted or rejected. "Worked on pagination" is session state, not a decision.
- **No secrets or personal data** in either record.

## Steps

### Step 0 — Load the contract

Read `.ascent/contract.yml` (or `.claude/contract.yml`) for `session.memory` and `session.state`; use the template's defaults when unset. Check that the session state is in `.gitignore` (`git ls-files -- <state>` must print nothing). If it is tracked or not ignored, say so first: writing it would publish one person's state to everyone (SES-S4), and the fix is the operator's.

### Step 1 — Read the current records

Read both records if they exist. Note the newest date in each section of the working memory, so new entries are appended in date order.

### Step 2 — Ask for the session state

Ask, one at a time, offering what the session suggests for the person to confirm: the current focus (one sentence), the active decisions (open questions), the blockers (with who or what unblocks them), and the next actions. Phase context comes from the repository: the branch and short commit from `git log -1 --format='%h %D'`.

### Step 3 — Ask for decisions

Ask: "What did we decide this session that the next one should not re-litigate?" Propose candidates from the session, each as one line; the person keeps, edits or drops each. For a pattern, ask whether it was adopted or rejected. For a decision that constrains the architecture (a technology, a boundary, a data model), suggest `ascent-adr:adr-write` as well, and cite the ADR in the entry once it exists.

### Step 4 — Preview

Show the complete new session state, with `Captured: <YYYY-MM-DD-HHMM>` and the four sections, and the exact lines to be appended under each working-memory section, each starting `- <today>: `. Say which entries replace an older one.

### Step 5 — After confirmation only

Write the session state, then append the entries. Re-read both files and confirm that every line of the earlier working memory is unchanged.

### Step 6 — Check and report

Run session-resume Step 1 and report its result. A SES-S4 failure is reported again with the fix for the operator: `git rm --cached <state>` and a `.gitignore` line. Say: "Session state captured. Working memory: N new entries | unchanged. Nothing is committed."
