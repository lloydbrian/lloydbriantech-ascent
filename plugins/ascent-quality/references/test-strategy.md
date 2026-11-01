# Test strategy reference

The shared source for `quality-review`, `test-inventory`, `test-check` and the `quality-reviewer` agent. The two scripts implement what this page describes; where they cannot (the limits below), the skills read.

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
| Load tests against the latency and throughput targets, mutation evidence | `ascent-quality` 0.2.0 (planned) |

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
