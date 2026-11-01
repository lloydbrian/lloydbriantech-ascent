# Drill records and drill runbooks

A recovery path is proven by a drill the operator runs and a record the operator commits. `check-drills.sh` (OPS-R1–R8, OPS-X1–X3) reads the records; `recovery-drill` writes missing drill runbooks. Claude never runs a restore, a failover, an alarm or a readiness exercise, and never writes a record ([ADR-020](../../../docs/framework/DECISIONS/ADR-020-recovery-drills-and-readiness-exercises.md)).

A record shows that a drill was recorded consistently. It does not show that it was honest: the evidence files and the reviewer's reading are the guard.

## The record

One Markdown file per drill in `ops.drills.dir` (default `docs/operations/drills/`), named `YYYY-MM-DD-<name>.md` with the drill's date. Other files in the folder (a README, an `evidence/` folder) are not records. The file opens with a two-column table; notes follow.

```markdown
# Drill: orders-db restore

| Field | Value |
|---|---|
| path | orders-db |
| kind | restore |
| date | 2026-11-12 |
| result | pass |
| measured_rto | 38m |
| measured_rpo | 6h |
| evidence | docs/operations/drills/evidence/2026-11-12-orders-db.txt |
| follow_up | — |
| runbook | docs/operations/runbooks/restore-orders-db.md |

## Notes

Restored the 02:00 UTC dump into a scratch instance; row counts matched production at the dump time.
```

| Field | Kinds | Value |
|---|---|---|
| `path` | all | the recovery path's `name` in `ops.drills.paths`; for an alarm, the alert's `name` in `ops.alerts`; for readiness, the dependency taken down; for a dry-run, the alert or runbook name |
| `kind` | all | `restore`, `failover`, `alarm`, `readiness` or `dry-run` |
| `date` | all | `YYYY-MM-DD`, the same as the file name |
| `result` | all | `pass` or `fail`. A drill that missed its target is still `pass` if the service came back; OPS-R4 compares the measurements |
| `measured_rto` | restore, failover | the time from the start of the recovery to the service answering readiness |
| `measured_rpo` | restore, failover | the age of the newest data the recovery brought back, at the time of the incident simulated |
| `evidence` | all | repository-relative files, comma-separated: command output, timings, screenshots. Never absolute paths or links outside the repository |
| `follow_up` | all | required when `result` is `fail`: an issue link, or the date of the planned re-run. `—` otherwise |
| `runbook` | restore, failover, dry-run | the runbook followed; for a dry-run, the runbook read through (OPS-X3 matches it to `ops.alerts[].runbook`) |
| `reached` | alarm | the **role** that answered the page (`on-call primary`), never a name, email or phone number |
| `probe` | readiness | the path probed, `ops.ready_path` (a full URL ending in it is accepted) |
| `probe_status` | readiness | the HTTP status the probe returned with the dependency down; it must not be 2xx |

Durations are `<n>d`, `<n>h`, `<n>m` and `<n>s`, combined without spaces (`1h30m`); `0` is zero. The targets come from `architecture.quality_targets.rto` and `rpo`, written the same way.

**What a record must never hold:** credentials, tokens, connection strings with passwords, account ids, names, email addresses or phone numbers. A credential is OPS-R5 High at every maturity level.

Redact command output before committing it. This first pass works the same with the `perl` on macOS and Linux (`sed`'s case-insensitive flag does not); it masks `key=value` and `key: value` pairs, passwords in URLs and bearer or basic tokens:

```bash
perl -pe 's/((?:password|passwd|passphrase|secret|token|api_?key|access_key|private_key)"?\s*[=:]\s*"?)[^\s",}]+/$1***/gi; s{(://[^/:@\s]+:)[^@\s]+@}{$1***\@}g; s/((?:Bearer|Basic)\s+)\S+/$1***/gi' raw-output.txt > docs/operations/drills/evidence/<record>.txt
```

It does not know every secret your output may hold. Before committing, run `check-drills.sh` (OPS-R5) and read the file yourself.

## Freshness

A record counts for `ops.drills.max_age_days` (default 90), and only a passing one makes a recovery path current (OPS-R3): a fresh failed drill does not make an old pass current. Enterprise runs every drill at least once a quarter. Standard runs the recovery-path checks (OPS-R1–R5) for restore and failover paths alike; alarm, readiness and dry-run exercises (OPS-X1–X3) are enterprise only.

## Drill runbooks

Every drill runbook follows [runbook-standard.md](runbook-standard.md): inputs as shell variables (secrets with `read -rs`), pre-flight, numbered steps each with **Expect** and **Stop if**, destructive steps flagged, post-flight, rollback. OPS-R2 checks the pre-flight, post-flight and rollback sections and the Expect and Stop if lines. A drill never touches production data: it restores into a scratch target, fails over in a window the operator chose, or takes down a dependency of a non-production environment.

### Restore

1. **Pre-flight:** the newest backup exists and its time is known; the incident time the drill pretends is set (the RPO is the incident time minus the backup time); the scratch target is empty; images are pulled; the clock is noted.
2. Restore the backup into the scratch target with the command the Maintenance manual names.
3. Start the service against the scratch target; wait for `ops.ready_path` to answer 200. The time since the start is the RTO.
4. Compare: row counts or checksums of the key tables against the source at the backup time.
5. **Post-flight:** remove the scratch target with its volumes, and the downloaded backup copy (destructive: flagged, confirmed; the copy holds production data), and check that nothing is left; write the record with `measured_rto`, `measured_rpo` and the redacted output as evidence; update the manual's Backup and restore section with the date (OPS-R7).
6. **Rollback:** the same removal, when the drill stops part way.

### Failover

1. **Pre-flight:** both sides healthy; replication lag known (this bounds the RPO); a change window agreed; the clock is noted.
2. Trigger the failover the IaC declares (a Multi-AZ reboot with failover, a Route 53 health check forced unhealthy, promoting a replica).
3. Measure until `ops.ready_path` answers 200 through the public route: the RTO.
4. **Post-flight:** writes succeed on the new primary; the record with both measurements.
5. **Rollback:** fail back the same way, with its own Expect and Stop if.

### Alarm exercise

1. **Pre-flight:** the alert's runbook exists; the on-call schedule has a role on duty; the people on duty know an exercise is running.
2. Raise the condition (or use the alerting system's test notification for that alert).
3. **Expect** the page within the alert's evaluation period; **record the role** that acknowledged it in `reached`.
4. **Rollback:** clear the condition; confirm the alert resolves.

### Readiness exercise

1. **Pre-flight:** a non-production environment; readiness and liveness both 200.
2. Stop one dependency (the database, the queue).
3. **Expect** `ops.ready_path` to answer a non-2xx status (503) and `ops.health_path` to stay 200; record `probe` and `probe_status`.
4. **Rollback:** start the dependency; **Expect** readiness 200 again.

### Runbook dry-run

Read the runbook an alert links to from start to end in a non-production environment, running only its read-only steps and its pre-flight. Every command must exist and accept its flags. Record `kind: dry-run`, the `runbook` path, and any step that did not work as a `follow_up`.
