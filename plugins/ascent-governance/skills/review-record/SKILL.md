---
name: review-record
description: >-
  Use when asked "record this review", "log the security review we just ran",
  "add the review to the review log", "the UX review is done, note it", or
  right after a review skill gives its rating and the operator wants it to
  count toward a launch. Appends one dated row to the project's review log:
  the review's name, the commit it read, its rating (strong, moderate or
  weak), its High, Medium and Low counts, the rule ids of its open High
  findings, and who asked for it. Refuses without a rating and a commit, never
  changes or removes an earlier row, and shows the row for approval before it
  writes. Writes only the review log; never commits.
version: 0.2.1
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# review-record

Puts a review that needed judgement on record, so `check-audit.sh` can tell that it happened, when, on which commit and how it came out.

Shared sources:
- [governance-rules.md](../../references/governance-rules.md): the review log's columns, the reviews it knows and how a rating is derived
- [contract-template.yml](../../references/contract-template.yml): `governance.review_log`

## Rules

- **Write only after approval, and only the review log.** One new row for one review. Any other path is a failure of this skill. Never commit.
- **Never change or remove a row.** A review that was run again is a new row; the old row stays, so the log shows when the rating changed. A mistake in an earlier row is corrected by a new row, never by an edit.
- **Record what the review said.** The rating, the counts and the open High rule ids come from the review's own output in this session, or from a report the operator points to. Never record a review that was not run, never round a rating up, and never leave out an open High finding.
- **Refuse without a rating and a commit.** No rating, or no commit to name, means nothing is written: say what is missing.
- **No secrets or personal data.** "Asked by" is a name or handle the operator gives; nothing else about a person goes in the log.

## Steps

### Step 0 — Load the contract and the log

Read `.ascent/contract.yml` (or `.claude/contract.yml`) for `governance.review_log` (default `docs/governance/review-log.md`) and the floors, so the review's name is the one a floor uses. Read the log if it exists.

### Step 1 — Collect the row

- **Date:** today, `YYYY-MM-DD`.
- **Review:** the skill's name as the floor writes it (`sec-posture`, `ux-review`, `architecture-review`, `ops-review`, `quality-review`, or any name the project's floors use).
- **Commit:** the commit the review read: `git log -1 --format=%h`. If files the review read have uncommitted changes, say so and ask whether to record now, against the last commit, or after the operator commits.
- **Rating:** the review's own `strong`, `moderate` or `weak`. For a review that gives no rating, derive it as governance-rules.md says: `weak` with any High finding, `moderate` with any Medium, else `strong`.
- **High, Medium, Low:** the counts of findings at each severity. Count a finding once.
- **Open High rules:** the rule id of every High finding that is still open, one id for each finding, separated by spaces (`SEC-L4 UX-F2`; `SEC-L4 SEC-L4` when two findings break the same rule), or `-` when there is none. A High count above the number of ids blocks a launch (GOV-R2): a finding with no id is one no waiver was ever held against. A High finding with no rule id still gets a name, so that it blocks until it is fixed and can be waived only on purpose: the review's name and two or three words of the finding, in capitals, joined by hyphens (`ARCHITECTURE-REVIEW-NO-BACKUP`). Reuse the name an earlier row or a waiver already gives that finding.
- **Asked by:** the operator's name or handle, as they give it.

### Step 2 — Preview

Show the exact row, and say whether the log will be created. Say what the row will mean for a launch: a `weak` rating is a condition, and each open High rule blocks a launch until it is fixed or waived by an accepted ADR.

### Step 3 — After confirmation only

If the log does not exist, create it with the heading, one sentence and the header row from governance-rules.md. Append the row as the last row of the table, directly under the row above it, with no blank line between. Keep the log to that one table: every table row below its header is read as a review row. Re-read the file and confirm every earlier line is unchanged.

### Step 4 — Check and report

Run governance-review Step 1 for the lowest environment whose floor names this review and report its GOV-R lines. Say: "Recorded <review> as <rating> at <commit>. Nothing is committed."

## Output

```
## Review recorded — <review>: <strong | moderate | weak>
Row: <the row>
Log: <path> (created | N rows before, N+1 now; earlier rows unchanged)
For a launch: <current for N days on <environment> | blocks: <open High rules> | condition: rated weak>
Recommended next: <launch-readiness when a launch is planned; the fix for each open High rule, by plugin; ascent-adr:adr-write to waive one on purpose>
```

Also name any plugin in `references/plugin-signals.md` whose signal this repository shows and whose skills are not available in this session, with its reason. The file is [plugin-signals.md](../../references/plugin-signals.md).
