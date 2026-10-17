# ADR-008: Portable skill tests and named negative controls

**Status:** Proposed
**Date:** 2026-10-17 (America/New_York)
**Decider:** lloydbriantech

## Context

The October 2026 framework audit ran the 28 embedded-skill tests on Linux for the first time. Eight failed: delivery-status, doc-sweep, env-audit, health, reflect, self-audit, standup and vitality. None of the failures came from the skills themselves. They came from the tests:

- **BSD-only commands first.** The tests called `stat -f %m`, `date -v`, `date -j` and `sed -i ''` before the GNU forms. GNU `stat -f` prints file-system data to stdout before failing, so the captured "age" was text and the arithmetic aborted.
- **Broken zero counts.** `grep -c … || echo 0` yields `0\n0` when nothing matches.
- **Git assumptions.** The tests assumed git's default branch is `main`, and backdated commits with `--date`, which sets only the author date while the stand-ins read the committer date (`%ct`).
- **A fixed date.** `test-ascent-vitality.sh` hard-coded a fixture date of 2026-05-18, so its 60-day recency check began failing in mid-July 2026.

The same audit, and the independent review of this change, found tests that could not fail:

- Some asserted on the fixture they had just written (layering-check, env-audit, delivery-status).
- Others called `assert_pass` with no condition (self-audit) or counted loop iterations instead of results (health).
- Several had "platform limitation" branches that turned a failure into a pass (health, doc-sweep, delivery-status, standup, vitality).
- Two grepped SKILL.md prose instead of exercising behavior, which Principle §16 forbids.
- The session classifier the template actually ships (`make session-resume`) had no test at all; only hand-copied versions of it were tested.

CI never ran these tests, so none of this was visible. §1 makes containers non-negotiable, and every container, devcontainer and default CI runner is Linux. A suite that only passes on macOS fails exactly where ASCENT says projects run.

## Decision

1. **One portable helper library.** `tests/skills/lib/portable.sh` is sourced by every test immediately after its cleanup trap, so the trap stays at its conventional line.
   - It provides `file_mtime`, `file_age_days`, `epoch_days_ago`, `set_mtime_days_ago`, `ymd_days_ago`, `ymd_to_epoch`, `sed_inplace`, `count_matches`, `git_init_main` and `git_commit_days_ago`.
   - Each helper detects GNU vs BSD once and uses the matching command, never a fallback chain.
   - Calendar dates are computed from local noon, so a DST change cannot shift a fixture date.
   - The library unsets `GIT_DIR`, `GIT_INDEX_FILE` and related variables. Fixture repositories refuse to start unless they are their own repository, and they disable hooks. Without this, a git hook that runs the tests could rewrite the outer repository's config and index.
   - Tests do not call `stat`, `touch -t/-d`, `date -d/-j/-v` or `sed -i` directly.
2. **Touched tests show each check passing and failing.** Every test this change rewrote asserts on a stand-in run against a passing fixture *and* a failing fixture.
   - Fixture ages sit at the threshold ±1 day (±2 for calendar dates).
   - No branch turns a failed expectation into a pass.
   - The shipped `make session-resume` classifier is tested directly.
   - Tests this change did not rewrite keep their current shape until the next verification pass (see Consequences).
3. **Named negative controls.** `make/mutants.tsv` lists 26 mutants. Each breaks one rule in a rendered project and names the test that must catch it. Every mutant touches code that both GNU and BSD runs execute. `make test-mutants`:
   - runs every named test unmutated first, as a control;
   - reports a mutant whose sed expression changes nothing as an ANCHOR MISS;
   - runs 4 validator controls against `qa-skill-frontmatter`;
   - fails if any mutant survives, any anchor misses, or the number of mutants run differs from the number of rows.
4. **The meta-repo runs the suite.** `make test-skills` renders the template with fixed self-test values (`make/render-template.sh`, which fails if any placeholder survives) and runs the 28 tests. CI runs `make qa`, `make test-skills` and `make test-mutants` on `ubuntu-latest` and `macos-latest`. The workflows use `contents: read` where possible and SHA-pinned actions, which Dependabot keeps current.
5. **Descriptions route.** Claude decides when to load a skill from its `description`. Each description therefore leads with its trigger phrases ("Use when …"), names its sibling where triggers overlap, and contains no template placeholders. `qa-skill-frontmatter` enforces both rules, and that the `name` matches the directory. `ascent-skills-doctor` documents and tests the same rules for projects.

## Alternatives considered

- **Require GNU coreutils on macOS (Homebrew).** Simple, but every contributor and operator must install and alias it, and the default macOS shell would still fail. Rejected: the framework should run on a stock Mac and a stock Linux runner.
- **Rewrite the tests in Python.** Removes the shell portability problems, but abandons the bash test discipline that Phase 3 established and doubles the languages a skill author needs. Rejected for now. Revisit if Phase 4's scaffolder (Python) wants one test language.
- **Mutation-testing framework (e.g. Stryker).** Strong coverage, but the stand-ins are bash, and these tools target JS or TS. A short list of named mutants documents intent ("this rule is guarded by that test"), which a generated mutant report does not. Kept named mutants; broad mutation testing can come later for template application code.
- **Keep platform-fallback passes.** Rejected: a test that passes when it cannot check anything gives false assurance, the failure class the audit was looking for.

## Consequences

**Easier:**
- The suite gives the same answer on a Mac, a Linux runner and inside a container. Running it from a git hook cannot touch the outer repository.
- 12 of the 28 tests are guarded by named mutants. A test that has lost its ability to fail shows up in `make test-mutants`.
- Skill descriptions route correctly before and after the template is rendered, and no longer block plugin packaging. The `version:` placeholder is a separate step, handled when the skills are packaged.

**Harder:**
- Test authors must use the helpers and add a mutant for any new rule. The PR template now lists both.
- A stand-in change can break a mutant anchor. The harness reports this as ANCHOR MISS, which is the intended signal, but it is extra work.

**Neutral, deferred to the next verification pass (audit wave W4):**
- Stand-ins still live inside each test. Extracting them into shared libraries that the SKILL.md files name is deferred.
- Tests not rewritten here still contain write-then-assert checks: reflect and feature-intake entry placement under `## Decisions`, adr-write, handoff and doc-stub guards.
- Several stand-ins are shallower than their SKILL.md:
  - self-audit §1, §7 and §9 detail;
  - env-audit frontend scanning and the `<paste-…>` placeholder;
  - feature-intake subjective-language matching;
  - health's `>=` ranges.
- `ascent-health/SKILL.md` contradicts itself on the composite for 3 strong + 1 not-assessed. The rule must be decided before its test can assert it.

## Cost implications

- About one day of one-time work: the library, the test edits, the harness, 26 mutants plus 4 validator controls, and 29 descriptions.
- On Linux, the three gate targets take about 10 seconds, plus runner start-up per job. The macOS runner consumes GitHub Actions minutes at a higher rate. That's acceptable for a public repository (free) and worth reviewing if the repository goes private.
- Ongoing: one `mutants.tsv` row per new rule, and monthly Dependabot PRs for pinned actions.
