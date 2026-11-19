---
name: session-resume
description: >-
  Use when a session starts, or when asked "where did we leave off?",
  "resume", "what were we doing?", "what have we decided so far?", "are our
  session records in order?", or after a break, a context reset or a change
  of hands. Reads the project's working memory, session state and handoff,
  classifies each as missing, empty, stale or fresh, runs the session checks
  (SES-S1–S6: records present, decisions dated and in order, entries only
  appended from git history, the session state kept out of git, complete and
  fresh, the handoff current), and gives a resumption summary in which every
  claim is cited to the file and line it came from, for the person to
  confirm or correct before work starts. Read-only.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# session-resume

The entry point of `ascent-session`. It answers one question: what did earlier sessions decide and leave in progress, according to the records, not to memory?

Shared sources:
- [session-rules.md](../../references/session-rules.md): the three records, SES-S1–S6 and their limits
- [contract-template.yml](../../references/contract-template.yml): the `session:` section

## Rules

- **Read-only.** Never edit the records here; `session-capture` and `handoff` write them, after approval.
- **Cite or say "not recorded".** Every statement about an earlier session names the file and line it comes from. Never claim to remember anything the records do not hold, and never fill a gap with a guess.
- **The person confirms.** The summary ends with a request to confirm or correct it; work starts only after that.
- **Rate only with the severity table below.** A concern that matches no row goes under **Other observations (unrated)**: for example, a decision in the working memory that looks like it needs an ADR.
- **No secrets or personal data** in the summary. If a record holds a credential, say that it does and where, never the value.
- **Scripts.** The scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`. Quote every contract value you pass to a script.

## Severity

<!-- ses-severity:start -->
| Finding | Severity |
|---|---|
| No working memory, or one with no Decisions section (SES-S1) | Medium |
| A working-memory entry changed or removed after it was recorded (SES-S3) | Medium |
| The session state tracked by git, or not in .gitignore (SES-S4) | Medium |
| A decision with no date, or a date that is not real, is after today or is before the entry above it (SES-S2) | Low |
| A session state missing a section, holding a snapshot placeholder, with no capture date, or older than the contract allows (SES-S5) | Low |
| A handoff missing a section or its date, older than the newest decision, or missing when the contract requires one (SES-S6) | Low |
| A session value missing from the contract ("unmeasured") | Low |
<!-- ses-severity:end -->

**Rating:** strong: no Medium. moderate: one or two Medium. weak: three or more Medium, or no session records at all (SES-S1).

## Steps

### Step 0 — Load the contract

Read `.ascent/contract.yml` (or `.claude/contract.yml`): `session.memory`, `state`, `handoff`, `state_max_age_days`, `handoff_required`, `memory_since` and `maturity_target`. If the section is missing, use the defaults in the contract template and say so; propose the section once, marking guessed values `# guess`.

### Step 1 — Run the checks

```bash
bash "$PLUGIN_ROOT/scripts/check-session.sh" --memory '<session.memory>' --state '<session.state>' --handoff '<session.handoff>' --max-age '<session.state_max_age_days>' --maturity '<maturity_target>' [--since '<session.memory_since>'] [--require-handoff] .
```

Leave out an option whose value the contract does not set; pass `--require-handoff` only when `handoff_required` is true. Exit 2 is bad input: fix the arguments, never rate it.

For each SES-S3 failure, read `git log -p -- <memory>` around the commit it names and say in one sentence what was changed or dropped. Never propose `memory_since` on your own: a person decides that a rewrite is accepted.

### Step 2 — Classify and read the records

Classify each record as **missing**, **empty** (no entry, or only placeholders), **stale** (session state captured, or handoff generated, before the contract's window) or **fresh**. Read the fresh and stale ones in full. A stale record is read but every statement from it is prefixed "last recorded <date>:".

### Step 3 — Read what the records point to

Follow what the records name, and only that: an ADR a decision cites, the branch and commit in Phase context (`git log -1 <commit>` to confirm it exists), and the README's "getting started" when the handoff points to it. Note where a record contradicts the repository, for example a branch that no longer exists; those go under **Other observations (unrated)**.

### Step 4 — Summarize and ask

```
## Resuming — <strong | moderate | weak> records
Records: working memory <state> · session state <state, captured date> · handoff <state, generated date>

Current focus: <...> (session-state.md:L)
Active decisions: <...> (session-state.md:L)
Blockers: <... or "none recorded"> (session-state.md:L)
Next actions: <...> (session-state.md:L)
Recent decisions: <the five newest, each with its date> (working-memory.md:L)

| Rule | Severity | Evidence | Failure scenario | Fix |
|---|---|---|---|---|
N/A: <rule — why>
Other observations (unrated)

Confirm or correct this before we start.
```

With no records at all, say "No session records found: starting fresh. What are we working on?" and recommend `session-capture` at the end of the session. The checks prove that the records are kept, not that they are accurate: end the report with that sentence.
