---
name: doc-drift
description: >-
  Use when asked "do the docs still match the code?", "find outdated
  commands in the docs", "which documented make targets or npm scripts no
  longer exist?", "fix the docs after this refactor", or after renaming
  files, targets, scripts or environment variables. Checks what the
  documents name against the repository (DOC-R1–R6: paths, make targets,
  package scripts, environment variables, the version, pinned runtimes),
  traces each mismatch to the commit that changed the name, and proposes the
  exact edit for each; applies only the edits a person approves, to
  documents only, and never commits.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# doc-drift

Keeps what documents name in step with the repository: the command a reader copies runs, the file they open exists, the variable they set is read.

Shared sources:
- [docs-rules.md](../../references/docs-rules.md): DOC-R1–R6 and their limits
- [contract-template.yml](../../references/contract-template.yml): `docs.paths`, `exclude`, `version_file`, `ignore_env`, `ignore`

## Rules

- **Write only after approval, and only documents:** the Markdown files under `docs.paths`. Never edit code, a Makefile, package.json or a contract to match a document; when the document is right and the code is wrong, say so and stop. Never commit.
- **One edit per finding,** shown as the exact old and new line. Never rewrite a paragraph around it.
- **Find the cause before the fix.** A name that vanished was usually renamed: find the new name in the history, never guess one.
- **Never add to `docs.ignore` on your own.** A person confirms that a name belongs to another project; the report says what they would be accepting.
- **No secrets or personal data** in proposed edits.
- **Scripts.** The scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`. Quote every contract value you pass to a script.

## Steps

### Step 0 — Load the contract

Follow docs-review Step 0.

### Step 1 — Run the drift checks

```bash
bash "$PLUGIN_ROOT/scripts/check-doc-drift.sh" --path '<docs.paths>'... --exclude '<docs.exclude>'... [--version-file '<docs.version_file>'] --ignore-env '<name>'... --ignore '<name>'... --maturity '<maturity_target>' .
```

Pass each list entry once, and leave out an option whose value the contract does not set. Exit 2 is bad input: fix the arguments, never rate it. Severity is the doc-severity table in docs-review.

### Step 2 — Trace each mismatch

For a missing path, target or script, find when it went: `git log --format='%h %cs %s' -n 5 -- <path>` for a path, and `git log -S'<name>' --format='%h %cs %s' -n 5 -- Makefile make package.json` for a target or script. Read that commit's change to find the new name. When nothing in the history explains it, the name may belong to another project the document describes: say so, and leave the decision to the person.

### Step 3 — Propose

```
| Rule | Evidence | Was | Now | Edit |
|---|---|---|---|---|
| DOC-R2 | docs/guide.md:41 | make bundle | make build (renamed in 3f1c2aa) | `make bundle` → `make build` |
```

List the findings with no clear fix separately, with what a person must decide.

### Step 4 — After confirmation only

Apply each approved edit as a surgical edit to its line. Then rerun Step 1: each fixed finding must be gone and nothing new may fail. Say: "N edits applied to M documents. Nothing is committed."
