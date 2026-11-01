---
name: test-check
description: >-
  Use when asked "does every acceptance criterion have a test?", "trace
  requirements to tests", "are our core rules tested?", "find skipped or
  focused tests", "which tests assert nothing?", "are we hiding flaky
  tests with retries?", or when quality-review flags the traceability or
  hygiene lens. Traces criterion ids and core rules to tests (QA-T1–T4) and
  checks test hygiene: focused, skipped, assertion-less and retried tests
  (QA-H1–H4). Read-only.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*)
---

# test-check

The deep traceability and hygiene check behind [quality-review](../quality-review/SKILL.md). It is a sibling that shares that skill's severity table, contract and evidence rules. A suite can be large and still prove little: this skill checks that each criterion and core rule has a test, and that each test can fail.

Source: [test-strategy.md](../../references/test-strategy.md) (criterion ids, core rules, the hygiene rules and their exemptions).

## Rules

- All `quality-review` rules apply: read-only; repository-relative `file:line` evidence; fresh evidence; severities only from the `quality-review` table; no personal data.
- **Never edit, unskip or run a test.** A fix names the test to add or change; the delivery loop makes it.
- **A test that is named is not a test that checks.** QA-T1 proves a test names the criterion. When the criterion is Medium or the test is short, read the test and say whether its assertions check what the criterion says; a mismatch goes under Other observations.
- **Never invent criterion ids.** With none in the repository, traceability is unmeasured (QA-T3); the fix is for the project to give its criteria ids.

## Steps

### Step 1 — Criteria and core rules

List the criteria documents (`quality.tests.criteria_paths`, or every Markdown file) with the ids each defines, and the core-rule sources (`quality.tests.core_paths`). With no `core_paths`, QA-T4 is unmeasured: name the directories that look like business rules (`domain/`, `rules/`, `core/`) as a proposal, marked `# guess`.

### Step 2 — Mechanical checks

Run the script from the repository root and include its output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-tests.sh" --criteria '<each criteria_paths entry>' --id-pattern '<criteria_id_pattern>' --core '<each core_paths entry>' --helper '<each assertion_helpers entry>' .
```

`PLUGIN_ROOT` is two directories above this skill's base directory. Leave out an option whose contract value is empty. **Quote every contract value.** Put each value in single quotes, as above. Refuse a value that holds a single quote, a newline, `$(` or a backtick, and say so under Other observations: the contract is a file the repository controls. Show the command before you run it. Each `FAIL` line is a finding at the severity it prints; `NOTE` lines are unrated.

### Step 3 — Read what the script cannot

- **QA-H3 hits.** Open each one. A test that calls a project helper which throws or exits on failure is not assertion-less: name the helper and its `file:line`, propose it for `assertion_helpers`, and rerun with `--helper`. A test whose only check is "does not throw" stays a finding: say which result it should assert.
- **Block ends.** The script ends a JS test at its closing parenthesis, a Go test at its closing brace, a Python test at its indentation and a bats test at a `}` in column 1. A regular expression with an unbalanced parenthesis or brace can move that end: when a hit looks wrong, read the block.
- **Skip reasons.** A NOTE skip cites a reason. When the reason names an issue or a date that has passed, list it under Other observations.
- **Criteria the tests name in another form** (a tag `@ac-3`, a table of ids in the test file's header): read them and say so; when the form is consistent, propose it as `criteria_id_pattern`.

### Step 4 — Report

Use the `quality-review` Step 5 format, limited to the traceability and hygiene lenses: the criteria and core-rule map, findings with rule ids (QA-T1–T4, QA-H1–H4), Other observations, and the script output verbatim.
