---
name: handoff
description: >-
  Use when work changes hands, before a holiday or a leave, when someone new
  joins, or when asked to "write a handoff", "prepare a handover", "onboard
  the next developer to this work", or "what does the next person need to
  know?". Builds a handoff from the project's records, not from memory: where
  to start, the project's state (focus, open questions, blockers, next
  actions, recent decisions, recent activity from git) and its conventions
  (how to build, test and release, and the rules the team keeps), every item
  cited to its source; shows it and writes it only after approval. Never
  commits.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# handoff

Writes the one page someone needs to pick up this work without asking the person who left: where to start, where things stand, and how the team works.

Shared sources:
- [session-rules.md](../../references/session-rules.md): the handoff's sections and date line, and SES-S6
- [contract-template.yml](../../references/contract-template.yml): `session.handoff`, `memory`, `state`

## Rules

- **Write only after approval, and only the handoff file.** Any other path is a failure of this skill. Never commit.
- **From the records, cited.** Every item names its source: a record and line, a README section, a contract key, an ADR, or a commit. Anything with no source is left out or marked "not recorded"; never fill a gap from memory.
- **For a newcomer.** Write for someone who knows the stack but not this project: no shorthand the records do not explain, links instead of copies.
- **No secrets or personal data.** Name where a credential is kept (a secret store, an environment variable), never its value. Name roles, not people, unless the records name an owner.

## Steps

### Step 0 — Load the contract

Read `.ascent/contract.yml` (or `.claude/contract.yml`) for `session.handoff`, `memory` and `state`; use the template's defaults when unset.

### Step 1 — Read the records

Run session-resume Step 1 and Step 2. A stale session state is used, with its date stated; a missing one leaves the state section to the person (Step 4).

### Step 2 — Read the project

Read the README's setup and usage sections, the operator entry point (the Makefile's targets, `package.json` scripts, or the equivalent; read them, never run them), the contract's sections, and the ten most recent accepted ADRs' titles. Run `git log --since='30 days ago' --format='%h %ad %s' --date=short` for recent activity.

### Step 3 — Draft

```
# Handoff — <project>

Generated: <YYYY-MM-DD>

## Where to start
<the three things to read first, in order, with links>

## Project state
<focus, open questions, blockers and next actions; the five newest decisions; recent activity; each cited>

## Project conventions
<how to build, test and release; the rules the team keeps, from the working memory's patterns, the ADRs and the contract; each cited>
```

### Step 4 — Ask

Ask the person for what the records do not hold: anything in flight that is not written down, who to ask about what, and what they would warn a newcomer about. Add their answers, marked "from <role>, <date>".

### Step 5 — Write and check

After confirmation only, write the handoff. Then run session-resume Step 1: SES-S6 must pass. Say: "Handoff written to <path>. Nothing is committed."
