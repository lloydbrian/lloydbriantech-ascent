# ADR-030: A checker's exit 2 is a usage error only when it says so, and the harness refuses both of its test-only variables

**Status:** Accepted
**Date:** 2026-11-23 (America/New_York)
**Decider:** lloydbriantech

## Context

v0.4.25 left three gaps, found while it was built and released.

**An exit 2 was always read as a usage error.** `check-audit.sh` reads an exit 2 from a floor checker as a usage error: `GOV-S2` Medium, GO WITH CONDITIONS ([ADR-028](ADR-028-auditability-and-the-governance-conductor.md)). [ADR-029](ADR-029-learned-order-one-baseline-and-gov-l1-severity.md) decision 5 kept that carve-out: a checker that stops without finishing is High, "any exit but 0, 1 or 2". But awk also exits 2 on a runtime error (`division by zero`, a fatal error), and bash exits 2 on a syntax error. A checker that crashes that way gave conditions, where a checker that stops without finishing has not passed. That has been so since `ascent-governance` 0.1.0.

**`MUTANT_FAULT` was not refused.** The harness refuses `MUTANT_FULL` from the environment and on any line outside the harness group (ADR-029 decision 4), because only the harness group's own controls may set it. `MUTANT_FAULT`, the harness's other test-only variable, breaks the harness on purpose: `copy-fail` makes every copy fail, and `fast-pass` makes fast mode pass every control. Set from the environment, it made a run that is not a real run. The run failed loudly (COPY FAIL, or MODES DIFFER), but the variable was not refused.

**The weekly full-mode run.** It went red on 2 and 16 November 2026. That looked like a timeout, but it was not one. Each red macOS job was never started: GitHub said "The job was not acquired by Runner of type hosted even after multiple attempts", with notices about macOS arm64 capacity, and no step ran. The 9 November run passed, with its longest control job at 27 of its 40 minutes ([ADR-018](ADR-018-fast-negative-control-harness.md) decision 8).

None of those runs had the governance controls, which reached `main` on 20 November with v0.4.24. Full mode was measured on 2026-11-22, on a copy of the v0.4.25 tree, and on 2026-11-23, on a copy of this release's tree:
- two whole groups, three jobs each (the macOS runner's CPUs);
- one control from every other group but the harness group, in full mode, four jobs at a time: 47 controls, all killed;
- the harness group whole, three jobs at a time: 46 controls, all killed, in 79 minutes.

A governance control took about 157 seconds in full mode, against 19 to 124 for the other groups' controls. In full mode the behavior tests run behind most of the gate, and the governance controls are caught by them. A harness-group control took about 338 seconds: these controls edit the harness and the gate, so each one reruns the whole gate, every plugin's behavior tests included. On PR #80, CI took about 1.9 times the local fast-mode time for both measured groups. Predicted macOS CI time is the seconds a control takes, × the controls in the group, ÷ 3 jobs, × 1.9:

| Group | Controls | Predicted macOS CI, full mode |
|---|---|---|
| `harness` | 46 | about 147 min (measured locally: 79 min) |
| `ascent-governance-adapters` | 56 | about 95 min |
| `ascent-governance-rules` | 53 | about 87 min |
| `ascent-governance` | 49 | about 84 min (measured locally: 42 min) |
| `ascent-governance-reviews-1`, `ascent-governance-ladder` | 38, 36 | 61–63 min |
| `ascent-ux`, `ascent-governance-views-1`, `ascent-governance-waivers` | 113, 32, 30 | 51–55 min |
| `ascent-docs`, `ascent-ux-resilience` | 112, 85 | 42–46 min |
| five more groups | | 32–40 min |
| the other 32 groups | | under 30 min |

This release adds controls to three of those groups. At its counts, `ascent-governance-adapters` (60) is about 102 minutes, `ascent-governance` (55) about 94 and `ascent-governance-rules` (55) about 91, before its slower test cases. Eleven groups would run past 40 minutes, the harness group the slowest. The whole run is about 1,460 macOS job-minutes.

## Decision

1. **An exit 2 is a usage error only when the checker says so** (`ascent-governance` 0.2.1).
   - Exit 2 is `GOV-S2` Medium only when the first line of the checker's output is its own message: `<name>: …`, or its usage line, `Usage: <name>.sh …`. NAME is the checker's file name without `.sh`.
   - Any other exit 2 is a checker that stopped without finishing: `GOV-L1` High, NO-GO, "its checker exited 2 without finishing (<first line>)".
   - For a checker run once per record (`ascent-delivery/check-acceptance`), an exit 2 without its own message ranks High, like any crash. A record with a real usage error is still listed apart, and never hides a failure.
   - The nine checkers in `lib/adapters.tsv` all follow the convention. Their 49 exit-2 sites, two of them in a library one of them calls, print `<name>: …` or their usage line first, with nothing printed before. A behavior test runs every checker the table names with an unknown option, and with a bad value for each option the table gives it, and requires its own message first whenever it exits 2. The list comes from the table, so a checker added later is held to the rule from the day it is added.
   - The rule assumes the floor's checkers are ASCENT's own scripts. Such a script reads a tool's result file; it does not run the tool. Promptfoo, for one, exits 100 when its tests fail, which the floor would read as a crash.

   This refines ADR-029 decision 5.
2. **The harness refuses `MUTANT_FAULT` as it refuses `MUTANT_FULL`.**
   - A value from the environment stops the run with exit 2 before any control: `test-mutants: MUTANT_FAULT is set in the environment; only the harness group's own controls may set it`.
   - So does any line outside the harness group that sets it: a prefix, a line of its own, an export. That message names the variable, the control and the group.
   - The harness group's own controls, P362 and P611, keep working.

   This extends ADR-029 decision 4.
3. **The jobs GitHub never started are explained where an operator looks.** A comment beside the weekly schedule in `validate-skills.yml` quotes GitHub's message. It says the job never started, which is runner capacity and not a failure of the job, and gives `gh run rerun <run id> --failed`, which reruns the run's failed jobs, those among them. Nothing reruns them automatically.
4. **Full mode gets 150 minutes a control job, and the harness group 240.** Fast mode keeps 25. This refines ADR-018 decision 8's 40 minutes.
   - 150 leaves about 50 minutes above the slowest other group at this release's counts, for estimation error and growth.
   - The harness group is predicted at about 147 minutes, so 150 would leave it nothing. The operator chose 240 for it on 2026-11-23, which leaves about 90. GitHub allows 360.
   - The groups stay as they are. Making the harness group cheaper is a decision for a later release.
   - After each release tag, the operator dispatches a full-mode run on `main`. Claude reports each job's time from that run, and a job over 120 minutes is split, or made cheaper, in a later release. The harness group is the first.

**Earlier decisions this amends.** Their text and status stay as they are:
- ADR-018 decision 8: the weekly run's limit, 40 → 150 minutes, and 240 for the harness group;
- ADR-029 decision 4: the refusal covers `MUTANT_FAULT` too;
- ADR-029 decision 5: exit 2 is a usage error only with the checker's own message.

## Alternatives considered

- **Every exit 2 is High.** Rejected: a bad contract value, a real usage error, would become NO-GO, which reverses `GOV-S2`.
- **A distinct exit code for usage errors in all nine checkers.** Rejected: six plugins would change for one rule, and every future checker would need to know it.
- **Split every group predicted over 30 minutes.** Rejected: 15 groups would split, adding about 40 jobs to every pull request, for a run made once a week.
- **Keep 150 for the harness group too.** Rejected: its prediction leaves no margin, and a job cut off at its limit fails every week.
- **Split the harness group now.** Rejected: its name is read by the refusal of both test-only variables, by G19's tests and by the CI scope, so a split needs new harness code, tests and controls.
- **Shard full mode only, into jobs that each fit 40 minutes.** Rejected: it needs new harness code, tests and controls. It would also mean about 100 macOS jobs a week, each exposed to the capacity failures decision 3 explains.
- **Make full mode cheaper by running each control's own tests first, as fast mode does.** Rejected here: full mode is the check on fast mode and ignores the order by design (ADR-029). Changing that is a decision for its own release.
- **Move the weekly run to a quieter time, or add an automatic rerun job.** Rejected: there is no evidence that the time helps, and a rerun job needs write permissions in CI.

## Consequences

- **A crashing checker blocks the launch.** A project's CI job that stayed green with conditions when a checker crashed with exit 2 now goes red. This is a behavior change in a released plugin: `ascent-governance` 0.2.0 → 0.2.1.
- **A real usage error still gives conditions.** A checker refusing the contract's values with its own message is still `GOV-S2` Medium.
- **A known limit, pinned by a test.** Only the first line is read. A crash after a line that starts with the checker's name would still read as a usage error. No adapted checker prints such a line before its checks: a `<name>: ` line outside a usage error is only the end-of-run summary. The `l1-crash-after-summary` case pins the current reading, so a change to it is deliberate.
- **No checker changes.** No exit-2 site falls outside the convention, so none is rated High by the rule.
- **A test-only variable cannot make a real run.** Neither variable can reach a real run, from the environment or from a control line.
- **The weekly run takes longer.** It takes 4 to 5 hours of elapsed time instead of failing jobs at 40 minutes, the harness job alone about 2.5 hours. A pull request's macOS jobs queue behind it meanwhile.
- **Negative controls.** P1698–P1708 and P1711 break the first-line rule, its per-record use, a real checker's messages for an unknown option and for a bad value, and the documents that state the rule. P1709 and P1710 break the `MUTANT_FAULT` refusal. P1623, P1366, P1612, P1688 and P1693 are re-anchored, with their intent unchanged.

## Cost implications

- **Time:**
  - about 1,460 macOS job-minutes for each full-mode run, weekly and after each release;
  - one dispatched run and its report in each release runbook.
- **Complexity:**
  - a six-line helper and two branches in `check-audit.sh`;
  - a second environment check and a wider line pattern in the harness;
  - 8 cases in `test-check-audit.sh`, 4 in `test-adapters.sh` (two run every adapted checker), 2 in `test-governance-rules.sh` and 6 in `test-gate-fast.sh`;
  - 14 new controls.
- **Future flexibility:** a new floor checker must print its own name, or its usage line, first on a usage error, and the behavior test says so the day it is added to the table.
- **Money:** none. The repository is public, and GitHub's hosted runners cost nothing for it.
