# ADR-018: The fast negative-control harness: one check, first failure, parallel, with guards

**Status:** Accepted
**Date:** 2026-10-29 (America/New_York)
**Decider:** lloydbriantech

## Context

[ADR-017](ADR-017-faster-negative-controls.md) set the scope of v0.4.10: run only the check a control names, stop at the first failure, run controls in parallel, rerun survivors in full, and give the harness its own controls. It left the design to the build. An impact analysis on 2026-10-29, against `main` at `909ccc9`, found:

- 280 of the 360 plugin controls name T11. Controls already ran only their own plugin's behavior tests (`ASCENT_T11_ONLY`), but every one still ran T1–T13 and every test file of that plugin to the end, one control at a time.
- The gate's sections, T1 to T13, share only the setup at the top of `make/test-plugins.sh`; none reads another's results.
- All 16 behavior tests print nothing on a pass but their summary, and all end with `[ "$FAIL" -eq 0 ]`: a FAIL line already means a failed test, but nothing enforced it.
- Reading a test's output through a pipe that quits early would bring back the SIGPIPE failure fixed in PR #60, and would save nothing: a passing test is silent, so it only notices the closed pipe at its next FAIL line.
- Controls shared `$WORK/plugin-out` and `$WORK/before`, and kept every repository copy (about 7 MB) until the run ended.
- macOS `/bin/bash` is 3.2: no `wait -n`, and a `case` pattern's `)` inside `$( )` does not parse.
- On the last CI run on `main`, macOS groups took 7 to 15 minutes and the whole run 34, bounded by how many macOS jobs run at once. macOS runners have 3 cores, Ubuntu runners 4.

## Decision

1. **Two modes.** Fast mode is the default for `make test-mutants`; `MODE=full` (`ASCENT_MUTANT_MODE=full`) runs every control on the whole gate, as before v0.4.10. A plain `make test-plugins` is unchanged.
2. **One check.** `ASCENT_ONLY=<label>` makes `make/test-plugins.sh` run the shared setup and the label's section only (`T13.4` runs T13). An unknown label exits 2: a typo cannot pass by checking nothing. `P00-baseline` and the ownership group's baseline still run the whole gate.
3. **First failure.** With `ASCENT_T11_FAST=1`, T11 runs each behavior test in its own process group and its own `TMPDIR` inside the gate's work directory, watches its output file, and sends the group TERM at the first FAIL line. T11 then stops at that test and that plugin: any failing test fails T11. The tests that name the edited file (`ASCENT_T11_FIRST`) run first; order cannot change the verdict, only how soon it is known.
4. **Parallel.** Controls run in the background, `JOBS` at a time (`ASCENT_MUTANT_JOBS`, default the number of cores), each on its own copy, deleted once its verdict is in. Results are written to numbered files and printed in control order; the totals are counted from them, and the totals line keeps its format. Throttling uses `jobs -pr` and works in bash 3.2. The `core` group stays serial: it takes under a minute.
5. **Survivors rerun in full,** on the same copy. The report carries the FAIL lines of both runs. If full mode kills a control that fast mode did not, the result is `MODES DIFFER`, counted with the survivors: a failed run, never a kill.
6. **Three guards keep the modes in agreement:**
   - **A FAIL line fails the test.** T11 fails a behavior test that prints a FAIL line and exits 0, in both modes. Fast mode stops at the first FAIL line, so without this a test could be killed in fast mode and pass in full mode, the one disagreement a survivor rerun cannot see.
   - **Sections stay independent.** `tests/meta/test-gate-sections.sh` runs the full gate and each section alone, and fails if a section's result lines differ.
   - **Fast mode has its own self-test,** gate check T14: `tests/meta/test-gate-fast.sh` runs the gate on fixture plugins and checks the first-failure stop, that the stopped test's children stop, the stop at the first failing test, the ordering, the per-test `TMPDIR`, the FAIL-line rule and the label handling.
7. **The harness checks itself.** A `harness` group of negative controls: six `expect_case` controls that must be reported as SURVIVED (three times: a harmless edit, a kill on the wrong check, and a T13.4 control that only breaks T13.2), ANCHOR MISS, MODES DIFFER (with `MUTANT_FAULT=fast-pass`, which makes fast mode pass everything) and CONTROL FAIL; and nine controls that break fast mode and must be killed by the T14 case they break. `tests/meta/test-mutants-harness.sh` runs that group with 1 and 4 jobs and requires the same results in the same order, and once more with `ASCENT_MUTANT_RAW=1`, which must fail and count every kind of result right. `make test-harness` runs the two slow meta tests; CI runs them in their own job.
8. **A weekly full run.** CI runs every group in full mode once a week and on request (`workflow_dispatch`), with the 40-minute timeout; fast runs on pull requests and `main` get 15 minutes once two runs show every group under 10. The totals line names the mode, so a full run can be told from a fast one. The repository is public, and GitHub pauses a scheduled workflow after 60 days without activity in the repository: a pause shows on the Actions tab, and a manual run with `mode: full` covers the gap.
9. **Review hardening (2026-10-29).** An independent review, checked by the finding verifier, confirmed 16 findings, all fixed before release: baselines for T14 and for the behavior tests in fast mode, per-case T14 results (`T14.G<n>`) so a T14 control is killed only by the case it breaks, a control for the fast-mode label check (P373), a raw run that tests the totals, the job list instead of `kill -0`, interrupts that stop every control, `--help`, and `MODE` and `JOBS` taken from the make command line only.

## Alternatives considered

- **Stop at the first failure inside each test file**, through each test's `bad()`. Rejected in ADR-017; the runner covers every plugin from one place.
- **Read the test's output through a pipe** (`… | awk '/^FAIL/ { exit }'`). Rejected: SIGPIPE under `set -e` and `pipefail` is the failure PR #60 fixed, and a silent passing test would run on until it wrote again.
- **Trust the full rerun's verdict when the modes disagree.** Rejected by the operator on 2026-10-29: it would hide a bug in fast mode. The full report stays available.
- **`xargs -P` or GNU `parallel` for the controls.** Rejected: controls set variables for one call (`T13_SELFTEST=1 plugin_case …`) and groups change `T11_FORCE` as they go, which a background job inherits and a separate process does not; GNU `parallel` is not on macOS.
- **Parallel `core` group.** Not worth it: it takes under a minute and has its own runner.

## Consequences

- A control that is killed costs one section of the gate, usually one behavior test up to its first FAIL line, on one of several cores. A survivor costs both modes.
- The weekly full run and the guards are what keep fast mode honest; a new gate section must keep to its own variables, and a new behavior test must fail when it prints a FAIL line, or the gate says so.
- Gate checks are now T1 to T14; `make test-plugins` reports one more check.
- The harness is about 150 lines longer, and its reports carry two runs for a survivor.

## Cost implications

- **Build:** one release, v0.4.10; no plugin version changes.
- **CI:** one more job per platform for the harness self-tests (a few minutes), and a weekly full run (about the old cost, once a week). Every pull request saves most of its negative-control time.
- **Risk:** a fault in fast mode that the guards miss would report a gap as killed until the weekly full run reports that control as a survivor.
