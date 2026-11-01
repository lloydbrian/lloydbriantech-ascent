# ADR-020: Recovery drills and readiness exercises: OPS-R1–R8 and OPS-X1–X3, proven by records the operator writes

**Status:** Accepted
**Date:** 2026-11-01 (America/New_York)
**Decider:** lloydbriantech

## Context

[ADR-014](ADR-014-testing-ownership-and-dependency-scan.md) decision 4 put restore, failover and readiness proof in `ascent-ops` 0.3.0: a `recovery-drill` skill and `check-drills.sh`, the `OPS-R1`–`R8` and `OPS-X1`–`X3` families, operator-run drills with dated records, and targets read from `architecture.quality_targets`. [ADR-017](ADR-017-faster-negative-controls.md) moved it to v0.4.12. ADR-014 named the rules but left these questions to the build:

- **What is a drill record, and where does it live?** The check needs a format a script can read and a reviewer can read in a pull request.
- **Where do the recovery paths and paging alarms come from?** IaC declares backups and alarms, but not every backup is a recovery path, and some recovery paths (a dump on a host) have no IaC.
- **How severe is each gap?** ADR-014 decision 5 makes every gap the maturity target requires Low unless waived. A drill that missed its target, or a credential pasted into the evidence, is not a gap; it is a defect in what exists.
- **Which file path does a rule read?** Building this release found that `check-iac-config.sh` classified Compose files for OPS-S8, and Terraform files as per-environment, by words in the absolute path. A repository cloned under a folder such as `~/Developer/` never got OPS-S8, because "dev" in the parent path marked every Compose file as non-production. A random temporary directory name made the same test fail in CI once.

## Decision

1. **A proof is a record the operator writes after a drill the operator runs.** Claude never runs a restore, a failover, an alarm or a readiness exercise, and never writes or edits a drill record: a record is the operator's statement that the drill happened. `recovery-drill` writes only missing drill runbooks (following [runbook-standard.md](../../../plugins/ascent-ops/references/runbook-standard.md)), as new files, and shows the operator the record to fill in. `check-drills.sh` proves a drill was recorded consistently, not that it was honest, and its output says so on every run.
2. **One Markdown file per drill**, `<ops.drills.dir>/YYYY-MM-DD-<name>.md` (default `docs/operations/drills/`). It opens with a two-column `| Field | Value |` table, then free notes. Fields: `path`, `kind` (`restore`, `failover`, `alarm`, `readiness`, `dry-run`), `date`, `result` (`pass` or `fail`), `measured_rto` and `measured_rpo` (restore and failover), `evidence` (repository-relative files), `follow_up` (an issue link, required when the result is `fail`), `runbook` (the runbook followed or dry-run), `reached` (alarm: the role that answered, never a name), `probe` and `probe_status` (readiness). The format is in [drill-records.md](../../../plugins/ascent-ops/references/drill-records.md).
3. **The contract is the source of truth; the IaC proposes.** `ops.drills.paths` lists every backup and recovery path (`name`, `kind` restore or failover, `runbook`), and `ops.alerts[].page: true` marks a paging alarm. `rto` and `rpo` are read from `architecture.quality_targets` and never copied. `check-drills.sh --iac` finds backups (retention, point-in-time recovery, backup plans, versioning, database volumes in Compose) and failover (Multi-AZ, Route 53 failover records, global tables and clusters, read replicas). A backup the contract does not list is a NOTE, so the skill can propose it; failover the contract does not drill is OPS-R8.
4. **Eleven rules, rated only from the `ops-severity` table:**

   | Rule | Severity | Rule |
   |---|---|---|
   | OPS-R1 | Medium | every recovery path in the contract has a runbook that exists; Low when the IaC declares backups and the contract lists no path (unmeasured) |
   | OPS-R2 | Medium | each drill runbook has pre-flight, post-flight and rollback sections and steps with Expect and Stop if |
   | OPS-R3 | Medium | each path has a passing record of its kind no older than `ops.drills.max_age_days` (default 90); Low for a record without the required fields, with an unknown kind or result, or dated otherwise than its name |
   | OPS-R4 | Medium | the newest current passing record's `measured_rto` ≤ `rto` and `measured_rpo` ≤ `rpo` |
   | OPS-R5 | High | no credential-like value in a record or its evidence (`key=value` before a command, `key: value`, JSON, a table row, a password in a URL, a bearer token, an access key, a private key); Medium for evidence that is missing or outside the repository, and for an email address or phone number. No record value that is not plain text is ever printed |
   | OPS-R6 | Medium | a failed drill has a `follow_up`, or a later passing record of the same path and kind |
   | OPS-R7 | Low | the Maintenance manual's Backup and restore section names a restore date no older than the newest passing restore record |
   | OPS-R8 | Low | failover the IaC declares has a failover path in the contract (its record is then OPS-R3) |
   | OPS-X1 | Low | every paging alarm has a fresh passing alarm record that names the role it reached |
   | OPS-X2 | Low | a fresh passing readiness record shows the probe at `ops.ready_path` returning a non-2xx status with a dependency down |
   | OPS-X3 | Low | every runbook an alert links to has a fresh passing dry-run record |

   Missing evidence of the secondary exercises is the maturity gap ADR-014 decision 5 makes Low (R7, R8, X1–X3). A recovery path with no current passing drill is Medium: a backup is only a recovery path once it has been restored, and rating it Low would let a team that never drills rate better than one that drills with a missing evidence file. A defect in what exists is rated as the existing table rates its kind: a credential is High as in OPS-M8, a runbook without pre-flight and post-flight is Medium as in the runbook standard, and a drill that missed its target, or failed with no follow-up, is Medium because the recovery is shown not to work. A fresh failed drill does not make an old pass current.
5. **Maturity.** `check-drills.sh --maturity` follows `ops.maturity_target`: prototype requires none of the rules, standard requires OPS-R1–R5, enterprise all eleven. OPS-R5's credential check runs at every level, because a leaked credential is never a maturity question.
6. **Durations and dates.** Durations are written as `<n>d`, `<n>h`, `<n>m` and `<n>s`, combined (`1h30m`). A target that does not parse is bad input (exit 2); a measurement that does not parse is an OPS-R4 failure, never a silent pass. A date must be a real calendar day; a date later than today in the manual is a plan, not a restore.
7. **Classify files by the path the operator named, never by the folders above it.** `check-iac-config.sh` matches OPS-S8's production words and the per-environment directories (`environments/`, `envs/`, `env/`, `stages/`, `live/`) against the path from the scan argument down: a relative argument counts as typed (`deploy/prod`), an absolute one from its own folder name. Test-code exclusions keep reading the path below the argument. `ascent-ops` 0.3.0 ships the fix.
8. **Registry.** `OPS-R` and `OPS-X` leave Reserved and become families of `check-drills.sh`; `recovery-drill` and the script are registered components; the restore and failover, and operational readiness exercises domains become released. PILLARS moves restore and failover proof from Gap to Strong and recoverability from Partial to Strong, and adds an operational readiness row (OPS-X1–X3), Strong from the operator's records.

## Alternatives considered

- **Claude runs the drill in a sandbox.** Rejected. A restore needs the project's credentials and changes state; ADR-014 decision 1 gives anything live to the operator.
- **Claude writes a blank record for the operator to fill in.** Rejected. A record Claude created, even blank, blurs who stated that the drill happened. The skill shows the record in its report; the operator creates the file.
- **YAML records.** Rejected. A second format beside Markdown runbooks and manuals; the field table reads the same in a pull request and parses with awk.
- **One drill log table.** Rejected. Evidence and notes do not fit a row, and a record per drill keeps the history in git.
- **Recovery paths from the IaC alone.** Rejected. Not every backup is a recovery path, and dumps on a host have no IaC. Detected backups are proposed, not required.
- **Every rule Low, as ADR-014 decision 5 reads literally.** Rejected. A drill that missed its RTO, or a credential in its evidence, would rate the same as a drill not yet run.
- **Parse the runbook steps exactly.** Rejected. `runbook-check` reads runbooks against the standard; OPS-R2 checks only the parts a drill cannot do without.

## Consequences

- A project gets recovery evidence it can show an auditor: a dated record per path, checked against its own targets.
- A record proves consistency, not honesty. A team can write a passing record without a drill; the evidence files and the reviewer's reading are the guard, and the output says so.
- `ops-review` reads the Change and recovery lens through `check-drills.sh` and recommends `recovery-drill`; the `ops-reviewer` agent applies the rules by reading.
- OPS-S8 now reports production Compose files in repositories under folders such as `~/Developer/`. Projects there may see new Medium findings that were always true.
- **(uncertain)** Paging alarms outside the IaC (a vendor's console) are known only through the contract.

## Cost implications

- About 800 plugin lines, 400 test lines and 28 negative controls (ADR-014's estimate). Actual: about 730 lines of scripts, skill and reference, 240 of blueprint runbooks and drill, 600 of tests and fixtures, and 58 negative controls (54 in `ascent-ops-drills`, 4 for the `OPS-S8` fix); the review roughly doubled the controls.
- **CI:** one new mutant group, `ascent-ops-drills`, inside the 15-minute job limit.
- **Recurring:** keep the backup and failover patterns current as IaC providers change.
- **Runtime:** bash and awk. Nothing is installed or run; the blueprint drill in the trial ran in a local container.
