# ADR-025: Faster local verification: timings, the right test first, cheaper rules tests and a kill cache

**Status:** Accepted
**Date:** 2026-11-16 (America/New_York)
**Decider:** lloydbriantech

## Context

Building v0.4.20 took two full runs of `make test-mutants`, each about 55 minutes on a 10-core machine. The second run followed a two-line fix (the skills' frontmatter versions) that could not change any control's verdict, yet all 977 controls ran again. Measured from that run's own timings:

- **T11 controls use 93% of the time.** 757 controls, about 16,300 of 17,600 control-seconds. A T11 control reruns its plugin's behavior tests on a fresh copy until one fails.
- **The `ascent-ops` and `ascent-quality` controls are the slowest**, 40–53 seconds each against 4–8 for `ascent-architecture`, `ascent-ux` and `ascent-delivery`.
- **One rules test was most of that.** `test-ops-rules.sh` took 17 seconds, 14 of them in R13 (every script check id in the severity table), which started several `grep`, `tr` and `cut` processes for each pair of id and table row.
- **"Run the edited file's tests first" did nothing for documents.** [ADR-018](ADR-018-fast-negative-control-harness.md) runs first the tests that name the edited file, by its file name. Every plugin has several `SKILL.md` files, and every rules test names `SKILL.md`, so a control on a skill ran the tests in name order.
- **The summary showed the three slowest controls and nothing else.** There was no way to see where a run's time went without reading the harness's temporary files.
- **The floor of a full run is the baseline.** The unmodified copy runs the whole gate in about eight minutes; no amount of parallel controls finishes a full run sooner.

CI is not the problem: since [ADR-023](ADR-023-ci-runs-what-a-change-can-affect.md) it runs only the controls a change can affect, in parallel jobs. The time lost is local: verifying a release, and verifying again after each fix.

## Decision

1. **A timing report.** The summary adds two lines, the three checks and the three groups that took the most time, each with its total and its number of controls. `ASCENT_MUTANT_TIMES=<file>` (`make test-mutants TIMES=<file>`) also writes every timed control, slowest first: seconds, status, id, group, check, cached. The baselines are in group and check `baseline`. The notice that the file was written goes to stderr, so a run's results do not depend on it.
2. **The right test first.** `make/test-mutants.sh` passes the edited path relative to its plugin (`skills/recovery-drill/SKILL.md`), not its file name. `make/test-plugins.sh` runs first the tests that name that path, then those that name its file name, then the rest. The order still cannot change a verdict, only how soon it is known. `test-gate-fast.sh` G4 covers both tiers; controls P913 and P914 drop each one, and P368 moves to the new code.
3. **Cheaper rules tests, the same checks.** R13 of `test-ops-rules.sh` becomes one awk pass per script: a row names an id outright (after `(`, `,` or a space, before `,`, `)`, a space or an en dash) or through a range of its letter (`OPS-M1–M4`), and must end with the id's severity, exactly as before. The old and new code were run on the real table and five broken copies of it and printed the same results, under bash 5 and 3.2 and the default awk, gawk and mawk. Controls P915 (a named id at the wrong severity) and P916 (a range shortened) keep it honest. A behavior test that spends its time running the script it tests is left alone: that time is the test.
4. **A kill cache for local reruns.** `ASCENT_MUTANT_CACHE=<dir>` (`make test-mutants CACHE=<dir>`, for example `CACHE=tmp/mutant-cache`) keeps one empty file per killed control, named by a hash of everything that control can read:
   - the control's own declaration (kind, id, check, path, sed expression);
   - its plugin's directory and its behavior tests (`plugins/<p>/`, `tests/plugins/<p>/`);
   - `skills/`, `.claude-plugin/` and `make/test-plugins.sh`;
   - `make/test-mutants.sh` without the other controls' `plugin_case` declarations, so adding a control does not discard every other kill;
   - the bash version, the operating system, and the awk binary.

   A control whose key exists is reported `killed … (cached)` without running, and the summary counts the kills reused. Only kills are kept: a survivor, an anchor miss, a disagreement or a copy failure always runs again. The cache applies only to T11 controls of one plugin. Controls of every plugin, of T13.0 or T14, with a fault or a rebuild, and the `expect_case` controls always run, and full mode ignores the cache and says so. The baselines always run.
5. **Where the cache may be used.** Local reruns only, after a fix, while a release is built. **CI never sets it, and the final run before a release runbook is written runs without it.** That run is the release's evidence, as before.
6. **Verification runs on a frozen copy.** Local verification runs on a copy of the work tree, so the tree can be edited while it runs and a running harness never reads a half-edited script.
7. **Tests.** `tests/meta/test-mutants-harness.sh` checks the times file (one row per control, slowest first, adding up to the summary) and the cache on a copy of the repository: a second run reuses both kills; an edit to another plugin keeps them; an edit to the controls' plugin, its tests or the gate reruns them; and full mode says it ignores the cache.

## Alternatives considered

- **Run fewer controls locally and trust CI for the rest.** Rejected. CI runs what a change can affect, which is the same scope; the local run is how a release is verified before the operator opens the pull request.
- **Cache every verdict, survivors included.** Rejected. A survivor is a finding to fix; rerunning it costs little and keeps it visible.
- **Key the cache on the whole repository.** Rejected: any edit would discard every kill, which is the problem today. Keyed per plugin, a fix to one plugin reruns that plugin's controls only.
- **Key it on the files a control's tests open, traced at run time.** Rejected for now. It would be tighter, but tracing file access is not portable across macOS and Linux shells, and the per-plugin key was checked against the tests: no behavior test reads `docs/` or another plugin's files.
- **Use the cache in CI as well.** Rejected. CI is the independent check; a stale or corrupted cache must never be able to pass a pull request.
- **Drop the bash 3.2 or second-awk runs to save time.** Rejected: they are what keeps the scripts portable, and they found real bugs (v0.4.19).
- **Shorten the baseline.** Not now. It is the floor of a full run, but it is also what proves the unmodified tree passes; a later change can scope it to the controls that actually run.

## Consequences

- A rerun after a fix to one plugin runs that plugin's controls, about a quarter of the total for the largest plugins, plus the baselines. On the `ascent-architecture` group a cached rerun took 11 seconds instead of 28.
- `test-ops-rules.sh` runs in about 2 seconds instead of 17, which every `ascent-ops` T11 control and every gate run gains.
- Every run says where its time went, so the next speed-up can be chosen from measurements.
- The cache adds a trust boundary: a kill can be reused only when nothing in its key changed. A behavior test that starts reading a file outside its plugin, `skills/`, `.claude-plugin/` or `make/test-plugins.sh` must widen the key in the same change; the final uncached run before a release catches anything it misses.
- Cache entries are never removed by the harness. They are empty files in a directory the operator chooses, under `tmp/` (ignored by git), and can be deleted at any time.

## Cost implications

- **Time:** a cached rerun of all the controls is bounded by the baselines (about eight minutes) plus the controls whose inputs changed; a full uncached run still takes its full time, once per release.
- **Compute:** hashing the inputs takes a few seconds per run, once per plugin.
- **Disk:** one empty file per kill, about a thousand.
- **Complexity:** about 40 lines in the harness, seven self-test cases and four controls.
- **Money:** none.
