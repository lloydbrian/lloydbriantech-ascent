# ADR-021: Load-test alignment and mutation evidence: QA-L1–L5 and QA-M1–M4, read statically

**Status:** Accepted
**Date:** 2026-11-01 (America/New_York)
**Decider:** lloydbriantech

## Context

[ADR-014](ADR-014-testing-ownership-and-dependency-scan.md) decision 3 left two items of the test strategy for `ascent-quality` 0.2.0: a load test whose thresholds match the latency and throughput targets that `ascent-architecture` sets (`p95_latency_ms` and `peak_rps` in `architecture.quality_targets`, read and never copied), and mutation evidence, which shows the tests fail when the code is broken. [ADR-019](ADR-019-quality-plugin-rules.md) built 0.1.0 as static scripts that never run a test. ADR-014 named the items but left these questions to the build:

- **Which load-test tools, and what does "aligned" mean?** A threshold can sit in a script (k6), a YAML file (Artillery) or Python code (Locust), and a load can be set as a request rate or as a number of virtual users.
- **What counts as mutation evidence?** A tool can be configured and never run; a score can be committed once and go stale.
- **How severe is each gap?** ADR-014 decision 5 makes every gap the maturity target requires Low unless waived; a load test that asserts a looser latency than the target is a defect in what exists, not a gap.

## Decision

1. **Three load-test tools, found by content.** A k6 script imports `k6`; an Artillery file is YAML with top-level `config:` and `scenarios:`; a Locust file imports `locust`. They are found anywhere under the scanned paths, so the contract needs no load-test key. Gatling and JMeter are not read; with a target set, a project using only them fails QA-L1, and the review reads its scripts and says what they check. A k6 scenario is read on its own: its rate counts only in an arrival-rate executor, per its own `timeUnit`.
2. **Aligned means as strict as the target, or stricter.** The p95 threshold is the target or lower, and the load reaches `peak_rps` or more. A tighter threshold still proves the target, so ADR-014's "equal" is read as "no looser". k6's untagged `http_req_duration` threshold is the overall one; with only tagged thresholds the loosest is used. A load set in virtual users has no request rate a static check can read: that is a NOTE and the skill reads the script, never a pass.
3. **Mutation evidence is configuration, CI and a current score in the repository.** A tool is configured (Stryker, mutmut, PIT, go-mutesting or gremlins); its break threshold is at or above `quality.mutation.min_score` where the tool has one (Stryker `thresholds.break`, PIT `mutationThreshold`, gremlins efficacy); CI runs it; and a report in the repository (Stryker `mutation.json`, PIT `mutations.xml`, or a text summary with a mutation score or test efficacy) shows at least `min_score`, dated within `quality.mutation.max_age_days`. A report is dated by a date in its path, or else by the author date of its last commit (`git log`, read-only, run from the repository root with bare-repository discovery and signature checks switched off, so the repository's own files cannot make git run a program); a shallow clone dates nothing. A report that cannot be used beside a usable one is a NOTE. Claude never runs a mutation tool: a run changes the code under test and takes minutes to hours.
4. **Nine rules, rated only from the `qa-severity` table:**

   | Rule | Severity | Checks |
   |---|---|---|
   | QA-L1 | Medium | a load-test script exists when the contract sets `p95_latency_ms` or `peak_rps` |
   | QA-L2 | Medium | a load test's p95 latency threshold is no looser than `p95_latency_ms` |
   | QA-L3 | Medium | a load test's request rate reaches `peak_rps` |
   | QA-L4 | Low | a load test sets an error-rate threshold |
   | QA-L5 | Low | a CI step, a make target or a runbook runs the load test |
   | QA-M1 | Medium | a mutation tool is configured |
   | QA-M2 | Medium | the tool's break threshold is at or above `min_score` |
   | QA-M3 | Low | a CI step runs the mutation tool |
   | QA-M4 | Medium | the newest usable report in the repository scores at least `min_score` and is no older than `max_age_days` |

   A missing test and a defect in what exists are both Medium where the target is shown not to be checked (L1–L3, M1, M2, M4): a load test that asserts 2 s against a 500 ms target proves nothing about the target. Where the evidence exists but its use is unproven (L4, L5, M3), the gap is Low.
5. **Maturity.** `check-test-evidence.sh --maturity` follows `quality.maturity_target`: prototype requires none, standard requires QA-L1, QA-L2 and QA-M1, enterprise all nine. With no target given, QA-L1–L3 are N/A and the review reports the "unmeasured" Low row; QA-L4 and QA-L5 still apply to any load script found.
6. **One new script and one new skill.** `check-test-evidence.sh` (bash and awk, static) and the `test-evidence` skill sit beside the two 0.1.0 scripts and skills; `quality-review` gains the load and mutation lenses. CI steps are followed through make recipes and package scripts as in QA-I2, so that code moves from `check-test-inventory.awk` to `qa-common.awk`, unchanged.

## Alternatives considered

- **Run the load test or the mutation tool.** Rejected. A load test reaches a live environment and a mutation run changes the code under test; ADR-014 decision 1 gives anything run to the operator.
- **k6 only.** Rejected by the operator: most repositories would be N/A.
- **Gatling and JMeter too.** Rejected for now: a Scala or Java DSL and JMeter XML would double the parser and its controls for tools no trial repository uses.
- **Thresholds equal to the targets, exactly.** Rejected. A stricter threshold proves the target; failing it would push teams to loosen tests.
- **Config and CI only for mutation.** Rejected by the operator: it gives no dated evidence of a score.
- **A committed report only.** Rejected by the operator: projects would have to commit reports before any credit.
- **A contract key listing load scripts.** Rejected: tools are found by content, so a key would only drift.

## Consequences

- A project with latency and throughput targets learns whether any test checks them, and how far its thresholds sit from them.
- A virtual-user load is never credited against `peak_rps`; the skill reads the script and the operator may switch to an arrival-rate executor.
- A mutation report in the repository is a new artifact for teams that adopt mutation testing; teams that do not fail QA-M1 (Medium) at standard and enterprise maturity unless a waiver ADR covers it, and QA-M2–M4 are then N/A.
- Moving the make and package-script following into `qa-common.awk` re-points four negative controls of `ascent-quality-inventory` to the shared file.
- **(uncertain)** Load profiles written in code paths the check cannot read (a rate computed at runtime) are NOTEs, so a script may need reading.

## Cost implications

- About 550 plugin lines, 400 test lines and some 70 negative controls in two new groups, `ascent-quality-load` and `ascent-quality-mutation`, each inside the 15-minute CI job limit.
- **Recurring:** keep the tool patterns current as k6, Artillery, Locust and the mutation tools change their configuration formats.
- **Runtime:** bash, awk and a read-only `git log`. Nothing is installed or run.
