---
name: onboard
description: >-
  Use when someone new joins, or when asked "I'm new here, where do I
  start?", "walk me through this repository", "onboard me as a developer
  (or operator, or contributor)", "what should I read first?", or "how do I
  get this running?". Walks one persona's path through the repository's own
  documents: where to start, what to read in order, how to build, test and
  run the project, where the decisions and conventions are, and who to ask,
  citing the document and line for every step; checks the path for broken
  links and missing pages on the way and reports the gaps it hit. Read-only.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# onboard

A guided first hour in a repository, built from the repository's own documents, for one reader. It shows the newcomer the way in, and shows the team where that way breaks.

Shared sources:
- [docs-rules.md](../../references/docs-rules.md): personas, entry points and the click limit
- [contract-template.yml](../../references/contract-template.yml): `docs.personas`, `max_clicks`

## Rules

- **Read-only.** Never edit a document, and never run the project's commands: show them, with where they are documented, for the newcomer to run.
- **From the documents, cited.** Every step names the document and line it comes from. Where the documents are silent, say "not documented" and add it to the gaps; never fill it from general knowledge without saying so.
- **One persona at a time,** and only what that persona needs in the first hour.
- **No secrets or personal data.** Name where a credential comes from, never its value.

## Steps

### Step 0 — Who is onboarding

Ask which persona, or match the person's description to `docs.personas` from the contract (docs-review Step 0). With no personas in the contract, use Developer and say so.

### Step 1 — Check the path

Run docs-review Step 2 and keep only what affects this persona's path: broken links (DOC-L1, L2) and drift (DOC-R1–R6) in the README, the entry point and the pages they link to, and DOC-P1, P2 and P4 for the entry point.

### Step 2 — Walk it

Starting from the persona's entry point (or the README), follow the links a newcomer would, at most `docs.max_clicks` deep. Collect, with citations: what the project is (one paragraph), the first three things to read, how to set up, build, test and run it (the exact commands, from the documents), where decisions and conventions are recorded (ADRs, a working memory, CONTRIBUTING), and who to ask.

### Step 3 — Present

```
## Onboarding — <persona>
What this is: <...> (README.md:L)
Read first: 1. <page> — <why> (link) · 2. ... · 3. ...
Get it running: <commands, each cited>
How the team works: <conventions and where decisions live, cited>
Ask: <roles or channels, cited, or "not documented">

Gaps on this path
| Rule or gap | Evidence | What the newcomer hits |
```

### Step 4 — Recommend

For each gap, recommend the skill that closes it: doc-drift for a stale command, doc-stub for a missing page, docs-review for a full review. End with: "This walkthrough cites the documents as they are; it does not check that they are right."
