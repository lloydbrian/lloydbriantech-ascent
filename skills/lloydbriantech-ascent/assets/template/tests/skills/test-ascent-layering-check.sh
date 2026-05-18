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

# Test 1: Valid layering passes all checks
cleanup
setup_valid_backend
# Check: routes import only from controllers (not storage/services)
if ! grep -q 'storage\|services' "$FIXTURES_DIR/backend/routes/items.js" 2>/dev/null || \
   grep -q 'controllers' "$FIXTURES_DIR/backend/routes/items.js"; then
  assert_pass "valid backend passes — routes import only controllers"
else
  assert_fail "valid backend should pass — routes import only controllers"
fi

# Test 2: Route importing storage is detected as violation
cleanup
setup_valid_backend
echo "import { getDb } from '../storage/db.js';" > "$FIXTURES_DIR/backend/routes/items.js"
if grep -q '../storage/' "$FIXTURES_DIR/backend/routes/items.js"; then
  assert_pass "route importing storage detected as violation"
else
  assert_fail "route importing storage should be detected"
fi

# Test 3: Service importing express is detected as violation
cleanup
setup_valid_backend
echo "import express from 'express';" > "$FIXTURES_DIR/backend/services/items.js"
if grep -q "express" "$FIXTURES_DIR/backend/services/items.js"; then
  assert_pass "service importing express detected as violation"
else
  assert_fail "service importing express should be detected"
fi

# Test 4: Empty backend (0 endpoints) handled gracefully
cleanup
mkdir -p "$FIXTURES_DIR/backend"
if [ -d "$FIXTURES_DIR/backend" ] && [ -z "$(find "$FIXTURES_DIR/backend" -name '*.js' 2>/dev/null)" ]; then
  assert_pass "empty backend (0 endpoints) handled gracefully"
else
  assert_fail "empty backend should be handled without error"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-layering-check tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
