---
name: runbook-check
description: >-
  Use when asked "check our runbooks", "are our scripts zero-touch?", "do our
  deploys have pre-flight and post-flight checks?", "is there a rollback?",
  or when ops-review flags the scripts and runbooks lens. Checks operator
  scripts (Z1–Z9: strict mode, --help, dry run, secrets with read -rs,
  guarded destructive commands, pinned versions), make targets, and runbooks
  against the runbook standard: pre-flight, numbered steps with Expect and
  Stop if, flagged destructive steps, post-flight and rollback. Read-only.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*)
---

# runbook-check

The deep scripts and runbooks check behind [ops-review](../ops-review/SKILL.md). It is a sibling that shares that skill's severity table, contract and evidence rules. It checks that every operation is a zero-touch command an operator can follow under pressure, with checks before and after each change.

Sources: [runbook-standard.md](../../references/runbook-standard.md) and the blueprint's [ops-script-template.sh](../../blueprints/operable-service/ops-script-template.sh), a script that passes Z1–Z9.

## Rules

- All `ops-review` rules apply: read-only; repository-relative `file:line` evidence; fresh evidence; severities only from the `ops-review` table; no personal data.
- **Never run the scripts or the runbook steps**, not even with `--dry-run`: a dry run still reads credentials and calls cloud APIs. Reading them is enough.
- **A secret in a runbook** (a token, a password, an account id, an email address) is a High finding marked `→ ascent-security`; name the line, never the value.

## Steps

### Step 1 — Inventory

List the operator scripts (`scripts/`, `bin/`, `ops/`, `tools/`, files with a shell shebang), the make targets that change systems, and the runbooks (`ops.runbooks`, `docs/operations/`, `docs/runbooks/`, `RUNBOOK*.md`, `*-runbook.md`). For each runbook, name the scripts or targets it calls. Mark sourced libraries (they are checked for Z5 and Z6 only) and test code (not operator scripts).

### Step 2 — Mechanical checks

Run the script from the repository root and include its output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-ops-scripts.sh" .
```

`PLUGIN_ROOT` is two directories above this skill's base directory. Each `FAIL` line is a finding at the severity it prints. Z8 covers images, workflows and Terraform versions as well as scripts.

### Step 3 — Runbooks against the standard

Read each runbook against [runbook-standard.md](../../references/runbook-standard.md):
- inputs declared as shell variables, secrets read with `read -rs`, nothing personal written in
- a pre-flight section before the first change and a post-flight section after the last
- numbered steps, each with the command, **Expect** and **Stop if**
- destructive steps flagged and explained before they run
- a rollback with its own Expect and Stop if; no rollback path for production is High
- no step that changes something by hand in a console
- the date and release it was last run against

Then check that each step calls a script or make target that exists, with flags the script accepts (`--help` text or its option parsing).

### Step 4 — Report

Use the `ops-review` Step 6 format, limited to the scripts and runbooks lens: the inventory, findings with rule ids (Z1–Z9, or the runbook-standard row), Other observations, and the script output verbatim. Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`.
