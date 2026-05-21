#!/usr/bin/env bash
# Test: ascent-security-audit
# Verifies static security checks: env-file scope, hardcoded credentials, container privilege.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/security-audit"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-security-audit: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-security-audit: %s\n" "$1"
}

# Reusable: check if .env is gitignored (matches skill Step 1 logic)
check_env_gitignored() {
  local gitignore="$1"
  [ -f "$gitignore" ] && grep -q '^\.env' "$gitignore" 2>/dev/null
}

# Reusable: scan for hardcoded credential patterns (matches skill Step 2 logic)
scan_credentials() {
  local source_dir="$1"
  local matches
  matches=$(grep -rnE 'API_KEY=|SECRET=|PASSWORD=|TOKEN=|aws_access_key_id|aws_secret_access_key' \
    "$source_dir" 2>/dev/null || true)
  if [ -z "$matches" ]; then
    echo 0
  else
    echo "$matches" | grep -v 'node_modules\|dist\|\.git' | wc -l | tr -d ' '
  fi
}

# Reusable: check for privileged containers (matches skill Step 3 logic)
check_privileged() {
  local file="$1"
  grep -qE 'privileged:\s*true|--cap-add|SYS_ADMIN|SYS_PTRACE' "$file" 2>/dev/null
}

# Test 1: Env-file scope — gitignored PASS, not gitignored FAIL
cleanup
mkdir -p "$FIXTURES_DIR"
printf '.env\nnode_modules/\n' > "$FIXTURES_DIR/.gitignore"
IGNORED_OK=false
if check_env_gitignored "$FIXTURES_DIR/.gitignore"; then
  IGNORED_OK=true
fi
printf 'node_modules/\n' > "$FIXTURES_DIR/.gitignore"
NOT_IGNORED_OK=false
if ! check_env_gitignored "$FIXTURES_DIR/.gitignore"; then
  NOT_IGNORED_OK=true
fi
if [ "$IGNORED_OK" = true ] && [ "$NOT_IGNORED_OK" = true ]; then
  assert_pass "env-file scope: .env in gitignore=PASS, .env missing from gitignore=FAIL"
else
  assert_fail "env scope: ignored=$IGNORED_OK (want true), not_ignored=$NOT_IGNORED_OK (want true)"
fi

# Test 2: Hardcoded credential scan — clean source PASS, credential detected WARNING
cleanup
mkdir -p "$FIXTURES_DIR/backend/routes"
cat > "$FIXTURES_DIR/backend/routes/items.js" << 'EOF'
import express from 'express';
const router = express.Router();
export default router;
EOF
CLEAN_COUNT=$(scan_credentials "$FIXTURES_DIR/backend")
cat > "$FIXTURES_DIR/backend/routes/bad.js" << 'EOF'
const API_KEY="sk_live_abc123def456";
const db_PASSWORD="supersecret";
EOF
DIRTY_COUNT=$(scan_credentials "$FIXTURES_DIR/backend")
if [ "$CLEAN_COUNT" -eq 0 ] && [ "$DIRTY_COUNT" -ge 2 ]; then
  assert_pass "hardcoded credentials: clean source=0, source with credentials=$DIRTY_COUNT detected"
else
  assert_fail "credentials: clean=$CLEAN_COUNT (want 0), dirty=$DIRTY_COUNT (want >=2)"
fi

# Test 3: Privileged container detection — clean compose PASS, privileged FAIL
cleanup
mkdir -p "$FIXTURES_DIR"
cat > "$FIXTURES_DIR/docker-compose.yml" << 'EOF'
services:
  backend:
    build: ./backend
    ports:
      - "3001:3001"
EOF
CLEAN_PRIV=false
check_privileged "$FIXTURES_DIR/docker-compose.yml" || CLEAN_PRIV=true
cat > "$FIXTURES_DIR/docker-compose.yml" << 'EOF'
services:
  backend:
    build: ./backend
    privileged: true
    ports:
      - "3001:3001"
EOF
DIRTY_PRIV=false
check_privileged "$FIXTURES_DIR/docker-compose.yml" && DIRTY_PRIV=true
if [ "$CLEAN_PRIV" = true ] && [ "$DIRTY_PRIV" = true ]; then
  assert_pass "container privilege: clean compose=PASS, privileged compose=detected"
else
  assert_fail "privilege: clean=$CLEAN_PRIV (want true), dirty=$DIRTY_PRIV (want true)"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-security-audit tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
