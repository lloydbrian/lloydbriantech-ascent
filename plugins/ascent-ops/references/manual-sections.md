# The two manuals

Every operable system has two manuals, at the paths in `ops.manuals` (defaults `docs/operations/MAINTENANCE-AND-OPERATIONS.md` and `docs/operations/TROUBLESHOOTING.md`). `ops-manuals` writes them; `check-ops-manuals.sh` checks them (OPS-M1–M8). The [operable-service blueprint](../blueprints/operable-service/MAINTENANCE-AND-OPERATIONS.md) is a complete worked example of both.

## Front matter (OPS-M1)

```yaml
---
as_of: 2026-10-25        # the date of the last review
describes: v1.4.2        # the release tag or commit the manual matches
sources:                 # the files it documents, relative to the repository root
  - infra/
  - compose.yml
  - scripts/deploy.sh
---
```

## Kept current (OPS-M6)

A manual is out of date when any of these is true:
- `as_of` is more than 90 days old
- a file in `sources` no longer exists
- `git log <describes>..HEAD -- <sources>` lists any commit: the system changed after the manual was written

When `describes` is not a tag or commit in the repository, the change check is a NOTE, not a pass: say "source changes not checked". The fix is always the same: run `ops-manuals`, review the diff, update `as_of` and `describes`, and add a change-history row.

## Maintenance and Operations Manual (OPS-M2)

| Section | What it holds |
|---|---|
| Overview | what the system does, owner (a team or role), environments, health endpoints, IaC, service levels |
| Architecture diagrams | Mermaid C4 diagrams: system context, containers, deployment (OPS-M3); every IaC and Compose service drawn (OPS-M4) |
| Dependency map | a table built from the manifests: dependency, kind, version, source file, update policy (OPS-M5) |
| Environments | each environment: purpose, where it runs, its configuration path, who can deploy |
| Configuration and secrets | every parameter and variable: where it lives, secret or not, rotation (OPS-S10); never a value |
| Deploy | the runbook steps, with pre-flight and post-flight checks |
| Rollback | how to restore the previous release, and when to do it |
| Backup and restore | what, how, when, retention, and the date of the last restore test |
| Scheduled maintenance | recurring tasks with cadence, command and expected result, including the drift check and the manual review |
| Upgrades | how dependencies are upgraded, in which order, and when an ADR is needed |
| Access | who can do what, how access is granted, and when it is reviewed |
| Escalation and contacts | roles and channels in order; names, phone numbers and email addresses stay in the paging tool |
| Change history | date, release, change and the sections updated |

## Troubleshooting Manual (OPS-M2, OPS-M7)

| Section | What it holds |
|---|---|
| Symptoms | a table: symptom, where to look, likely cause, fix or escalation (OPS-M7) |
| Diagnostic commands | read-only commands only, copied as written |
| Known issues | issue, workaround, where it is tracked |
| Escalation | when to escalate and to whom (roles), pointing at the escalation table |

## Diagrams

- **Mermaid in the Markdown** at the three C4 levels: `C4Context`, `C4Container`, `C4Deployment` (or a flowchart under a heading that names the level). Mermaid renders on GitHub, stays plain text and shows in diffs; images and draw.io files do not.
- **Every service is drawn.** Each Compose service and each service-like IaC resource (functions, databases, buckets, queues, load balancers, distributions, clusters) appears by name in a diagram. A resource with a generic name (`this`, `main`) is matched by its kind (`s3`, `lambda`).
- **No system to map** (no IaC or Compose, such as scripts that manage network devices): OPS-M4 is N/A, and the diagrams are checked by reading against the inventory of hosts and devices the scripts name.

## Contents never allowed

No secret values, credentials, tokens, account ids, IP allow-lists of personal devices, email addresses, phone numbers or names of private individuals (OPS-M8 checks the credential-like ones). Refer to where a value lives, not to the value.
