#!/usr/bin/env bash
# Test: ascent-layering-check
# Verifies the backend layering check detects correct layering and violations.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/layering-check"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT
# shellcheck source=lib/portable.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/portable.sh"

setup_valid_backend() {
  mkdir -p "$FIXTURES_DIR/backend/routes" "$FIXTURES_DIR/backend/controllers" \
           "$FIXTURES_DIR/backend/services" "$FIXTURES_DIR/backend/storage"
  echo "import { listItems } from '../controllers/items.js';" > "$FIXTURES_DIR/backend/routes/items.js"
  echo "import * as itemsService from '../services/items.js';" > "$FIXTURES_DIR/backend/controllers/items.js"
  echo "import * as itemsStorage from '../storage/items.js';" > "$FIXTURES_DIR/backend/services/items.js"
  echo "import { getDb } from './db.js';" > "$FIXTURES_DIR/backend/storage/items.js"
  echo "export function getDb() {}" > "$FIXTURES_DIR/backend/storage/db.js"
}

assert_pass() {
  local desc="$1"
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-layering-check: %s\n" "$desc"
}

assert_fail() {
  local desc="$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-layering-check: %s\n" "$desc"
}

# Stand-in for the skill's import-direction checks (Steps 3-6).
# layering_violations BACKEND_DIR — prints one line per violation, nothing when clean.
#   routes      may import controllers only (never services or storage)
#   controllers may import services only   (never storage)
#   services    may not import express or touch req/res
layering_violations() {
  local b="$1" f
  for f in "$b"/routes/*.js; do
    [ -f "$f" ] || continue
    grep -nE "from ['\"]\.\./(services|storage)/" "$f" | sed "s|^|routes→lower: $f:|" || true
  done
  for f in "$b"/controllers/*.js; do
    [ -f "$f" ] || continue
    grep -nE "from ['\"]\.\./storage/" "$f" | sed "s|^|controller→storage: $f:|" || true
  done
  for f in "$b"/services/*.js; do
    [ -f "$f" ] || continue
    grep -nE "from ['\"]express['\"]|(^|[^A-Za-z0-9_])(req|res)\." "$f" | sed "s|^|service→http: $f:|" || true
  done
}

violation_count() {
  layering_violations "$1" | wc -l | tr -d ' '
}

# Test 1: Valid layering passes all checks (0 violations)
cleanup
setup_valid_backend
VALID=$(violation_count "$FIXTURES_DIR/backend")
if [ "$VALID" -eq 0 ]; then
  assert_pass "valid backend passes — 0 layering violations"
else
  assert_fail "valid backend should have 0 violations, got $VALID: $(layering_violations "$FIXTURES_DIR/backend")"
fi

# Test 2: Route importing storage is detected as a violation
cleanup
setup_valid_backend
echo "import { getDb } from '../storage/db.js';" >> "$FIXTURES_DIR/backend/routes/items.js"
ROUTE_V=$(layering_violations "$FIXTURES_DIR/backend")
if [ "$(violation_count "$FIXTURES_DIR/backend")" -eq 1 ] && printf '%s' "$ROUTE_V" | grep -q 'routes→lower'; then
  assert_pass "route importing storage detected as violation"
else
  assert_fail "route importing storage should be exactly 1 routes→lower violation, got: $ROUTE_V"
fi

# Test 2b: Route importing services (skipping controllers) is a violation
cleanup
setup_valid_backend
echo "import * as svc from '../services/items.js';" >> "$FIXTURES_DIR/backend/routes/items.js"
ROUTE_SVC_V=$(layering_violations "$FIXTURES_DIR/backend")
if [ "$(violation_count "$FIXTURES_DIR/backend")" -eq 1 ] && printf '%s' "$ROUTE_SVC_V" | grep -q 'routes→lower'; then
  assert_pass "route importing services detected as violation"
else
  assert_fail "route importing services should be exactly 1 routes→lower violation, got: $ROUTE_SVC_V"
fi

# Test 2c: Controller importing storage (skipping services) is a violation
cleanup
setup_valid_backend
echo "import { getDb } from '../storage/db.js';" >> "$FIXTURES_DIR/backend/controllers/items.js"
CTRL_V=$(layering_violations "$FIXTURES_DIR/backend")
if [ "$(violation_count "$FIXTURES_DIR/backend")" -eq 1 ] && printf '%s' "$CTRL_V" | grep -q 'controller→storage'; then
  assert_pass "controller importing storage detected as violation"
else
  assert_fail "controller importing storage should be exactly 1 controller→storage violation, got: $CTRL_V"
fi

# Test 3: Service importing express is detected as a violation
cleanup
setup_valid_backend
echo "import express from 'express';" >> "$FIXTURES_DIR/backend/services/items.js"
SERVICE_V=$(layering_violations "$FIXTURES_DIR/backend")
if [ "$(violation_count "$FIXTURES_DIR/backend")" -eq 1 ] && printf '%s' "$SERVICE_V" | grep -q 'service→http'; then
  assert_pass "service importing express detected as violation"
else
  assert_fail "service importing express should be exactly 1 service→http violation, got: $SERVICE_V"
fi

# Test 4: Empty backend (0 endpoints) is handled without error and reports 0
cleanup
mkdir -p "$FIXTURES_DIR/backend/routes" "$FIXTURES_DIR/backend/controllers" "$FIXTURES_DIR/backend/services"
if EMPTY=$(violation_count "$FIXTURES_DIR/backend") && [ "$EMPTY" -eq 0 ]; then
  assert_pass "empty backend (0 endpoints) handled gracefully — 0 violations"
else
  assert_fail "empty backend should report 0 violations without error, got '${EMPTY:-error}'"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-layering-check tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
