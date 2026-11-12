# Test strategy reference

The shared source for `quality-review`, `test-inventory`, `test-check`, `test-evidence` and the `quality-reviewer` agent. The three scripts implement what this page describes; where they cannot (the limits below), the skills read.

## Who owns which tests

A test type has up to three owners: the plugin that sets the **target**, the plugin that checks the test is **present**, and the operator, who **runs** anything live. `ascent-quality` checks presence for these types and refers the others.

| Testing type | Present checked by |
|---|---|
| Unit, integration, contract, regression and end-to-end tests | `ascent-quality` |
| Acceptance criterion to test traceability | `ascent-quality` |
| Accessibility, navigation, front-end performance | `ascent-ux` |
| Recovery drills, readiness exercises | `ascent-ops` |
| Smoke tests after a deploy, user-acceptance sign-off | `ascent-delivery` |
| Security tests and scans | `ascent-security` |
| Load tests against the latency and throughput targets, mutation evidence | `ascent-quality` |

## How a test file is recognized

By name, in any directory:

| Language | Test file names |
|---|---|
| JavaScript, TypeScript | `*.test.*`, `*.spec.*`, `*.cy.*`, `*.e2e.*` (js, jsx, ts, tsx, mjs, cjs, mts, cts) |
| Python | `test_*.py`, `*_test.py` |
| Go | `*_test.go` |
| bats | `*.bats` |
| shell | `test-*.sh`, `test_*.sh`, `*_test.sh`, `*.test.sh` |

A JS, TS, Python or Go file with another name is a test when it sits under `tests/`, `test/`, `spec/`, `__tests__/`, `e2e/` or `cypress/` and holds a test block (`it(`, `test(`, `def test_`, `func TestX`). Other files there are helpers.

Never read as tests: dependencies (`node_modules/`, `vendor/`), build output (`dist/`, `build/`, `target/`, `coverage/`), virtualenvs and caches, and fixtures (`fixtures/`, `testdata/`, `__fixtures__/`, `__snapshots__/`), which are inputs to tests.

## Test types

| Type | Recognized by |
|---|---|
| e2e | under `e2e/`, `end-to-end/`, `cypress/`, `playwright/` or `acceptance/`; named `*.e2e.*`, `*.cy.*` or `e2e-*`; or imports Playwright, Cypress, Selenium, Puppeteer, WebdriverIO or TestCafe |
| contract | under `contract/`, `contracts/` or `pact/`; a name with `contract` or `pact`; or imports Pact |
| integration | under `integration/` or `it/`; a name with `integration`, `.int.` or `-int-`; `@pytest.mark.integration`; or a Go `integration` build tag |
| unit | any other test |

A project that types its tests differently (a `slow/` directory, a marker of its own) says so in the review, and the inventory is corrected by reading.

## Running in CI

CI files: `.github/workflows/*.yml`, `.gitlab-ci.yml`, `Jenkinsfile`, `.circleci/config.yml`, `azure-pipelines.yml`, `bitbucket-pipelines.yml`, `.travis.yml`, `.buildkite/*.yml`.

A step runs the tests when it calls a test runner (`jest`, `vitest`, `mocha`, `pytest`, `go test`, `bats`, `node --test`, `playwright test`, `cypress run`, and the like), a package script or make target whose name starts with `test`, `check`, `qa`, `ci` or `verify`, or a script under `tests/`. Make recipes and `package.json` scripts are followed three levels deep. End-to-end and contract tests count as run only when a step names their runner.

## Integration boundaries

A boundary is a client the source imports to reach something outside the process. A test in the same language reaches it when it names the client or uses a test double of its kind.

| Kind | Clients (JS, Python, Go) | Test doubles |
|---|---|---|
| database | `pg`, `mysql2`, `mongodb`, `mongoose`, `sequelize`, `typeorm`, `@prisma/client`, `knex`, `better-sqlite3`, `redis`, `ioredis`, DynamoDB clients; `psycopg`, `sqlalchemy`, `pymongo`, `redis`, `asyncpg`, `pymysql`; `database/sql`, `pgx`, `lib/pq`, `gorm`, the Mongo and Redis drivers | testcontainers, sqlmock, pg-mem, mongodb-memory-server, fakeredis, mongomock, an in-memory SQLite (`:memory:`) |
| queue | `amqplib`, `kafkajs`, SQS and SNS clients, `bullmq`, Pub/Sub, `nats`; `pika`, `kafka`, `aiokafka`, `celery`; `kafka-go`, `amqp091-go`, `nats.go`, `sarama` | testcontainers, localstack, moto |
| HTTP (outbound) | `axios`, `node-fetch`, `got`, `undici`, `superagent`, `ky`; `requests`, `httpx`, `aiohttp`, `urllib3`; Go `http.Get`, `http.Client` | nock, msw, fetch-mock, `responses`, `requests_mock`, `respx`, `pytest_httpx`, `httptest`, vcr |

QA-I4 is a heuristic and stays Low until trialled (ADR-014 decision 3): a test that reaches the client through the project's own wrapper is not seen.

## Acceptance criteria and core rules

- **Criterion ids.** The default format is `AC-<n>`, with an optional `.<n>` (`AC-2.1`), set by `quality.tests.criteria_id_pattern`. An id is defined where a criteria document names it, and covered where a test names it: in its title, a comment or a tag. A test naming `AC-2.1` also counts for `AC-2`. An id inside a longer word (`XAC-1`, `AC-1a`) is not an id.
- **No ids.** Most repositories have none. Then traceability is unmeasured (QA-T3, Low), and the fix is to give the criteria ids, not to invent tests.
- **Core rules.** The source files under `quality.tests.core_paths` hold the rules the business depends on. Each must be named by a test: imported, or named by a word equal to its base name (the directory's name for `index`, `main`, `__init__`, `mod` or `lib`), or by a test file named after it. A Go file counts as named when its directory has a `_test.go` file.

## Hygiene

| Rule | Caught | A reason or exemption |
|---|---|---|
| QA-H1 focused | `.only(` on `it`, `test`, `describe`, `context`, `suite`; `fit(`, `fdescribe(`; `@pytest.mark.only` | none: a focused test is never committed on purpose |
| QA-H2 skipped | `.skip(`, `.todo(`, `.fixme(`, `xit(`, `xdescribe(`; `@pytest.mark.skip`, `@unittest.skip`, `pytest.skip()`, `self.skipTest()`; `t.Skip()`, `t.SkipNow()`; bats `skip` | a message (`skip("flaky on arm64, #123")`, `t.Skip("needs a database")`), or a comment on the line or the line above. `skipif` with a condition is not a skip |
| QA-H3 no assertion | a test block with no `expect`, `assert*`, `should`, `t.Error`, `t.Fatal`, `require.`, `pytest.raises`, helper call given `t` (Go), or checked command (bats) | a skipped test; a project helper named in `assertion_helpers`. A test that only checks "does not throw" is still a finding: say what result it should check |
| QA-H4 retries | `jest.retryTimes`, `this.retries(n)`, `retries` in a runner config, `@pytest.mark.flaky`, `--reruns`, `--retries` in CI | none; a waiver ADR when a third-party flake cannot be fixed yet |

Shell `test-*.sh` files are counted and searched for ids, but not read as test blocks: a shell test has no common block syntax.

## Load tests and mutation evidence

The targets belong to `ascent-architecture`: `p95_latency_ms` and `peak_rps` in `architecture.quality_targets`. They are read, never copied ([ADR-021](../../../docs/framework/DECISIONS/ADR-021-load-test-alignment-and-mutation-evidence.md)). Nothing is run: a load test reaches a live environment and a mutation run rewrites the code under test.

| Tool | Recognized by | p95 threshold (QA-L2) | Request rate (QA-L3) | Error threshold (QA-L4) |
|---|---|---|---|---|
| k6 | a JS or TS file that imports `k6` | `http_req_duration: ['p(95)<N']`; the untagged threshold, else the loosest tagged one | `rate` (or `startRate`, stage `target`) of an arrival-rate executor per `timeUnit` | `http_req_failed: ['rate<x']` or `checks: ['rate>x']` |
| Artillery | YAML with top-level `config:` and `scenarios:` | `p95: N` under `ensure`, or `http.response_time.p95` in a threshold or condition | the highest `arrivalRate` or `rampTo` | `maxErrorRate`, or a condition on `vusers.failed` or `errors.` |
| Locust | a Python file that imports `locust` | `get_response_time_percentile(0.95) > N` in a quitting listener | `constant_throughput(r)` or `constant_pacing(s)` times the users in `locust.conf` or `-u`/`--users` | `fail_ratio >` or `num_failures >` |

- A threshold is in milliseconds and counts when it is no looser than the target; a rate counts when it reaches the target. Each rule is met by at least one load script.
- A load set in virtual users (k6 `vus`, a Locust user count with no throughput wait) has no rate a static check can read: a NOTE, which the review reads, never a pass.
- **Run** (QA-L5): `k6 run`, `k6 cloud`, the Grafana k6 GitHub actions, `artillery run` or `locust` in a CI step, a make recipe, a package script or a runbook in Markdown.

| Mutation tool | Configured by (QA-M1) | Break threshold (QA-M2) |
|---|---|---|
| Stryker (JS, TS) | `stryker.conf.*`, `stryker.config.*`, or `@stryker-mutator/core` in `package.json` | `thresholds.break` |
| PIT (Java) | `pitest-maven` in `pom.xml`, or `pitest` in `build.gradle` | `mutationThreshold` |
| gremlins (Go) | `.gremlins.yaml`, or `gremlins unleash` in CI or make | `efficacy`, or `--threshold-efficacy` |
| mutmut (Python) | `[mutmut]` or `[tool.mutmut]` in `setup.cfg` or `pyproject.toml`, or `mutmut run` | none: a NOTE, and the report is the evidence |
| go-mutesting (Go) | `go-mutesting` in CI or make | none: a NOTE |

- **CI** (QA-M3): a CI step runs the tool, through make recipes and package scripts as in QA-I2. A make target alone does not count: the score must be checked on every change.
- **Reports** (QA-M4): `*mutation.json` (Stryker: Killed and Timeout are detected, Survived and NoCoverage are not), `*mutations.xml` (PIT: KILLED, TIMED_OUT, MEMORY_ERROR and RUN_ERROR detected, SURVIVED and NO_COVERAGE not), and `*mutation-report.*` or `*mutation-score*` with a line such as `Mutation score: 72.5%`, go-mutesting's `The mutation score is 0.725` or gremlins' `Test efficacy: 85%`; plus any `quality.mutation.reports` entry (a file inside the repository). Reports under `target/`, `build/`, `dist/` and `coverage/` are not searched, so PIT's `target/pit-reports` must be listed. A line that states a target (`Minimum mutation score: 80%`) is not read as the score. The newest usable report counts. It is dated by a `YYYY-MM-DD` in its path, else by the author date of its last commit (`git log`, read-only, run from the repository root with bare-repository discovery and signature checks off); an uncommitted report with no date in its path is undated, and so is every report in a shallow clone. A report that cannot be used (unreadable, undated, dated after today) is a NOTE beside a usable one and fails QA-M4 when it is the only kind there is.
- **k6 scenarios** are read one by one: a rate counts only inside an arrival-rate executor and is divided by that scenario's own `timeUnit`; a `target` in a `ramping-vus` stage is a number of virtual users, not a rate. Block and line comments are skipped, and several thresholds on one line are each read. Installing a tool (`pip install locust`, `go install …go-mutesting`) is not running it.
