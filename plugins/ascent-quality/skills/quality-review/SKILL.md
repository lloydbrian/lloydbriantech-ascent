---
name: quality-review
description: >-
  Use when asked "review our tests", "is our test strategy sound?", "what
  tests are missing?", "does every acceptance criterion have a test?", "are
  our tests trustworthy?", or before a release. Rates the test strategy
  against the project contract: maps the tests by type, checks five lenses
  (inventory, traceability, hygiene, load, mutation), runs the inventory, test
  and evidence checks, and reports strong, moderate or weak with file:line
  evidence. Read-only.
version: 0.2.0
allowed-tools: Read, Grep, Glob, Bash(git log:*), Bash(git ls-files:*)
---

# quality-review

One review of whether a repository's tests can be trusted to catch a broken change, judged against the project's own targets. It is the entry point of the `ascent-quality` plugin. It runs surface checks itself and recommends [test-inventory](../test-inventory/SKILL.md), [test-check](../test-check/SKILL.md) or [test-evidence](../test-evidence/SKILL.md) only for the lenses a surface check flags (the hybrid pattern). It never invokes them; they read the same sources.

It makes the ASCENT tester role checkable (ADR-014, ADR-019, ADR-021): the test types the project needs exist and CI runs them, every acceptance criterion and core rule is named by a test, no test passes by doing nothing, a load test holds the service to its latency and throughput targets, and mutation evidence shows the tests fail when the code is broken.

Shared sources:
- [test-strategy.md](../../references/test-strategy.md): test types, how they are recognized, criterion ids, the boundaries, the hygiene rules, load tests and mutation evidence
- [contract-template.yml](../../references/contract-template.yml): the `quality:` section of `.ascent/contract.yml`

## Rules

- **Read-only.** Never edit files, write or fix a test, run the test suite, or install a test tool. Never run a load test or a mutation tool. `git log` and `git ls-files` are the only commands pre-approved; run `git log` only to read history, never with `--output`, `--ext-diff` or `--textconv`. The three scripts only read.
- **Evidence or it is not a finding.** Every finding cites a repository-relative `path/to/file:line` (never a bare file name or a directory) or "absent: searched <paths>", the rule it breaks (QA-I1–I5, QA-T1–T4, QA-H1–H4, QA-L1–L5, QA-M1–M4, or the maturity item), a concrete failure scenario (what breaks, for whom, when), and a fix.
- **Fresh evidence.** Re-read the evidence for every finding in this run. Never carry findings over from an earlier pass, an agent's report or another session.
- **Rate only with the severity table.** A concern that matches no row goes under **Other observations (unrated)** and does not count toward the rating. Never invent a severity.
- **Judge against the contract**, not against an ideal. A gap covered by a waiver ADR is Info, not a finding.
- **Never "met" without a target.** A lens whose target is missing from the contract is unmeasured, never met; it is at risk instead when the evidence shows a gap.
- **A test present is this plugin's; a test run live is the operator's.** Never run the suite to prove a test works. Where a result would help, write the command for the operator and read the redacted output they paste.
- **Other plugins' tests stay theirs** (ADR-014 decision 1). Accessibility, navigation and front-end performance tests are `ascent-ux`'s; recovery drills and readiness exercises `ascent-ops`'s; smoke tests after a deploy and user-acceptance sign-off `ascent-delivery`'s; security tests and scans `ascent-security`'s. Mark such items `→ ascent-ux`, `→ ascent-ops`, `→ ascent-delivery` or `→ ascent-security` under Other observations.
- **Targets are read, never copied.** `p95_latency_ms` and `peak_rps` come from `architecture.quality_targets`, which `ascent-architecture` sets. Never write them into the `quality:` section; with neither, the load lens is unmeasured.
- **Not checked here:** code health (coupling, complexity), which is `ascent-architecture`'s. Name it under Other observations only when the contract or the operator asks.
- **Maturity gaps are always rated.** With no confirmed contract, rate them against the enterprise defaults (Step 4) and say so; never list them unrated.
- **No secrets, account ids or personal data** in the report, even when a test fixture holds one: name the file and line, never the value, and mark it `→ ascent-security`. Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`.
- **Scripts.** The plugin's read-only scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`.

## Severity

Every finding carries one of these severities. The other skills, the `quality-reviewer` agent and the three scripts use the same table.

<!-- qa-severity:start -->
| Finding | Severity |
|---|---|
| A focused test committed (.only, fit, fdescribe, @pytest.mark.only), so CI runs only part of the suite (QA-H1) | High |
| A required test type with no tests (QA-I1) | Medium |
| No CI configuration, or no CI step that runs the tests (QA-I2) | Medium |
| An acceptance criterion that no test names (QA-T1) | Medium |
| A core-rule source file that no test names (QA-T4) | Medium |
| A skipped test with no reason given (QA-H2) | Medium |
| A test with no assertion (QA-H3) | Medium |
| A load test missing while the contract sets p95_latency_ms or peak_rps (QA-L1) | Medium |
| A load test whose p95 threshold is missing or looser than p95_latency_ms (QA-L2) | Medium |
| A load test whose request rate stays below peak_rps (QA-L3) | Medium |
| No mutation tool configured (QA-M1) | Medium |
| A mutation break threshold missing or below min_score (QA-M2) | Medium |
| No usable mutation report in the repository (none, or each unreadable, undated or dated after today), or the newest older than max_age_days or below min_score (QA-M4) | Medium |
| End-to-end or contract tests that no CI step runs (QA-I3) | Low |
| A database, queue or HTTP client that no test reaches (QA-I4) | Low |
| A package.json with no test script and no make test target, or npm's placeholder script (QA-I5) | Low |
| A test that names a criterion id no document defines (QA-T2) | Low |
| No criterion ids, so traceability is unmeasured (QA-T3) | Low |
| Retries that hide flaky tests (QA-H4) | Low |
| A load test with no error-rate threshold (QA-L4) | Low |
| A load test that no CI step, make target or runbook runs (QA-L5) | Low |
| A mutation tool that no CI step runs (QA-M3) | Low |
| A quality target missing from the contract ("unmeasured") | Low |
| Any other item the maturity target requires, missing with no waiver (Step 4) | Low |
| A gap covered by a waiver ADR | Info |
<!-- qa-severity:end -->

**Rating:** **strong**: no High and no Medium. **moderate**: no High, one or more Medium. **weak**: one or more High.

## Steps

### Step 0 — Load or propose the contract

Read `.ascent/contract.yml`, or `.claude/contract.yml` where ASCENT-named files are not allowed, and use its `quality:` section.

If it is missing, **detect, don't ask.** Propose the section from what the repository declares:

- **Test paths:** the directories that hold test files (see [test-strategy.md](../../references/test-strategy.md#how-a-test-file-is-recognized)).
- **Types required:** the maturity default. Add `e2e` at enterprise when the project has a user interface: HTML templates, JSX, Vue or Svelte files, or a `pages/`, `app/` or `public/` directory with HTML.
- **Criteria:** the directories whose Markdown holds ids like `AC-1` (specs, requirements, user stories, issue templates). With none, leave `criteria_paths` empty and say traceability will be unmeasured.
- **Core paths:** source directories named for business rules (`domain/`, `rules/`, `core/`, `models/`, `services/`), marked `# guess`. Never guess them without marking.
- **Assertion helpers:** functions the tests call that are defined in a test helper and throw or exit on failure (`assertEqual`, `check`), with their `file:line`.
- **Mutation:** the template defaults (`min_score: 60`, `max_age_days: 90`), raised to the tool's break threshold when one is configured (`# detected: <path:line>`), and any report a default name would not find under `reports`.
- **Load targets:** none. Read `p95_latency_ms` and `peak_rps` from the `architecture:` section of the same contract; with neither, say the load lens is unmeasured and that `ascent-architecture:quality-attributes` sets them.

Use only the keys and values of [contract-template.yml](../../references/contract-template.yml):
- `maturity_target` is one of enterprise, standard or prototype (never a new value)
- `types_required` takes only unit, integration, contract and e2e
- each waiver is an `id`, `skips` and `review_by`
- mark detected values with their source (`# detected: <path:line>`) and guesses with `# guess`

Show the proposal once and ask the operator to confirm it. Write nothing: the operator commits the file. Until it is confirmed, review against the enterprise defaults, and say so in the report.

### Step 1 — Map the tests

Build the inventory from the repository, not from memory:

| Test file or directory | Type | Runner | Run by CI | Notes |
|---|---|---|---|---|

List the test files grouped by directory and type; the runner each uses (Jest, Vitest, Mocha, node:test, Playwright, Cypress, pytest, unittest, go test, bats, a project script); the CI files and the steps that run tests, following make targets and package scripts; the criteria documents and how many ids each defines; and the core-rule sources. A repository with no tests says so in one line and goes on to Step 3.

### Step 2 — Surface checks (five lenses)

One line per lens: what the contract asks, the evidence found, and the status **met**, **at risk** or **unmeasured**. A lens whose target is missing from the contract is unmeasured, never met; it is at risk instead when the evidence shows a gap. Report these five lenses, in this order, and no others:

- **Inventory:** every type in `types_required` has tests, CI runs them on every change, and the integration boundaries (databases, queues, outbound HTTP) are reached by a test (QA-I1–I5).
- **Traceability:** every acceptance criterion and every core rule is named by a test, and no test names a criterion that no longer exists (QA-T1–T4).
- **Hygiene:** no focused tests, no unexplained skips, no tests without an assertion, no retries that hide flaky tests (QA-H1–H4).
- **Load:** a load test asserts a p95 no looser than `p95_latency_ms`, reaches `peak_rps`, sets an error-rate threshold and is run by CI, a make target or a runbook (QA-L1–L5).
- **Mutation:** a mutation tool is configured with a break threshold at `min_score` or above, CI runs it, and a report in the repository no older than `max_age_days` shows the score (QA-M1–M4).

A lens at risk or unmeasured: recommend [test-inventory](../test-inventory/SKILL.md) for inventory, [test-check](../test-check/SKILL.md) for traceability or hygiene, and [test-evidence](../test-evidence/SKILL.md) for load or mutation.

### Step 3 — Mechanical checks

Run the three scripts from the repository root, with the contract's values, and include their output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-test-inventory.sh" --types '<quality.tests.types_required, comma-separated>' .
bash "$PLUGIN_ROOT/scripts/check-tests.sh" --criteria '<each criteria_paths entry>' --id-pattern '<criteria_id_pattern>' --core '<each core_paths entry>' --helper '<each assertion_helpers entry>' .
bash "$PLUGIN_ROOT/scripts/check-test-evidence.sh" --p95 '<architecture.quality_targets.p95_latency_ms>' --rps '<architecture.quality_targets.peak_rps>' --min-score '<mutation.min_score>' --max-age '<mutation.max_age_days>' --report '<each mutation.reports entry>' --maturity '<maturity_target>' .
```

Leave out an option whose contract value is empty. Repeat `--criteria`, `--core`, `--helper` and `--report` once per entry. **Quote every contract value.** Put each value in single quotes, as above. Refuse a value that holds a single quote, a newline, `$(` or a backtick, and say so under Other observations: the contract is a file the repository controls. Show the command before you run it.

- Each `FAIL` line is a finding with the severity it prints, under the rule id it names.
- An `absent` location means nothing was found anywhere searched: cite it as "absent: searched <paths>".
- `NOTE` lines are unrated: list them under Other observations.
- `N/A` is never a pass. Say what had nothing to check. `QA-T4` N/A with no `core_paths`, and `QA-L1` N/A with no latency or throughput target, are the "unmeasured" Low row.
- **QA-H3 and QA-I4 are heuristics.** Open each hit before you rate it. A test that calls a project helper which asserts is not assertion-less: name the helper for `assertion_helpers` and rerun with `--helper`. A boundary reached through the project's own wrapper, which a test does exercise, is not a finding: say which test reaches it.
- If Bash is unavailable or the operator declines it, apply the rules by reading and say "checks applied by reading; scripts not run".

### Step 4 — Maturity gaps

Compare what you found with the `maturity_target` row by row, using the maturity table in the plugin [README](../../README.md#maturity-targets). Each missing item is a finding at the severity the table above gives it, unless a waiver ADR in `quality.waivers` covers it. Then it is listed as **Info: waived by ADR-NNN**, and the ADR is checked to exist in `adr_dir`. A waiver that points at a missing ADR is a Low finding.

### Step 5 — Report

The counts and the rating cover rated findings only. Every rated finding gets the full `Q<n>` block, Low ones included: no condensed lists.

```
quality-review: <strong | moderate | weak> — <H> High, <M> Medium, <L> Low, <I> Info
Contract: <path, or "none — enterprise defaults (proposal shown in Step 0)">
Maturity target: <target>   Types required: <list>   Criteria: <paths or "none">   Core: <paths or "none">
Targets: p95 <ms or "none">, peak <rps or "none"> (architecture.quality_targets)   Mutation: min_score <n>, max_age_days <n>

Test map (Step 1): <inventory table>
Lenses (Step 2): <one line per lens: target | evidence | status (met only when the contract sets a target)>

Findings, most severe first:
Q<n>  <severity>  <file>:<line or "absent: searched …">  <rule id or maturity item>
      Scenario: <what breaks, for whom, when>
      Fix: <the smallest change that closes it: the test to add, the skip to explain, the CI step to add>

Other observations (unrated):
O<n>  <file>:<line>  <concern>  [→ ascent-ux | → ascent-ops | → ascent-delivery | → ascent-security]

Mechanical checks (Step 3): <the three scripts' output, verbatim>
Recommended next: <only the deeper skills whose surface checks flagged something, with the reason; ascent-security when any item is marked → ascent-security>
```

## What this skill does not do

- Write, fix, unskip or run tests. Fixes go through the delivery loop (`ascent-delivery`) and the operator's runbook.
- Measure coverage. A coverage figure says which lines ran, not which behaviour is checked; this review asks the second question.
- Run a load test or a mutation tool, or check code health (see Rules).
