---
name: test-evidence
description: >-
  Use when asked "do our load tests match our latency target?", "will the
  load test catch a slow release?", "do we have mutation testing?", "what is
  our mutation score?", or when quality-review flags the load or mutation
  lens. Checks that a k6, Artillery or Locust load test asserts the p95
  latency and reaches the request rate in the contract's targets (QA-L1–L5),
  and that a mutation tool is configured, run by CI and backed by a current
  score in the repository (QA-M1–M4). Read-only; never runs a load test or a
  mutation tool.
version: 0.2.0
allowed-tools: Read, Grep, Glob, Bash(git log:*), Bash(git ls-files:*)
---

# test-evidence

The deep load-test and mutation check behind [quality-review](../quality-review/SKILL.md). It is a sibling that shares that skill's severity table, contract and evidence rules. It answers two questions: would a load test fail if the service missed its latency or throughput target, and is there evidence that the tests fail when the code is broken?

Source: [test-strategy.md](../../references/test-strategy.md#load-tests-and-mutation-evidence) (the tools, how thresholds and rates are read, report formats and dates).

## Rules

- All `quality-review` rules apply: read-only; repository-relative `file:line` evidence; fresh evidence; severities only from the `quality-review` table; no personal data.
- **Never run a load test or a mutation tool.** A load test reaches a live environment, and a mutation run rewrites the code under test and can take hours. Both are the operator's; write the command for them when a run would settle a question, and read the redacted output they paste.
- **Targets are read, never copied.** `p95_latency_ms` and `peak_rps` come from `architecture.quality_targets` (set by `ascent-architecture`), `min_score` and `max_age_days` from `quality.mutation`. Never write a target into the `quality:` section. With no latency or throughput target, the load lens is unmeasured.
- **A NOTE is never a pass.** A load set in virtual users has no request rate the script can read: open the script and say what rate it reaches, or that it cannot be told.

## Steps

### Step 1 — Inventory

List every load-test script with its tool, the p95 threshold it asserts, the request rate it reaches and what runs it (CI, a make target, a runbook). List every mutation tool with its configuration file, its break threshold and the CI step that runs it, and every report in the repository with its date (from its path, or from its last commit) and score. Cite `file:line` for each.

### Step 2 — Mechanical checks

Run the script from the repository root and include its output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-test-evidence.sh" --p95 '<architecture.quality_targets.p95_latency_ms>' --rps '<architecture.quality_targets.peak_rps>' --min-score '<quality.mutation.min_score>' --max-age '<quality.mutation.max_age_days>' --report '<each quality.mutation.reports entry>' --maturity '<quality.maturity_target>' .
```

`PLUGIN_ROOT` is two directories above this skill's base directory. Leave out an option whose contract value is empty, and repeat `--report` once per entry. **Quote every contract value.** Put each value in single quotes, as above. Refuse a value that holds a single quote, a newline, `$(` or a backtick, and say so under Other observations: the contract is a file the repository controls. Show the command before you run it. Each `FAIL` line is a finding at the severity it prints.

### Step 3 — Read what the script cannot

- **Rates and thresholds set at runtime.** A k6 rate read from `__ENV`, an Artillery phase in a separate environment file, a Locust user count passed by a wrapper script: read them and say what the test reaches. A value found by reading clears a finding only with the `file:line` that shows it.
- **QA-L3 NOTE lines.** Open each script the NOTE names. A virtual-user load reaches a rate only through its think time and response time, so it cannot prove `peak_rps`; recommend an arrival-rate executor (k6 `constant-arrival-rate`, Artillery `arrivalRate`, Locust `constant_throughput`).
- **Which script is the peak test.** The script checks each rule against at least one load script. Say whether the script that asserts the latency threshold is also the one at peak rate; if not, it is an observation, not a finding.
- **Gatling and JMeter.** Not read by the script: with a latency or throughput target, a project that uses only them fails QA-L1. Read the simulation or the test plan for its assertions and say what it checks under Other observations; the QA-L1 finding stands, because the script cannot confirm it.
- **Exit 2 on `--report`.** A `quality.mutation.reports` entry must be a file inside the repository, not a directory, a glob, a symbolic link or a path with `..`. Say which entry was refused and rerun without it.

### Step 4 — Report

Use the `quality-review` Step 5 format, limited to the load and mutation lenses: the inventory, findings with rule ids (QA-L1–L5, QA-M1–M4), Other observations, and the script output verbatim.
