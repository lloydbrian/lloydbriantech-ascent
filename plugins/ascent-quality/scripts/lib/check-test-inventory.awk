# check-test-inventory.awk — the checks of check-test-inventory.sh, which passes the
# file list and the ENVIRON values (QA_TYPES, QA_PATHS). Loaded after qa-common.awk.
# A separate file keeps bash 3.2 from parsing the program. Run with LC_ALL=C.
BEGIN {
  NTY = split(ENVIRON["QA_TYPES"], TY, ",")
  # Integration boundaries: language, kind, module, the word a test that reaches it
  # names. A test reaches a boundary when it names that word or uses a test double
  # of the boundary's kind (DOUBLE below).
  n = split("js db pg pg|js db mysql mysql|js db mysql2 mysql2|js db mongodb mongodb|js db mongoose mongoose|js db sequelize sequelize|js db typeorm typeorm|js db @prisma/client prisma|js db knex knex|js db better-sqlite3 better-sqlite3|js db sqlite3 sqlite3|js db redis redis|js db ioredis ioredis|js db @aws-sdk/client-dynamodb client-dynamodb|js db @aws-sdk/lib-dynamodb lib-dynamodb|js db drizzle-orm drizzle-orm|js queue amqplib amqplib|js queue kafkajs kafkajs|js queue @aws-sdk/client-sqs client-sqs|js queue @aws-sdk/client-sns client-sns|js queue bullmq bullmq|js queue bull bull|js queue @google-cloud/pubsub pubsub|js queue nats nats|js http axios axios|js http node-fetch node-fetch|js http got got|js http undici undici|js http superagent superagent|js http ky ky|py db psycopg psycopg|py db psycopg2 psycopg2|py db sqlalchemy sqlalchemy|py db pymongo pymongo|py db redis redis|py db asyncpg asyncpg|py db mysql mysql|py db pymysql pymysql|py db motor motor|py db peewee peewee|py queue pika pika|py queue kafka kafka|py queue confluent_kafka confluent_kafka|py queue aiokafka aiokafka|py queue celery celery|py http requests requests|py http httpx httpx|py http aiohttp aiohttp|py http urllib3 urllib3|go db database/sql sql|go db github.com/jackc/pgx pgx|go db github.com/lib/pq pq|go db gorm.io/gorm gorm|go db go.mongodb.org/mongo-driver mongo|go db github.com/redis/go-redis redis|go db github.com/go-redis/redis redis|go queue github.com/segmentio/kafka-go kafka|go queue github.com/rabbitmq/amqp091-go amqp|go queue github.com/nats-io/nats.go nats|go queue github.com/IBM/sarama sarama|go queue github.com/Shopify/sarama sarama", E, "|")
  for (i = 1; i <= n; i++) { split(E[i], F, " "); NB++; BL[NB] = F[1]; BK[NB] = F[2]; BM[NB] = F[3]; BW[NB] = F[4] }
  # Test doubles by language and kind: a double only counts for a client of its own
  # language (responses is no double for a Go HTTP client).
  DOUBLE["js", "db"] = "testcontainers pg-mem mongodb-memory-server ioredis-mock redis-mock"
  DOUBLE["js", "queue"] = "testcontainers localstack"
  DOUBLE["js", "http"] = "nock msw fetch-mock axios-mock-adapter"
  DOUBLE["py", "db"] = "testcontainers fakeredis mongomock pytest-postgresql pytest_postgresql"
  DOUBLE["py", "queue"] = "testcontainers localstack moto"
  DOUBLE["py", "http"] = "responses requests_mock requests-mock respx httpx_mock pytest_httpx aioresponses vcr vcrpy pook"
  DOUBLE["go", "db"] = "testcontainers testcontainers-go sqlmock go-sqlmock dockertest"
  DOUBLE["go", "queue"] = "testcontainers testcontainers-go dockertest"
  DOUBLE["go", "http"] = "httptest"
}
# addtokl LINE LANG — the words of a test file, by the file's language.
function addtokl(s, lg,   n, i, W) {
  n = split(s, W, /[^A-Za-z0-9_-]+/)
  for (i = 1; i <= n; i++) if (W[i] != "") TOKL[lg, W[i]] = 1
}
# boundary LANG MODULE — records a boundary import at the current line.
function boundary(lg, mod,   i) {
  for (i = 1; i <= NB; i++) {
    if (BL[i] != lg) continue
    if (mod == BM[i] || (lg == "go" && index(mod, BM[i] "/") == 1)) {
      if (!(i in BAT)) BAT[i] = at()
      return
    }
  }
}
function newfile() {
  FN = FILENAME; sub(/^\.\//, "", FN); LG = lang(FN); KN[K]++; INGO = 0; INSCR = 0; MT = ""
  MCOM = 0; MQ = ""
  if (K == "t") { NT++; TF[NT] = FN }
  if (K == "ci" && CIFIRST == "") CIFIRST = FN
}
FNR == 1 { newfile() }
{ raw = $0; sub(/\r$/, "", raw) }
K == "t" || K == "td" {
  addtokl(raw, LG); typeflags(raw)
  if (raw ~ /:memory:/) TOKL[LG, "memory-db"] = 1
  if (K == "td" && !(FN in TDBLK) && isblock(mask(raw, LG), LG)) { TDBLK[FN] = 1; NT++; TF[NT] = FN }
  next
}
K == "s" {
  if (LG == "js") {
    s = raw
    while (match(s, /(require|import)[ \t]*\([ \t]*["'][^"']+["']|(from|import)[ \t]+["'][^"']+["']/)) {
      m = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
      sub(/^[^"']*["']/, "", m); sub(/["']$/, "", m)
      if (m ~ /^@/) { split(m, P, "/"); m = P[1] "/" P[2] } else sub(/\/.*$/, "", m)
      boundary("js", m)
    }
  } else if (LG == "py") {
    if (match(raw, /^[ \t]*(import|from)[ \t]+[A-Za-z0-9_.]+/)) {
      m = substr(raw, RSTART, RLENGTH); sub(/^[ \t]*(import|from)[ \t]+/, "", m); sub(/\..*$/, "", m)
      boundary("py", m)
    }
  } else if (LG == "go") {
    if (raw ~ /^import[ \t]*\(/) { INGO = 1; next }
    if (INGO && raw ~ /^\)/) { INGO = 0; next }
    if (INGO || raw ~ /^import[ \t]/) { if (match(raw, /"[^"]+"/)) boundary("go", substr(raw, RSTART + 1, RLENGTH - 2)) }
    else if (raw ~ /http\.(Get|Post|PostForm|Head|NewRequest|NewRequestWithContext)[ \t]*\(|&?http\.Client[ \t]*\{/ && !(0 in GOHTTP)) GOHTTP[0] = at()
  }
  next
}
K == "ci" {
  t = trim(raw)
  if (t ~ /^#/ || t ~ /^-?[ \t]*(name|description)[ \t]*:/) next
  NCI++; CIL[NCI] = t
  next
}
K == "pkg" { pkgline(raw); next }
K == "make" { makeline(raw); next }
function runstests(s) {
  s = noinstall(s)
  return (s ~ /(^|[^A-Za-z0-9_-])(npm|yarn|pnpm|bun)[ \t]+((run|run-script)[ \t]+)?[A-Za-z0-9:_-]*(test|spec|e2e)/ || \
    s ~ /(^|[^A-Za-z0-9_-])(npm|yarn|pnpm)[ \t]+t([ \t;&|]|$)/ || \
    s ~ /(^|[^A-Za-z0-9_\/-])(jest|vitest|mocha|ava|tap|pytest|py\.test|tox|nox|bats|phpunit|rspec|ctest)([ \t;&|]|$)/ || \
    s ~ /playwright[ \t]+test|cypress[ \t]+run|python[0-9.]*[ \t]+-m[ \t]+(pytest|unittest)|go[ \t]+test|cargo[ \t]+test|node[ \t]+--test|deno[ \t]+test|bun[ \t]+test|mvn[ \t]+.*(test|verify)|gradlew?[ \t]+.*(test|check)/ || \
    s ~ /(^|[^A-Za-z0-9_-])(make|\$\(MAKE\)|\$\{MAKE\})[ \t]+([^;&|]*[ \t])?(test|tests|check|qa|ci|verify)[A-Za-z0-9_-]*/ || \
    s ~ /(bash|sh|node|python[0-9.]*|deno|bun|\.\/)[ \t]*[^ \t;&|]*(tests?|spec)\/[^ \t;&|]+/ || \
    s ~ /run-tests|test-runner|runtests|run_tests/)
}
END {
  for (j = 1; j <= NT; j++) { y = ttype(TF[j]); CNT[y]++; if (!(y in TFIRST)) TFIRST[y] = TF[j] }
  where = "absent: searched " ENVIRON["QA_PATHS"]
  # QA-I1 — required test types
  for (j = 1; j <= NTY; j++) {
    y = TY[j]; CHK["I1"]++
    if (CNT[y] == 0) fail("I1", "Medium", where, "no " y " tests, and the contract requires them (types_required)")
  }
  # QA-I2, QA-I3 — CI runs the tests
  ALL = ""
  for (j = 1; j <= NCI; j++) { e = expand(CIL[j], 0); ALL = ALL "\n" e; if (runstests(e)) CIRUN = 1 }
  if (NT > 0) {
    CHK["I2"]++
    if (KN["ci"] == 0) fail("I2", "Medium", "absent: searched .github/workflows/, .gitlab-ci.yml, Jenkinsfile, .circleci/, azure-pipelines.yml, bitbucket-pipelines.yml, .travis.yml, .buildkite/", "no CI configuration, so no test runs on a change")
    else if (!CIRUN) fail("I2", "Medium", CIFIRST ":1", "no CI step runs the tests (" KN["ci"] " CI file(s) read; make targets and package scripts followed)")
    if (KN["ci"] > 0) {
      if (CNT["e2e"] > 0) { CHK["I3"]++; if (ALL !~ /playwright|cypress|e2e|wdio|webdriver|selenium|puppeteer|testcafe|nightwatch/) fail("I3", "Low", TFIRST["e2e"] ":1", "end-to-end tests exist (" CNT["e2e"] " file(s)) but no CI step runs them") }
      if (CNT["contract"] > 0) { CHK["I3"]++; if (ALL !~ /pact|contract/) fail("I3", "Low", TFIRST["contract"] ":1", "contract tests exist (" CNT["contract"] " file(s)) but no CI step runs them") }
    }
  }
  # QA-I4 — integration boundaries
  if (0 in GOHTTP) { NB++; BL[NB] = "go"; BK[NB] = "http"; BM[NB] = "net/http client"; BW[NB] = "http"; BAT[NB] = GOHTTP[0] }
  for (i = 1; i <= NB; i++) {
    if (!(i in BAT)) continue
    CHK["I4"]++
    lg = BL[i]; hit = ((lg, BW[i]) in TOKL)
    if (!hit) { n = split(DOUBLE[lg, BK[i]], W, " "); for (j = 1; j <= n; j++) if ((lg, W[j]) in TOKL) { hit = 1; break } }
    if (!hit && BK[i] == "db" && ((lg, "memory-db") in TOKL)) hit = 1
    if (!hit) fail("I4", "Low", BAT[i], "the " BK[i] " client " BM[i] " is used here, but no test names it or uses a test double for it (heuristic)")
  }
  # QA-I5 — package.json declares a test script
  for (f in PKGLINE) {
    CHK["I5"]++
    # A project whose operator vocabulary is make (a test* target) needs no npm script.
    if (!(f in PKGTEST)) { if (!MAKETEST) fail("I5", "Low", f ":1", "package.json has no test script and no make target runs tests, so there is no standard command to run them") }
    else if (PKGTEST[f] ~ /no test specified/) fail("I5", "Low", f ":" PKGTL[f], "the test script is npm's placeholder, which always fails")
  }
  split("I1 I2 I3 I4 I5", ORDER, " ")
  D["I1"] = "every required test type has tests"
  D["I2"] = "CI runs the tests"
  D["I3"] = "CI runs every end-to-end and contract test"
  D["I4"] = "every integration boundary is reached by a test"
  D["I5"] = "package.json declares a test script"
  for (j = 1; j <= 5; j++) {
    k = ORDER[j]
    if (NF_[k] > 0) printf "%s", OUT[k]
    else if (CHK[k] > 0) printf "PASS  %-7s %s (%d checked)\n", "QA-" k, D[k], CHK[k]
    else printf "N/A   %-7s %s (nothing to check)\n", "QA-" k, D[k]
  }
  printf "check-test-inventory: %d test file(s) (unit %d, integration %d, contract %d, e2e %d), %d source file(s), %d CI file(s), %d failure(s)\n", \
    NT, CNT["unit"], CNT["integration"], CNT["contract"], CNT["e2e"], KN["s"], KN["ci"], NFAIL
  exit (NFAIL > 0 ? 1 : 0)
}
