# ADR-029: Learned test order, one baseline and scoped self-test reruns; GOV-L1 follows the checker's findings

**Status:** Accepted
**Date:** 2026-11-20 (America/New_York)
**Decider:** lloydbriantech

## Context

**The negative controls made CI slow enough to break it.** v0.4.24's first pull request run timed out on four macOS jobs. The fix split the governance controls into 14 groups and gave the harness self-test 75 minutes, and the release run took 2 hours 4 minutes. Measured on v0.4.24:

- **The governance controls were most of the time.** 169 of 314 macOS control job-minutes (54%), and 31,033 of 64,906 local control-seconds (48%): 380 controls averaging 82 seconds, against 23 for the other plugins.
- **The test that caught a control often ran last.** Fast mode stops T11 at the first failing test, and runs first the tests that name the edited file ([ADR-018](ADR-018-fast-negative-control-harness.md), [ADR-025](ADR-025-faster-local-verification.md) decision 2). 152 governance controls edit `scripts/check-audit.sh`, and 7 of the 8 governance test files name it, so the order was alphabetical: a control caught by `test-waivers` first ran five whole test files.
- **Two baselines ran the same suite.** In fast mode every group ran `P00-baseline` (the run's checks in normal mode, T11 included) and `P00-fast-baseline` (T11 in fast mode). For a T11 group both ran every behavior test of the group's plugins, about 7 minutes of control time per governance job, and the split into 14 groups multiplied them.
- **The self-test reran the whole gate.** It runs the harness group three times. Four of its controls are survivors or disagreements by design (P359, P360, P362, P373), so each reran the whole gate in full mode every time: 55.4 minutes on macOS.

**GOV-L1 made every failing check a NO-GO.** v0.4.24 ([ADR-028](ADR-028-auditability-and-the-governance-conductor.md)) rated any failing check on an environment's floor High, even when the checker found only Medium or Low problems. On the trial, one `.dockerignore` line written wrongly gave NO-GO at local, and three of seven failing checks in one repository had only Low findings, each a NO-GO. The operator expected GO WITH CONDITIONS for those, so that the builder can address them without being blocked.

## Decision

1. **Learned order.**
   - When fast mode kills a T11 control, the harness records the catching test: the first `<test> failed:` entry of the gate's T11 FAIL line, or nothing when the line names no test (a missing `hooks.json`, a script no test exercises, a test that printed FAIL lines but exited 0). The times file (ADR-025 decision 1) gains a seventh column, `caught by`.
   - `make/mutant-order.tsv` is committed and generated: one row per T11 control that a test caught, its id and that test, sorted by id. `make mutant-order FROM=<times file>` (`make/mutant-order.sh`) merges a times file into it. A control the file shows killed with a catching test gets that row; every other control keeps its row; rows of controls that no longer exist are removed. A times file without the `caught by` column is refused with exit 2, and the file is left as it was. Each release's file comes from that release's own final full run: for v0.4.25 it is generated in the working copy before the pull request, and from then on a step of the release runbook runs it.
   - `make/test-plugins.sh` reads `ASCENT_T11_LEAD=<test>` and, in fast mode only, moves that test ahead of the tiers of ADR-025 decision 2, which keep their order behind it. A name that matches no test changes nothing; normal mode ignores it. The harness sets it for each control from the order file.
   - **The order cannot change a verdict.** T11 fails if any test fails, and each test runs in its own process group and `TMPDIR` (ADR-018); the lead changes how soon a failure is known, never whether. A missing, wrong or stale row costs time only. The summary prints `order    <n> of <m> T11 controls led by the test that caught them; <k> stale rows ignored`; a stale row is never fatal, so renaming a test is not a CI failure.
   - The order file is not part of a control's cache key (ADR-025 decision 4), and `make/gate-scope.sh` keeps treating it as part of `make/*`, so a change to it runs everything.
2. **One test-suite baseline per group.** In fast mode, when the run has T11 controls, `P00-fast-baseline` is the only baseline that runs the behavior tests, and `P00-baseline` runs the run's other checks in normal mode; when T11 is the run's only check, `P00-baseline` is not launched, so an empty `ASCENT_ONLY` (the whole gate) is never passed. Full mode keeps its single whole-gate baseline. A fast-mode kill is judged against its exact counterpart; an unmodified tree that failed T11 only in normal mode would fail a survivor's full-mode rerun and be reported as MODES DIFFER. P835 keeps its id and intent and now fails through the fast-mode baseline. `make/test-mutants.sh --baselines` prints the baselines a run would launch, and stops.
3. **The governance groups stay as they are.** CI runs the same groups in full mode every week, where a merged group of governance controls would run far past its job's limit.
4. **The self-test's own reruns are scoped.** A control in `mutant_group harness` may declare `MUTANT_FULL=<sections>`, comma-separated, the sections its full-mode rerun runs instead of the whole gate: P359 `T5`, P360 `T10,T11` (its edit fails T10 in the whole gate, which keeps the "failed, but not on T11" report it exists to exercise), P362 `T11`, P373 `T13`. The harness refuses `MUTANT_FULL` with exit 2 before any control runs when it comes from the environment, or when any line outside the harness group sets it (a prefix, a line of its own, an export), so a real control's full-mode rerun is always the whole gate.
5. **GOV-L1 follows the checker's findings** (`ascent-governance` 0.2.0). When a check on the floor fails, GOV-L1's severity is the most severe finding the checker printed:
   - High when any FAIL line is High, when no FAIL line was printed, or when one's severity is not High, Medium or Low; Medium when the most severe is Medium; Low when every one is Low;
   - a checker that stops without finishing (any exit but 0, 1 or 2) is High, as before;
   - a checker run once per record (`ascent-delivery/check-acceptance`) takes the most severe finding across every failing record, cited from the first record that has it;
   - the findings GOV-L1 cites are the most severe first, and a finding of no known severity ranks with High, so the message matches the severity.

   A Medium or Low GOV-L1 gives GO WITH CONDITIONS at every environment, prod included, where the person who signs the launch record sees each condition. The severity table in `launch-readiness` and its copy in `governance-conductor` give GOV-L1 three rows, and R2 of `test-governance-rules.sh` checks the computed severity.
   - Every floor checker prints `FAIL  <rule>  <severity>  …`. `ascent-delivery/check-acceptance` rates every finding High, so an acceptance failure stays a NO-GO; the contract's gate command (`delivery/gate`) prints no severity and stays High. No floor checker prints a FAIL line without a severity.
   - This repository's own T17 stays strict: it fails on any GOV failure except a waiver due soon (ADR-028 decision 14).

**Earlier decisions this amends.** Their text and status stay as they are, as ADR-025 left ADR-018's:

- ADR-018: in fast mode the behavior tests run in one baseline, not two, and T11 runs the lead test first;
- ADR-025 decision 1 (the times file has a seventh column, `caught by`) and decision 2 (the lead runs ahead of the path and file-name tiers);
- ADR-028 decision 7: a failing check fails a project's CI only with a High finding or when its checker stops without finishing; a check that fails with only Medium or Low findings is listed in the job summary as a condition, and the job stays green.

## Alternatives considered

- **B, a declared order: each control names its catching test.** The same speed, but about 370 governance declarations to edit by hand, and every new control's author would have to find its catching test. Rejected.
- **C, a faster `check-audit.sh`, with fewer processes per run.** It would help users too, but it meant reworking a script released the same day, for perhaps twice the speed. Rejected for now.
- **Merging the 14 governance groups into about five.** It would cut the per-group baselines further, but each governance control runs the whole gate in the weekly full-mode run, about 4 minutes on macOS, so a merged group would take about 100 minutes against that job's 40-minute limit. Rejected (decision 3).
- **Governance controls on Linux only, or more CI groups.** Rejected: platform differences in controls are real (v0.4.22 made the controls portable to GNU sed), and more groups is what multiplied the baselines.
- **Dropping the second awk or bash 3.2, or the kill cache in CI.** Rejected, as ADR-025 rejected them: they find real bugs, and CI stays the independent check.
- **Failing the run on a stale order row.** Rejected: a file that cannot change a verdict would make renaming a test a CI failure.
- **GOV-L1 Medium and Low at local and beta, High at prod.** Rejected: the same rule at every environment is simpler to read, and at prod a person signs the conditions.

## Consequences

- **Faster controls, the same verdicts.** Measured locally on `ascent-governance-views-1`, three controls at a time with both baselines still in: control time 1,197 s → 351 s and wall time 8:29 → 3:51 once the order was learned, every control killed both times; 31 of its 32 controls were caught by `test-views`, 1 by `test-check-audit`. On `ascent-architecture` (ten at a time) 199 s → 178 s, 32 of 33 controls led (P42 removes the tests, so no test catches it).
- **Half the governance baselines.** 14 runs of the governance suite per CI run instead of 28.
- **The order file needs refreshing.** It is regenerated once per release from the final full run. A control added between releases runs in the old order until then, which costs time only.
- **A new trust rule, kept narrow.** The lead must never be able to change a verdict; the self-test proves that a lead naming a passing test gives the same verdict, and controls P1668–P1680, P1690, P1696 and P1697 break the lead, the order script and the baselines. `MUTANT_FULL` is confined to the harness group by a refusal that P1681 and P1691–P1693 weaken.
- **GOV-L1 gives conditions, not a block, for Medium and Low findings.** A builder sees every finding and can launch locally or to beta while addressing them; a High finding or a checker that did not finish still blocks. Controls P1682–P1689, P1694 and P1695 hold the rule, its citations, the severity table and the README.
- **A behavior change in a released plugin:** `ascent-governance` 0.1.0 → 0.2.0. A project's CI job that went red on a Medium-only failure now stays green and lists it.

## Cost implications

- **Time:** governance CI control time roughly halved, estimated from the measured gains, and confirmed on the pull request's run; one `make mutant-order` step per release runbook.
- **Compute:** one small awk per run to read the order file, and one per killed control to read its catching test.
- **Complexity:** about 120 lines in `make/mutant-order.sh`, about 100 in the harness, ten in the gate and twenty in `check-audit.sh`; 32 cases in `test-gate-fast.sh`, the order and baseline cases in `test-mutants-harness.sh`, 36 governance cases; 30 controls (P1668–P1697); and a generated file of 1,465 rows for v0.4.25, one per T11 control a test caught (16 of the 1,481 are caught by no test).
- **Future flexibility:** the order applies to T11 only; another check that gains several tests can use the same lead.
- **Money:** none.
