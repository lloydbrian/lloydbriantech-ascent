---
name: test-inventory
description: >-
  Use when asked "what tests do we have?", "are we missing integration or
  end-to-end tests?", "does CI run our tests?", "which database or HTTP
  calls have no test?", or when quality-review flags the inventory lens.
  Lists the tests by type and runner, checks each required type exists and
  CI runs it, and finds integration boundaries (database, queue and HTTP
  clients) that no test reaches (QA-I1–I5). Read-only.
version: 0.2.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*)
---

# test-inventory

The deep inventory check behind [quality-review](../quality-review/SKILL.md). It is a sibling that shares that skill's severity table, contract and evidence rules. It answers two questions: does the project have the kinds of test its maturity target needs, and does CI run them on every change?

Source: [test-strategy.md](../../references/test-strategy.md) (how a test file is recognized and typed, CI, boundaries).

## Rules

- All `quality-review` rules apply: read-only; repository-relative `file:line` evidence; fresh evidence; severities only from the `quality-review` table; no personal data.
- **Never run the tests or CI**, not even one file: a test run can reach real services. Reading is enough; write the command for the operator when a run would settle a question.
- **The types required come from the contract** (`quality.tests.types_required`), or the maturity default when there is none (`quality-review` Step 0). Never require a type the contract leaves out.

## Steps

### Step 1 — Inventory

List every test file by directory, with its type (unit, integration, contract, e2e), its runner and whether a CI step runs it. Follow each CI step through the make targets and package scripts it calls. Name the boundaries the source imports (database, queue, outbound HTTP clients) with `file:line`.

### Step 2 — Mechanical checks

Run the script from the repository root and include its output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-test-inventory.sh" --types '<types_required, comma-separated>' .
```

`PLUGIN_ROOT` is two directories above this skill's base directory. **Quote every contract value.** Put each value in single quotes, as above. Refuse a value that holds a single quote, a newline, `$(` or a backtick, and say so under Other observations: the contract is a file the repository controls. Show the command before you run it. Each `FAIL` line is a finding at the severity it prints.

### Step 3 — Read what the script cannot

- **Types the paths do not show.** A project that keeps integration tests in `tests/` with a marker of its own (`@slow`, a `describe('integration')` block): read a sample and correct the inventory. A type found by reading clears a QA-I1 failure only with the `file:line` that shows it.
- **CI steps split over lines.** A YAML `run: |` block whose test command is on a later line, or a reusable workflow: read the workflow and say which step runs the tests.
- **Boundaries.** Open each QA-I4 hit. A test that reaches the client through the project's own wrapper (a `db.js` module that a test imports and exercises against a test database) clears it: name the test. A client used only in a script the operator runs by hand is an observation, not a finding.

### Step 4 — Report

Use the `quality-review` Step 5 format, limited to the inventory lens: the inventory table, findings with rule ids (QA-I1–I5), Other observations, and the script output verbatim.
