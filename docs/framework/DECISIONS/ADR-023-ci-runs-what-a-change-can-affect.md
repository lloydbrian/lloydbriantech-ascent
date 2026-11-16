# ADR-023: CI runs what a change can affect

**Status:** Accepted
**Date:** 2026-11-15 (America/New_York)
**Decider:** lloydbriantech

## Context

Every pull request ran every check. PR #73 (v0.4.16, a capability map and documentation) took 61 jobs, 262 runner minutes and 38 minutes of wall time. PR #74 (v0.4.17, a README banner) took about as long, although it changed no plugin, no gate code and no harness code. Measured on run 43713088593:

- the harness self-tests ran on every pull request, 25.6 minutes on macOS for `test-mutants-harness` and 9 to 10 for `test-gate-sections`, though only a change to the harness or the gate can change what they check;
- every negative-control group ran on every pull request: 26 groups on two platforms;
- each group began with a baseline that ran the whole gate, every plugin's behavior tests included: 150 to 230 seconds on macOS per job, about 9,900 seconds across the macOS jobs, whatever the group's controls were judged by. The `ownership` group ran three such baselines;
- T13.0, the ownership checker's fixture tests, ran its 100 cases once per awk, one after another: 300 seconds of the Ubuntu gate's 457, and 158 of macOS's 306;
- a newer push to a pull request left the older run going.

On 2026-11-15 the operator asked for the gates to run "based on applicability" and to be "as efficient as possible … without losing quality", and approved the plan this ADR records.

## Decision

1. **The cheap checks always run, on both platforms.** `make qa`, `make test-skills` and the plugin gate run on every pull request and every push. Without T11 and T13.0 the gate takes seconds, so nothing is gained by scoping it, and every documentation, version and registry check stays on every change.
2. **A scope decides the slow parts.** `make/gate-scope.sh` reads the paths a pull request changes, against the base it merges into, and decides four things:
   - which plugins' behavior tests T11 runs: all, none or a list;
   - whether T13.0 runs;
   - which harness self-tests run;
   - which negative controls run: whole groups, plus the controls selected by id, in one "selected" job.

   The rules are in the script's header and in [ARCHITECTURE](../ARCHITECTURE.md):
   - a plugin's files run that plugin's behavior tests, its groups and `ownership`;
   - the ownership checker or its fixture runs T13.0, `ownership` and `ownership-checker`;
   - the template or `make/mutants.tsv` runs `core`;
   - a harness self-test file runs that self-test;
   - a changed control line in `make/test-mutants.sh` runs that control;
   - documentation and metadata run nothing more;
   - a `FRAMEWORK_VERSION`-only Makefile change runs nothing more.
3. **Every path runs the controls that edit it, and the behavior tests that read it.** The harness lists its controls (`make/test-mutants.sh --list`: group, id, label, kind, file, T11 scope, T13.0 and T14 switches), and the scope selects every control whose file is a changed path, or whose directory holds one. An anchor can only go stale when its file changes, so no control's anchor goes unchecked. A README change runs the three controls that edit the README, not the 61 of the `ownership` group. Some behavior tests also read files outside their plugin. A `$ROOT/<path>` in a plugin's tests marks the path it reads, as `ascent-ops` reads the observability contract and the template. A glob over every plugin's directory reads every `plugins/` path, as `ascent-architecture`'s R12 does. Such a path runs those plugins' T11. Both are found in the tests themselves when the scope runs, so a new test of the same form is covered without a rule change.
4. **Anything else runs everything.** That covers:
   - a change to the gate, the harness, the scope script, a workflow or a make file;
   - a harness line that is not a control, or a changed harness file with no changed line found (the scope fails closed);
   - any path without a rule.

   A push to main, the weekly run and a manual run always run everything (`--full`), so a gap in the rules is found on main the day it merges.
5. **A baseline runs what its controls are judged by.** In fast mode, a run's baseline (P00-baseline) runs only the checks its controls name (`ASCENT_ONLY` now takes a list) and only the behavior tests of the plugins its T11 controls edit (`ASCENT_T11_ONLY` now takes a list). It also runs T13.0 or T14 when a control needs them. The fast-mode T11 baseline runs only when a control is judged by T11. Full mode keeps the whole gate. The `ownership` and `harness` groups lose their extra baselines (P00-ownership-baseline, P00-harness-baseline), which the scoped baseline covers. A fast-mode kill is judged only on the control's own check, so a baseline of those checks is exactly what makes the kill meaningful.
6. **The checker's own controls get a group of their own.** The 13 controls that break `make/check-ownership.sh` or its fixture tests, judged by T13.0, move from `ownership` to `ownership-checker`. They depend on the checker alone, and they were most of the group's time (T13.0 runs 100 fixture cases per control). A plugin or registry change runs `ownership` in about a minute; a checker change runs both.
7. **T13.0 runs its cases in parallel.** The fixture tests split each awk's cases into shards, as many in all as there are cores, each on its own copy of the fixture. The shards' case counts must add up to every case once per awk, or the test fails. Inside the harness, which already runs controls in parallel, T13.0 keeps one shard.
8. **The harness self-tests run when the harness or the gate changes,** and on main and weekly. A changed control line in the `harness` group also runs `test-mutants-harness`, which runs that group whole and counts its results.
9. **A newer push cancels the older run of the same pull request.** Runs on main never cancel each other: each has its own concurrency group.
10. **The same scope runs locally.** `make gate-scope` shows what a branch needs and why, from its changes against `origin/main` (uncommitted and untracked files included), and `make gate-changed` runs it.
11. **The scope cannot be misled by its own run or the operator's settings.** The Scope job writes its explanation outside the checkout, where it would otherwise be an untracked, changed path. Git runs without colour, external diff drivers or other prefixes. If the Scope job fails, the gate runs whole.
12. **The scope is tested like the gate.** T15, a new gate section, runs `tests/meta/test-gate-scope.sh`:
    - fixture changes with all five outputs checked for each, so a rule that runs too little and a rule that runs too much both fail;
    - the repository's own control list: well formed, ids unique, groups as `--groups-json` lists them, every file present.

    The `scope` group's 23 controls each narrow a rule, and T15 must catch them. P832 drops cases from the fixture shards, and P833 to P835 break the list forms of `ASCENT_ONLY` and `ASCENT_T11_ONLY` and the baseline's T11 scope.

## Alternatives considered

- **GitHub's `paths` filters on the workflow.** Rejected. They choose whether the whole workflow runs, not which plugin's tests or which controls, and a skipped required workflow blocks the merge.
- **Scope by group only.** Rejected. A README change would run the 61 controls of `ownership` to check the three that edit the README; selecting by file checks the same anchors in a few seconds.
- **Skip the negative controls on documentation changes altogether.** Rejected. A documentation edit can break a control's anchor (P795 edits the README's alt text), which then fails on main instead of on the pull request.
- **Keep the whole-gate baseline in fast mode.** Rejected. A fast-mode kill is judged only on the control's check; the whole gate cost each group job two to four minutes and caught nothing a scoped baseline misses.
- **A larger runner or more shards per group.** Not needed now; the cost was in running checks a change cannot affect, not in running the needed ones slowly.

## Consequences

- A pull request runs what it can affect. Expected wall times:
  - documentation only: about 2 to 3 minutes;
  - a change like v0.4.17: 6 to 8;
  - one plugin: 6 to 10;
  - a change to the gate or the harness: 25 to 30, as before but with cheaper baselines.
- A gap in the scope rules lets a pull request pass a check it should have run. The full run on main finds it the same day; the rule is then fixed in `make/gate-scope.sh` and T15.
- A new kind of path runs everything until it gets a rule, so the default costs time, never coverage.
- The gate reports T1 to T15. The control figure becomes 904 (P813 to P839 added), and the decision figure 23.
- An independent review before release found two under-selections: behavior tests reading outside their plugin, and a new plugin directory that `ascent-architecture` R12 reads. It also found that the Scope job's own output file would have made every pull request run everything, plus three smaller issues. All six are fixed above and covered by T15 or its controls.
- CI totals count fewer baselines: one per job, plus a fast-mode T11 baseline when a control is judged by T11, instead of two per group plus two.

## Cost implications

- **Build:** one release, v0.4.18; tooling only, no plugin version changes.
- **CI:** one small scope job (Ubuntu, under a minute) on every run. Pull requests save most of their runner minutes; the full runs on main and weekly cost less than before, because each group's baseline is smaller.
- **Risk:** the scope is a new place for a mistake. It is mitigated by the full run on every push to main, by T15 and its controls, and by the rule that unknown paths run everything.
