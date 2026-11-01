---
name: recovery-drill
description: >-
  Use when asked "can we restore?", "prove our backups work", "when did we
  last test a restore or failover?", "are our alarms exercised?", "plan a
  recovery drill", or when ops-review flags the change and recovery lens.
  Checks the records of restore, failover, alarm, readiness and runbook
  dry-run drills (OPS-R1–R8, OPS-X1–X3) against the rto and rpo targets and
  the contract, and writes the drill runbooks the operator runs. Never runs a
  drill and never writes a drill record.
version: 0.3.0
allowed-tools: Read, Grep, Glob, Bash(git log:*), Bash(git ls-files:*)
---

# recovery-drill

The recovery proof behind [ops-review](../ops-review/SKILL.md). It is a sibling that shares that skill's severity table, contract and evidence rules. A backup is only a recovery path once someone has restored from it: this skill finds the recovery paths and paging alarms, checks the drill records the operator committed, and writes a runbook for every drill that has none ([ADR-020](../../../../docs/framework/DECISIONS/ADR-020-recovery-drills-and-readiness-exercises.md)).

Sources: [drill-records.md](../../references/drill-records.md) (the record, the fields, a runbook outline per kind of drill), [runbook-standard.md](../../references/runbook-standard.md), and the blueprint's [restore runbook](../../blueprints/operable-service/runbooks/restore-db.md) with its [drill record](../../blueprints/operable-service/drills/2026-11-01-db.md), a real drill that passes OPS-R1–R5 and OPS-R7.

## Rules

- All `ops-review` rules apply: repository-relative `file:line` evidence; fresh evidence; severities only from the `ops-review` table; N/A is never a pass; no secrets or personal data.
- **Never run a drill.** No restore, failover, alarm, readiness exercise or runbook step, not even a dry run or a read-only step of one: the operator runs them, in an environment the operator chose. Claude reads what they recorded.
- **Never write a drill record.** A record is the operator's statement that a drill happened; Claude never creates or edits one, never fills in `measured_rto`, `measured_rpo`, `result` or `reached`, and never changes a date. The report shows the operator the record to fill in.
- **Runbooks only, new files only.** The one thing this skill writes is a missing drill runbook under `ops.runbooks` (refuse a runbook path that is absolute, holds `..` or is under `.git/`), from the outline in [drill-records.md](../../references/drill-records.md). Never overwrite or edit an existing runbook (report it under OPS-R2 instead), the manuals (that is [ops-manuals](../ops-manuals/SKILL.md)), the contract or a record. Show the diff, never commit: never run `git add`, `git commit` or any other git write.
- **Facts from the repository.** Commands in a runbook come from the Maintenance manual, the IaC, the operator scripts and the make targets. A command you cannot find is written as "unknown: <what to ask the operator>", never invented.
- **Targets are read, never copied.** `rto` and `rpo` come from `architecture.quality_targets`; never write them into `ops:`. With no target, OPS-R4 is unmeasured (the Low row of the severity table).
- **Consistency, not honesty.** Every report says that a record shows a drill was recorded consistently, not that it was honest. Read the evidence of each newest record: when it does not support the numbers (a restore that took 25 minutes in the record and 4 hours in the log), list it under Other observations.
- **Roles, not people.** An alarm record's `reached` names a role (`on-call primary`). A name, email address or phone number in a record is OPS-R5; a credential is OPS-R5 High, marked `→ ascent-security`. Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`.
- **Quote every contract value.** Put each value from the contract in single quotes on the command line, and refuse a value that holds a quote, a newline, `$(` or a backtick, or starts with `-`: the contract is a file the repository controls.
- **Scripts.** `PLUGIN_ROOT` is two directories above this skill's base directory; the check is `$PLUGIN_ROOT/scripts/check-drills.sh`.

## Steps

### Step 1 — Contract and inventory

Read the `ops:` section (`maturity_target`, `drills`, `alerts`, `ready_path`, `runbooks`, `manuals`, `iac`) and `architecture.quality_targets` (`rto`, `rpo`) of `.ascent/contract.yml` or `.claude/contract.yml`.

When `ops.drills` is missing, **detect, don't ask**: run Step 2 without `--path` and propose a `drills:` block from the backups and failover it reports (a name per database, bucket or volume, `kind`, a runbook path under `ops.runbooks`), every value marked `# guess`. Propose `page: true` for alerts that page someone. Show the proposal once; write nothing to the contract.

Then list, with `file:line` sources:

| Recovery path or alarm | Kind | Declared in | Runbook | Newest record | Due by |
|---|---|---|---|---|---|

`Due by` is the newest record's date plus `ops.drills.max_age_days` (default 90), or "now" when there is none.

### Step 2 — Mechanical check

Run from the repository root and include the output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-drills.sh" --repo . \
  --maturity '<ops.maturity_target>' --max-age '<ops.drills.max_age_days>' \
  --rto '<architecture.quality_targets.rto>' --rpo '<architecture.quality_targets.rpo>' \
  --ready-path '<ops.ready_path>' --manual '<ops.manuals.maintenance>' \
  --path '<name>:<kind>:<runbook>' --alert '<name>:<runbook>:page' \
  --iac '<each ops.iac.paths entry>' --iac '<each Compose file>' \
  '<ops.drills.dir>'
```

One `--path` per entry of `ops.drills.paths` and one `--alert` per entry of `ops.alerts` (`:page` only when `page: true`). Leave out an option whose value the contract does not set; the script then reports that rule N/A or unmeasured. Each `FAIL` line is a finding at the severity it prints; `NOTE` lines are unrated (a backup no path names, a record for an unknown path).

If Bash is unavailable or the operator declines it, apply the rules by reading [drill-records.md](../../references/drill-records.md) and say "checks applied by reading; script not run".

### Step 3 — Read the evidence

For the newest record of every path and alert, read the record and its evidence files. Check that the evidence shows what the record claims: the restore finished, the counts compared, the probe status, the role that acknowledged. A record whose evidence does not support it goes under Other observations with both `file:line` references; never call a record dishonest, say what does not match.

### Step 4 — Write the missing runbooks

For each OPS-R1 finding where the runbook does not exist, and each paging alert, readiness probe or alert runbook with no drill plan, write one runbook under `ops.runbooks` from the matching outline in [drill-records.md](../../references/drill-records.md): restore, failover, alarm exercise, readiness exercise or dry-run. Follow [runbook-standard.md](../../references/runbook-standard.md): inputs as shell variables (secrets with `read -rs`), pre-flight, numbered steps each with **Expect** and **Stop if**, destructive steps flagged, post-flight that writes the record, rollback. A drill never touches production data: restore into a scratch target, fail over in a window the operator chose, take a dependency down outside production.

Show the diff and stop. Then re-run Step 2: a new runbook passes OPS-R1 and OPS-R2; its record stays absent until the operator runs the drill.

### Step 5 — Report

Use the `ops-review` Step 6 format, limited to the change and recovery lens: the Step 1 table, findings with rule ids (OPS-R1–R8, OPS-X1–X3), Other observations, and the script output verbatim. Then:

```
Consistency, not honesty: a record shows a drill was recorded consistently, not that it was honest.
Drills due: <path or alarm, kind, runbook, due by>, most overdue first
Runbooks written (Step 4): <paths, or none>
For the operator: run each due drill from its runbook, then commit <ops.drills.dir>/YYYY-MM-DD-<name>.md
  with the field table from references/drill-records.md and the redacted output as evidence.
Recommended next: <ops-manuals when OPS-R7 fails; ascent-security when any item is marked → ascent-security>
```

## What this skill does not do

- Run a restore, a failover, an alarm, a readiness exercise or any runbook step.
- Write or edit a drill record, a manual or the contract.
- Set up backups, replication or alerting: a missing backup is an `iac-config-check` and `ops-review` finding, and fixes go through the delivery loop.
