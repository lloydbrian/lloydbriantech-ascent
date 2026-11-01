# ADR-019: The quality plugin's rules: QA-I1–I5, QA-T1–T4 and QA-H1–H4, read statically, never run

**Status:** Accepted
**Date:** 2026-10-31 (America/New_York)
**Decider:** lloydbriantech

## Context

[ADR-014](ADR-014-testing-ownership-and-dependency-scan.md) decision 3 scoped `ascent-quality` 0.1.0: a hand-written test-strategy plugin with `quality-review`, `test-inventory`, `test-check` and a read-only `quality-reviewer`, the `QA-I`, `QA-T` and `QA-H` rule families, and a default criterion id pattern of `AC-<n>[.<n>]`. [ADR-017](ADR-017-faster-negative-controls.md) moved it to v0.4.11. ADR-014 named the families but left the rules, their severities and how a script finds a test to the build. The build and a read-only trial on five repositories (four application and infrastructure repositories and this one, copies with `.env` files excluded) raised these questions:

- **What is a test file?** Repositories put tests beside the source (`*.test.js`, `*_test.go`), under a `tests/` tree, or in shell (`test-*.sh`, `*.bats`). Fixtures under a test tree hold deliberately broken files and must not count.
- **What is a test block, and what is an assertion?** JS and TS tests end at a closing parenthesis, Go tests at a closing brace, Python tests at their indentation, bats tests at a `}` in column 1. An assertion differs per runner, and many projects use their own helpers.
- **Which boundary doubles count?** In the first build a Python `responses` double cleared a Go HTTP client, and `testcontainers` cleared every boundary in every language.
- **What runs the tests in CI?** Most CI steps call `make test` or `npm test`, not the runner, so a check that reads only the CI file misses them.
- **Do criterion ids in examples count?** Documents show ids inside code fences as examples.
- **The trial.** Two repositories had no tests (QA-I1), one had no CI (QA-I2), and three had no criterion ids (QA-T3). One had two genuine QA-H3 findings: tests whose only check was "does not raise". One repository had no `package.json` test script but a `make test` target that runs the suite, which the first build reported as QA-I5.

## Decision

1. **Thirteen rules, rated only from the `qa-severity` table** in `quality-review` and copied into `quality-reviewer`. T5 checks the copies with a `marked_table qa-severity quality` line.

   | Rule | Severity | Rule |
   |---|---|---|
   | QA-I1 | Medium | every type in `quality.tests.types_required` has a test file |
   | QA-I2 | Medium | CI exists and a step runs the tests |
   | QA-I3 | Low | end-to-end and contract tests, when present, are run by a CI step naming their runner |
   | QA-I4 | Low | every database, queue and outbound HTTP client the source imports is reached by a test in the same language |
   | QA-I5 | Low | every `package.json` declares a real test script, or the repository has a make `test*` target |
   | QA-T1 | Medium | every criterion id a criteria document defines is named by a test |
   | QA-T2 | Low | every criterion id a test names is defined |
   | QA-T3 | Low | criterion ids exist; with none, traceability is unmeasured |
   | QA-T4 | Medium | every source file under `quality.tests.core_paths` is named by a test |
   | QA-H1 | High | no focused tests (`.only`, `fit`, `fdescribe`, `@pytest.mark.only`) |
   | QA-H2 | Medium | every skipped test gives a reason; one that does is a NOTE |
   | QA-H3 | Medium | every test block holds an assertion |
   | QA-H4 | Low | no retries that hide flaky tests |

   QA-H1 is the only High: a focused test makes CI run part of the suite and report green. QA-I4 stays Low, as ADR-014 set for a heuristic until trialled.
2. **Two scripts, static and line-based.** `check-test-inventory.sh` owns `QA-I`; `check-tests.sh` owns `QA-T` and `QA-H`. They share `lib/qa-files.sh` (which files are tests, and which directories are skipped: dependencies, build output, virtualenvs, `fixtures`, `testdata`, snapshots) and `lib/qa-common.awk` (comment and string masking, block recognition, test typing). They run under bash 3.2 and POSIX awk, with no subshell per file. Neither script, nor any skill, runs a test, the suite or CI; a question that needs a run becomes a command the operator runs.
3. **Test files** are found by name in every language, and for JS, TS, Python and Go also by sitting under `tests/`, `test/`, `spec/`, `__tests__/`, `e2e/` or `cypress/`. A test's type comes from its path, name and imports (Playwright, Cypress, Pact, testcontainers and so on); everything else is unit.
4. **Test blocks and assertions, per language.** A block ends by paren depth (JS, TS), brace depth (Go, one-line functions included), indentation (Python, after a signature that may span lines, and never on a line inside a triple-quoted string) or a `}` in column 1 (bats); its first line counts. Strings and comments are masked first, so a word inside them is never an assertion. An assertion is the runner's own (`expect`, `assert*`, `should`, `t.Error`, `t.Fatal`, `pytest.raises`), a Go helper given `t`, any checked bats command, or a name in `quality.tests.assertion_helpers`. Skipped tests are exempt from QA-H3, and `test-*.sh` files are not read as blocks. `test-check` reads every QA-H3 hit before reporting it, because a project helper that throws is an assertion the script cannot see.
5. **Doubles are per language.** QA-I4 matches a client to a test only through a test in the same language that names the client or uses a double of its kind (`sqlmock`, `nock`, `msw`, `responses`, `httptest`, `testcontainers` and so on).
6. **CI is followed through make and package scripts.** QA-I2 and QA-I3 follow make recipes and prerequisites, `$(MAKE)` calls and npm, yarn, pnpm and bun scripts three levels deep. Installing a runner (`pip install pytest`, `npm i -D jest`) is not running it. QA-I5 accepts a make `test*` target in place of a missing test script: the calibration from the trial.
7. **Criterion ids.** The default pattern stays `AC-[0-9]+([.][0-9]+)?` (ADR-014). A pattern that matches the empty string is refused. A test naming `AC-2.1` covers `AC-2.1` and counts for `AC-2`. Ids inside a code fence are examples and are ignored. The skill never invents a mapping: with no ids, the fix is for the project to adopt a convention.
8. **Contract values reach the scripts quoted.** The skills put every value in single quotes and refuse one holding a quote, a newline, `$(` or a backtick, because the contract is a file the repository controls; the scripts prefix relative paths with `./`, so no value reaches `find` as an expression.
9. **The `quality:` contract section:** `maturity_target`, `tests` (`paths`, `types_required`, `criteria_paths`, `criteria_id_pattern`, `core_paths`, `assertion_helpers`), `adr_dir` and `waivers`. Enterprise maturity by default, as in ADR-011, ADR-013 and ADR-014 decision 5.
10. **The delivery loop's Tests lens** uses `ascent-quality:quality-reviewer` first, then `engineering:testing-strategy`. `ascent-delivery` 0.1.3 changes its three lens tables, and `OWNERSHIP.md` changes in the same release (T13.8).
11. **Registry.** `ascent-quality` becomes released in `OWNERSHIP.md`: its components, the three families (no longer reserved), a signals row, and the unit, integration and contract, regression and end-to-end, and traceability domains. Load and performance and mutation evidence stay planned for 0.2.0. PILLARS moves functional suitability to Strong for traceability, test types and hygiene.

## Alternatives considered

- **Run the tests to see which ones pass, focus or skip.** Rejected. Running a suite is the operator's (ADR-014 decision 1); it needs the project's toolchain and secrets, and can change state. The static reading finds the committed problem, which is the one CI inherits.
- **A coverage threshold.** Rejected. Coverage says which lines ran, not which behaviour is checked; a test with no assertion raises it.
- **Language parsers (Babel, `ast`, `go/parser`) for exact test blocks.** Rejected. They need each language's toolchain installed and four parsers to maintain. Depth and indentation counting is exact for ordinary tests; the skill reads a hit when a regular expression could have moved a block's end.
- **One script for all thirteen rules.** Rejected. Inventory and traceability read different inputs (CI files and imports, criteria documents and test names). Two scripts keep each skill's run small, and the shared libraries keep recognition identical.
- **QA-H3 as High.** Rejected. An assertion-less test is often a helper the script cannot see. Medium, with the skill reading every hit, matched the trial.
- **QA-I5 only from `package.json`.** Rejected after the trial: a repository that runs its tests with `make test` has one command, which is what the rule asks.

## Consequences

- A repository that tags its criteria and core rules gets traceability evidence; one that does not gets QA-T3 (Low) and a proposed convention, not invented results.
- Line-based reading has known limits, printed in each script's header: a YAML command split over lines, a test command built at runtime, or a client reached through the project's own wrapper can be missed. The skills tell the reader where to look.
- QA-T1 proves a test names a criterion, not that it checks it. `test-check` reads short tests and Medium criteria and lists a mismatch under Other observations.
- The plugin has no dependencies. The delivery loop uses it when installed and falls back otherwise.
- Every rule has behavior tests on the default awk and negative controls in the `ascent-quality-*` groups of `make/test-mutants.sh`.
- **(uncertain)** Projects with test layouts the trial did not cover (Java, Ruby, Rust, .NET) are not recognized; they read as no tests. Adding a language is a recognition change in `lib/qa-files.sh` and `lib/qa-common.awk`, with tests.

## Cost implications

- About 1,280 plugin lines and 560 test lines with 19 fixture files, against ADR-014's estimate of 1,600 and 700. 84 negative controls (P377–P460) against an estimate of about 35: block ends, masking, the input guards and the review's fixes each needed their own.
- **CI:** new `ascent-quality-*` mutant groups, each inside the 15-minute job limit.
- **Gate:** one `marked_table qa-severity quality` line in `make/test-plugins.sh`.
- **Recurring:** keep the runner, double and assertion lists current as test tools change, and add languages when a trial needs them.
- **Runtime:** bash, awk and git. Nothing is installed or run.
