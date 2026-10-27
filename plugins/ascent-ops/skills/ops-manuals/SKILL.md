---
name: ops-manuals
description: >-
  Use when asked "write the operations manual", "update the troubleshooting
  guide", "are our manuals current?", "draw the architecture for operators",
  or when ops-review flags the manuals lens. Creates or updates the
  Maintenance and Operations Manual and the Troubleshooting Manual from the
  repository, with Mermaid C4 diagrams (context, containers, deployment), a
  dependency map with versions and a symptom table; checks whether they are
  current. Writes only those two files, with surgical edits; never commits.
version: 0.2.0
allowed-tools: Read, Grep, Glob, Bash(git log:*), Bash(git ls-files:*)
---

# ops-manuals

Keeps the two operations manuals at their latest and greatest. It is a sibling of [ops-review](../ops-review/SKILL.md) and shares its severity table and evidence rules. It is the only `ascent-ops` skill that writes, and it writes exactly two files.

Sources: [manual-sections.md](../../references/manual-sections.md) (front matter, sections, diagrams, staleness) and the blueprint's [Maintenance and Operations Manual](../../blueprints/operable-service/MAINTENANCE-AND-OPERATIONS.md) and [Troubleshooting Manual](../../blueprints/operable-service/TROUBLESHOOTING.md), a worked example that passes OPS-M1–M8.

## Rules

- **Two files only.** Write only `ops.manuals.maintenance` and `ops.manuals.troubleshooting` (defaults `docs/operations/MAINTENANCE-AND-OPERATIONS.md` and `docs/operations/TROUBLESHOOTING.md`), or the draft directory the operator names (for example `tmp/`), never both. Never touch any other file, and never write into a repository the operator asked you only to review.
- **Modify, never overwrite.** Update an existing manual with surgical edits to the sections that changed; keep the operator's own text, ordering and notes. Create a manual only when it does not exist, starting from the blueprint's structure.
- **Show the diff, never commit.** After writing, show the diff and stop. The operator reviews it and commits; never run `git add`, `git commit` or any other git write.
- **Facts from the repository only.** Every statement cites where it came from (a file in `sources`); write "unknown: <what to ask the operator>" rather than guess. Never invent hosts, versions, contacts or SLOs.
- **No secrets or personal data.** Name where a value lives, never the value. Contacts are roles and channels; names, phone numbers and email addresses stay in the paging tool.
- **Diagnostics only read.** The Troubleshooting Manual's commands only read; anything that changes the system belongs in a runbook.
- **Dated.** Set `as_of` to today, `describes` to the release tag or commit the manual now matches (`git describe --tags`, or the short commit from `git log -1 --format=%h`), and add a change-history row.

## Steps

### Step 1 — Paths and sources

Read `ops.manuals` from the contract (defaults above). List the sources the manuals must describe: the IaC and Compose files, the operator scripts and runbooks, the manifests (`package.json` and lock files, `requirements*.txt`, `pyproject.toml`, `go.mod`, Dockerfile `FROM` lines, Terraform `required_providers` and modules, `.tool-versions`, `.nvmrc`), and the configuration and secret definitions.

### Step 2 — Current state

When the manuals exist, run the check and include its output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-ops-manuals.sh" --repo . <maintenance manual> <troubleshooting manual> .
```

`PLUGIN_ROOT` is two directories above this skill's base directory. Each `FAIL` line is something this run must fix. For OPS-M6, `git log --oneline <describes>..HEAD -- <sources>` lists the changes the update must cover; read those commits first.

### Step 3 — Gather the facts

- **Diagrams:** the system context (users, operators, external systems), the containers (each Compose service and each service-like IaC resource, with its technology and how they talk), and the deployment (hosts, accounts, regions, what runs where). Every service in the IaC and Compose files appears by name (OPS-M4). With no IaC or Compose, draw from the inventory of hosts and devices the scripts and runbooks name.
- **Dependency map:** one row per dependency from the manifests, with the pinned version and the file it comes from.
- **Configuration and secrets:** every parameter and variable, where it lives, whether it is a secret, its rotation (OPS-S10).
- **Deploy, rollback, backup, maintenance, upgrades, access:** from the runbooks, scripts and make targets, citing them.
- **Symptoms:** from the runbooks' Stop-if lines, the scripts' error messages, the health endpoints and known issues in the docs or the backlog.

### Step 4 — Write

Follow the section lists in [manual-sections.md](../../references/manual-sections.md). Mermaid at the three C4 levels (`C4Context`, `C4Container`, `C4Deployment`). Update only the sections whose facts changed; keep everything else as the operator wrote it. Then show the diff.

### Step 5 — Verify

Run the Step 2 command again and include the output. Every check passes, or each remaining `FAIL` is listed with the question the operator must answer. Report:

```
ops-manuals: <created | updated> <paths>; as_of <date>; describes <ref>
Sections changed: <list>
check-ops-manuals: <output, verbatim>
Open questions: <each "unknown" with what to ask>
Next: review the diff, then commit it yourself (git add <paths> && git commit)
```
