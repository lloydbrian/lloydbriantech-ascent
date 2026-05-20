#!/usr/bin/env bash
# Test: ascent-dependency-health
# Verifies dependency discipline checks: pinned versions, engines, traceability, unused deps.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/dependency-health"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-dependency-health: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-dependency-health: %s\n" "$1"
}

# Reusable: detect unpinned versions in package.json (matches skill Step 1 logic)
# Returns the count of unpinned dependencies.
count_unpinned() {
  local pkg_file="$1"
  local unpinned=0
  local in_deps=false
  while IFS= read -r line; do
    if echo "$line" | grep -qE '"(dependencies|devDependencies)"'; then
      in_deps=true
      continue
    fi
    if [ "$in_deps" = true ] && echo "$line" | grep -q '^  }'; then
      in_deps=false
      continue
    fi
    if [ "$in_deps" = true ]; then
      local version
      version=$(echo "$line" | grep -oE '": "[^"]*"' | sed 's/": "//;s/"$//')
      if [ -n "$version" ] && echo "$version" | grep -qE '[\^~>=*]|latest'; then
        unpinned=$((unpinned + 1))
      fi
    fi
  done < "$pkg_file"
  echo "$unpinned"
}

# Reusable: check if dependency is imported in source (matches skill Step 4 logic)
is_dep_imported() {
  local dep_name="$1"
  local source_dir="$2"
  grep -rq "from ['\"]${dep_name}['\"]" "$source_dir" 2>/dev/null || \
    grep -rq "require(['\"]${dep_name}['\"])" "$source_dir" 2>/dev/null
}

# Test 1: Pinned vs unpinned — detect range prefixes
cleanup
mkdir -p "$FIXTURES_DIR/backend"
cat > "$FIXTURES_DIR/backend/package.json" << 'EOF'
{
  "name": "test-app",
  "dependencies": {
    "express": "4.21.2",
    "lodash": "^4.17.21",
    "axios": "~1.6.0"
  },
  "devDependencies": {
    "vitest": "3.2.1"
  },
  "engines": { "node": ">=22.0.0" }
}
EOF
UNPINNED=$(count_unpinned "$FIXTURES_DIR/backend/package.json")
if [ "$UNPINNED" -eq 2 ]; then
  assert_pass "pinned versions: detected 2 unpinned deps (lodash ^, axios ~), 2 pinned (express, vitest)"
else
  assert_fail "should detect exactly 2 unpinned deps, got $UNPINNED"
fi

# Test 2: Missing engines field
cleanup
mkdir -p "$FIXTURES_DIR/backend"
cat > "$FIXTURES_DIR/backend/package.json" << 'EOF'
{
  "name": "test-app",
  "dependencies": {
    "express": "4.21.2"
  }
}
EOF
if grep -q '"engines"' "$FIXTURES_DIR/backend/package.json"; then
  assert_fail "package.json without engines field should be detected"
else
  assert_pass "missing engines: detected (no engines field in package.json)"
fi

# Test 3: Unused dependency — listed but never imported
cleanup
mkdir -p "$FIXTURES_DIR/backend/routes"
cat > "$FIXTURES_DIR/backend/package.json" << 'EOF'
{
  "name": "test-app",
  "dependencies": {
    "express": "4.21.2",
    "uuid": "11.1.0"
  },
  "engines": { "node": ">=22.0.0" }
}
EOF
cat > "$FIXTURES_DIR/backend/routes/items.js" << 'EOF'
import express from 'express';
const router = express.Router();
export default router;
EOF
EXPRESS_IMPORTED=false
UUID_IMPORTED=false
is_dep_imported "express" "$FIXTURES_DIR/backend" && EXPRESS_IMPORTED=true
is_dep_imported "uuid" "$FIXTURES_DIR/backend" && UUID_IMPORTED=true
if [ "$EXPRESS_IMPORTED" = true ] && [ "$UUID_IMPORTED" = false ]; then
  assert_pass "unused dependency: express imported, uuid not imported — detected as unused"
else
  assert_fail "express should be imported ($EXPRESS_IMPORTED), uuid should not ($UUID_IMPORTED)"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-dependency-health tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
