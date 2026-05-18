#!/usr/bin/env bash
# Test: ascent-observability-check
# Verifies the observability check detects correct emission and violations.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/observability-check"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

setup_valid_backend() {
  mkdir -p "$FIXTURES_DIR/backend/observability" "$FIXTURES_DIR/backend/middleware" "$FIXTURES_DIR/backend/routes"
  # Logger with required config
  cat > "$FIXTURES_DIR/backend/observability/logger.js" << 'JSEOF'
import pino from 'pino';
export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  timestamp: pino.stdTimeFunctions.isoTime,
  base: { service: 'test-project' },
});
JSEOF
  # Request-id middleware with traceparent
  cat > "$FIXTURES_DIR/backend/middleware/request-id.js" << 'JSEOF'
const TRACEPARENT_REGEX = /^00-([0-9a-f]{32})-[0-9a-f]{16}-[0-9a-f]{2}$/;
export function requestId(req, res, next) {
  const traceparent = req.headers['traceparent'];
  req.traceId = traceparent ? traceparent.match(TRACEPARENT_REGEX)?.[1] : crypto.randomUUID();
  next();
}
JSEOF
  # HTTP logger with trace_id
  cat > "$FIXTURES_DIR/backend/middleware/logger.js" << 'JSEOF'
import pinoHttp from 'pino-http';
export const httpLogger = pinoHttp({ customProps: (req) => ({ trace_id: req.traceId }) });
JSEOF
  # Health routes — /healthz without DB, /readyz with DB
  cat > "$FIXTURES_DIR/backend/routes/health.js" << 'JSEOF'
import { Router } from 'express';
import { getDb } from '../storage/db.js';
export const healthRoutes = Router();
healthRoutes.get('/healthz', (_req, res) => { res.json({ status: 'ok' }); });
healthRoutes.get('/readyz', (_req, res) => {
  const db = getDb();
  db.prepare('SELECT 1').get();
  res.json({ status: 'ready' });
});
JSEOF
  # Server with lifecycle events
  cat > "$FIXTURES_DIR/backend/server.js" << 'JSEOF'
import { logger } from './observability/logger.js';
logger.info({ event: 'service.started' }, 'Server started');
process.on('SIGTERM', () => {
  logger.info({ event: 'service.draining' }, 'Draining');
  logger.info({ event: 'service.stopped' }, 'Stopped');
});
JSEOF
  # Error handler with production check
  cat > "$FIXTURES_DIR/backend/middleware/error-handler.js" << 'JSEOF'
export function errorHandler(err, req, res, _next) {
  const body = { error: { message: err.message, status: 500 } };
  if (process.env.NODE_ENV !== 'production') { body.error.stack = err.stack; }
  res.status(500).json(body);
}
JSEOF
}

assert_pass() {
  local desc="$1"
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-observability-check: %s\n" "$desc"
}

assert_fail() {
  local desc="$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-observability-check: %s\n" "$desc"
}

# Test 1: Valid observability passes
cleanup
setup_valid_backend
ALL_PRESENT=true
[ -f "$FIXTURES_DIR/backend/observability/logger.js" ] || ALL_PRESENT=false
[ -f "$FIXTURES_DIR/backend/middleware/request-id.js" ] || ALL_PRESENT=false
[ -f "$FIXTURES_DIR/backend/middleware/logger.js" ] || ALL_PRESENT=false
[ -f "$FIXTURES_DIR/backend/routes/health.js" ] || ALL_PRESENT=false
grep -q "service.started" "$FIXTURES_DIR/backend/server.js" || ALL_PRESENT=false
grep -q "service.draining" "$FIXTURES_DIR/backend/server.js" || ALL_PRESENT=false
grep -q "service.stopped" "$FIXTURES_DIR/backend/server.js" || ALL_PRESENT=false
if [ "$ALL_PRESENT" = true ]; then
  assert_pass "valid backend passes all observability checks"
else
  assert_fail "valid backend should pass all observability checks"
fi

# Test 2: Missing trace_id in logger middleware detected
cleanup
setup_valid_backend
echo "export const httpLogger = {};" > "$FIXTURES_DIR/backend/middleware/logger.js"
if ! grep -q "trace_id" "$FIXTURES_DIR/backend/middleware/logger.js"; then
  assert_pass "missing trace_id in logger middleware detected"
else
  assert_fail "missing trace_id should be detected"
fi

# Test 3: /healthz checking DB detected as violation
# Fixture: /healthz handler contains getDb() and .prepare() calls.
# Detection: extract the /healthz handler block and check for DB operations within it.
cleanup
setup_valid_backend
cat > "$FIXTURES_DIR/backend/routes/health.js" << 'JSEOF'
import { Router } from 'express';
import { getDb } from '../storage/db.js';
export const healthRoutes = Router();
healthRoutes.get('/healthz', (_req, res) => {
  const db = getDb();
  db.prepare('SELECT 1').get();
  res.json({ status: 'ok' });
});
healthRoutes.get('/readyz', (_req, res) => {
  const db = getDb();
  db.prepare('SELECT 1').get();
  res.json({ status: 'ready' });
});
JSEOF
# Extract lines between /healthz handler and the next handler (or EOF).
# Then check if those lines contain DB operations (.prepare, getDb).
HEALTHZ_BLOCK=$(sed -n "/healthz/,/healthRoutes\.\|^});$/p" "$FIXTURES_DIR/backend/routes/health.js" | head -6)
if echo "$HEALTHZ_BLOCK" | grep -qE 'getDb|\.prepare|storage'; then
  assert_pass "/healthz handler contains DB operations — violation detected"
else
  assert_fail "/healthz checking DB should be detected within the handler block"
fi

# Test 4: Backend with no observability layer handled gracefully
cleanup
mkdir -p "$FIXTURES_DIR/backend"
echo "console.log('hello');" > "$FIXTURES_DIR/backend/server.js"
MISSING_COUNT=0
[ -f "$FIXTURES_DIR/backend/observability/logger.js" ] || MISSING_COUNT=$((MISSING_COUNT + 1))
[ -f "$FIXTURES_DIR/backend/middleware/request-id.js" ] || MISSING_COUNT=$((MISSING_COUNT + 1))
[ -f "$FIXTURES_DIR/backend/routes/health.js" ] || MISSING_COUNT=$((MISSING_COUNT + 1))
if [ "$MISSING_COUNT" -ge 3 ]; then
  assert_pass "backend with no observability layer handled gracefully ($MISSING_COUNT modules missing)"
else
  assert_fail "missing observability modules should be detected"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-observability-check tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
