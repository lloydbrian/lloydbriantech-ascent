# ascent-quality

Test strategy review for any repository. It checks that the tests can be trusted to catch a broken change:
- the kinds of test the project needs exist, and CI runs them on every change
- every acceptance criterion and every core rule is named by a test
- no test passes by doing nothing: no focused, unexplained skipped, assertion-less or retried tests

It makes the ASCENT tester role checkable in an existing repository ([ADR-014](../../docs/framework/DECISIONS/ADR-014-testing-ownership-and-dependency-scan.md), [ADR-019](../../docs/framework/DECISIONS/ADR-019-quality-plugin-rules.md)). You don't need an ASCENT project to use it.

```
/plugin marketplace add lloydbrian/lloydbriantech-ascent
/plugin install ascent-quality@lloydbriantech-ascent
```

Start with `/ascent-quality:quality-review`, or ask "review our tests". For an independent pass: "Use the ascent-quality:quality-reviewer agent to review this repository."

## What's inside

| Part | Kind | What it does |
|---|---|---|
| `quality-review` | skill, entry point | contract, test map, three lenses, the two checks, maturity gaps; strong, moderate or weak |
| `test-inventory` | skill | test types and runners, what CI runs, integration boundaries no test reaches: QA-I1–I5 |
| `test-check` | skill | acceptance criteria and core rules traced to tests (QA-T1–T4); focused, skipped, assertion-less and retried tests (QA-H1–H4) |
| `quality-reviewer` | agent, read-only | independent review; the delivery loop's Tests lens |
| `check-test-inventory.sh` | script | QA-I1–I5 on test files, source imports, CI files, make targets and `package.json` |
| `check-tests.sh` | script | QA-T1–T4 and QA-H1–H4 on test files, criteria documents and runner configs, for JS, TS, Python, Go and bats |
| `references/` | references | the test strategy (recognition, types, CI, boundaries, criteria, hygiene) and the contract template |

## Boundaries

- **Running tests** is the operator's: the plugin never runs the suite, a test file or CI. A fix goes through `ascent-delivery` and its runbook.
- **Other plugins' tests:** accessibility, navigation and front-end performance are `ascent-ux`'s; recovery drills and readiness exercises `ascent-ops`'s; smoke tests and user-acceptance sign-off `ascent-delivery`'s; security tests and scans `ascent-security`'s ([ADR-014](../../docs/framework/DECISIONS/ADR-014-testing-ownership-and-dependency-scan.md) decision 1).
- **Coverage figures** are out of scope: they say which lines ran, not which behaviour is checked.
- **Load tests and mutation evidence** come in 0.2.0; code health is `ascent-architecture`'s.

## Maturity targets

| Item | Prototype | Standard | Enterprise (default) |
|---|---|---|---|
| Test types (QA-I1) | unit | unit, integration | unit, integration, and end-to-end when the project has a user interface |
| CI (QA-I2, QA-I3) | tests run with one command (QA-I5) | CI runs the tests on every change | CI runs every test type, end-to-end and contract included |
| Integration boundaries (QA-I4) | — | — | every database, queue and outbound HTTP client reached by a test |
| Traceability (QA-T1–T3) | — | criteria have ids, and each is named by a test | the same, with no stale ids |
| Core rules (QA-T4) | — | `core_paths` set, each file named by a test | the same |
| Hygiene (QA-H1–H4) | no focused tests | no focused, unexplained skipped or assertion-less tests | QA-H1–H4: no retries either |
| Decisions | — | — | an ADR for every waiver |

## Evidence, strongest first

1. **The two scripts:** exact, repeatable, `file:line`, labelled with their check id.
2. **Reading** the tests, the CI files and the criteria: the agent's view, and how the skills confirm the two heuristics (QA-H3, QA-I4).
3. **A run the operator does,** when a question needs one: the skill writes the command and reads the redacted output.

## Tests

`make test-plugins` runs `tests/plugins/ascent-quality/`, on every awk installed:
- `test-check-test-inventory.sh`: the good fixtures pass QA-I1–I5; one broken copy per control fails that check and no other; the trial calibrations
- `test-check-tests.sh`: the good fixtures pass QA-T1–T4 and QA-H1–H4 in JS, Python, Go and bats; one broken copy per control; reasons, exemptions and helpers
- `test-quality-rules.sh`: the skill rules, the severity table against both scripts, the contract keys, and bash 3.2

`make test-mutants GROUP=ascent-quality-inventory` (and the `-trace`, `-hygiene` and `-rules` groups) adds negative controls that must each make a named check fail.
