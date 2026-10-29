# ADR-017: Faster negative controls in v0.4.10; ascent-quality moves to v0.4.11 and ascent-ops 0.3.0 to v0.4.12

**Status:** Accepted (scope and release order; the design details are settled when it is built)
**Date:** 2026-10-28 (America/New_York)
**Decider:** lloydbriantech

## Context

Every negative control (`plugin_case` in `make/test-mutants.sh`, ADR-008) copies the repository, applies one edit and runs the whole plugin gate, `make/test-plugins.sh`, on the copy. The control is killed when its named check fails. Measured on 2026-10-28, with the v0.4.9 tree:

- One control's gate run takes 20.8 seconds locally (one awk). T11, the plugin's behavior tests, takes about 15 of them; the other checks about 5.
- With control P265 applied, `test-check-dependencies.sh` prints its first failure after 0.14 seconds and runs on for 8.6. The harness only needs to know whether the named check fails.
- On CI a control takes about 9 seconds on Ubuntu and 23 to 50 seconds on macOS, depending on the run. On the first CI run of PR #59, five macOS jobs ran past the 15-minute job timeout; v0.4.9 raised it to 40 minutes and split `ascent-security-regressions` into three groups.
- Controls P246, P255 and P265 survived now and then, on main after the v0.4.9 merge and on PR #59. A survivor's report said only "failed, but not on T11", and finding the cause took reading the gate's raw output: T11 quoted the first FAIL lines through `grep | head`, and under `set -e` and `pipefail` SIGPIPE ended the gate before T11 printed. PR #60 fixed it, and control P358 guards it.

`ascent-quality` 0.1.0 adds a plugin with its own behavior tests and controls, so the cost grows with every release. [ADR-014](ADR-014-testing-ownership-and-dependency-scan.md) decision 6 and [ADR-015](ADR-015-ownership-registry-and-gate.md) decision 9 put `ascent-quality` 0.1.0 in v0.4.10 and `ascent-ops` 0.3.0 in v0.4.11. Both ADRs are immutable.

## Decision

1. **v0.4.10 makes the negative controls faster.** It is framework tooling: no plugin version changes.
2. **Three changes, verdicts unchanged.** A control is still killed only when its named check fails, and still survives otherwise.
   - **Stop at the first failure.** When the harness asks for it, T11 stops a behavior test at its first `FAIL` line. This lives in one place, the T11 runner in `make/test-plugins.sh`, not in each test file.
   - **Run only the named check.** A control runs the check it names and no other. `P00-baseline` still runs the full gate.
   - **Run controls in parallel** inside each CI job, one per core, each on its own copy as today.
3. **A survivor reruns in full mode**, so its report names every check that failed and the behavior test's full output. The intermittent survivors fixed in PR #60 showed that a short report is not enough to diagnose a survivor: the cause was found only in the gate's raw output.
4. **The fast harness has its own negative controls**: a control the tests do not catch is still reported as SURVIVED, an anchor miss as ANCHOR MISS, and a broken baseline as CONTROL FAIL.
5. **Target:** every group under 10 minutes on a macOS runner. The negative-control job timeout returns to 15 minutes once two CI runs show it.
6. **Release order:** v0.4.10 this harness; v0.4.11 `ascent-quality` 0.1.0; v0.4.12 `ascent-ops` 0.3.0. The last two may still swap, as ADR-014 allows. This replaces the version numbers in ADR-014 decision 6 and ADR-015 decision 9, not their order.

## Alternatives considered

- **Keep raising timeouts and splitting groups.** Rejected as the long-term answer. It holds for v0.4.9 but every plugin adds controls, and the macOS time per control already varies by a factor of two between runs.
- **Ship the harness inside v0.4.10 with `ascent-quality` 0.1.0.** Rejected by the operator on 2026-10-28: one change per release, and `ascent-quality` starts on the fast harness.
- **Stop at the first failure inside each test file.** Rejected. It means editing every plugin's `bad()` and keeping them in step; one place in the T11 runner covers every plugin, current and future.
- **Run fewer controls on macOS.** Rejected. ADR-008 runs every control on both platforms because the scripts must work on both awk and sed families.

## Consequences

- A typical control should take a few seconds instead of 20 to 50, so CI finishes sooner and the macOS jobs stop running near their timeout.
- The harness gains two modes, fast and full. Contributors read a survivor's report from the full rerun.
- `ascent-quality` 0.1.0 and `ascent-ops` 0.3.0 each move one version later. The reserved rows in `OWNERSHIP.md`, the roadmap and the CHANGELOG plan carry the new numbers; ADR-014 and ADR-015 keep the old ones, and this ADR records the change.

## Cost implications

- **Build:** about 100 lines in `make/test-mutants.sh` and `make/test-plugins.sh`, plus the harness's own controls. One release.
- **Delay:** `ascent-quality` 0.1.0 ships one release later.
- **Saving:** CI minutes on every pull request from v0.4.10 on, most of them on macOS runners. The repository is public, so the minutes are free, but the wait is not.
- **Risk:** a fast mode that reports a survivor as killed would hide gaps in the tests. Decision 4's controls exist to catch exactly that.
