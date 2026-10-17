#!/usr/bin/env bash
# Test: ascent-env-audit
# Verifies the env audit detects correct discipline and violations.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/env-audit"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT
# shellcheck source=lib/portable.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/portable.sh"

setup_valid_env() {
  mkdir -p "$FIXTURES_DIR"
  printf "<<ENV_PREFIX>>_PORT=\n<<ENV_PREFIX>>_DB_URL=\n" > "$FIXTURES_DIR/.env.example"
  printf ".env\n.env.local\n!.env.example\n" > "$FIXTURES_DIR/.gitignore"
  printf ".env\n" > "$FIXTURES_DIR/.dockerignore"
}

assert_pass() {
  local desc="$1"
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-env-audit: %s\n" "$desc"
}

assert_fail() {
  local desc="$1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-env-audit: %s\n" "$desc"
}

# Stand-ins for the skill's Steps 1-5. Each returns a count or a status the
# tests assert on, for both a clean fixture and a broken one.

# ignore_status DIR — OK when .env is listed in both .gitignore and .dockerignore.
ignore_status() {
  if [ "$(count_matches '^\.env$' "$1/.gitignore")" -ge 1 ] && \
     [ "$(count_matches '^\.env$' "$1/.dockerignore")" -ge 1 ]; then
    printf 'OK'
  else
    printf 'FAIL'
  fi
}

# non_empty_defaults FILE — keys in .env.example that ship a value (Step 4).
non_empty_defaults() {
  count_matches '^[^#=[:space:]]+=.+' "$1"
}

# placeholder_values FILE — REPLACE_ME-style placeholders (Step 4).
placeholder_values() {
  count_matches '(REPLACE_ME|<your-[a-z-]+>|YOUR_[A-Z_]+_HERE)' "$1"
}

# undeclared_reads DIR — env vars read in backend code but absent from .env.example (Step 5).
undeclared_reads() {
  local d="$1" missing=0 var
  while IFS= read -r var; do
    [ -z "$var" ] && continue
    if [ "$(count_matches "^${var}=" "$d/.env.example")" -eq 0 ]; then
      missing=$((missing + 1))
    fi
  done < <(grep -rhoE "process\.env(\['|\.)[A-Za-z0-9_<>]+" "$d/backend" 2>/dev/null \
             | sed -E "s/process\.env(\['|\.)//" | sort -u || true)
  printf '%s' "$missing"
}

# schema_status DIR — Step 1: .env.example must exist.
schema_status() {
  if [ -f "$1/.env.example" ]; then printf 'PRESENT'; else printf 'MISSING'; fi
}

# Test 1: Valid env discipline passes; a shipped default value fails it
cleanup
setup_valid_env
CLEAN_IGNORE=$(ignore_status "$FIXTURES_DIR")
CLEAN_DEFAULTS=$(non_empty_defaults "$FIXTURES_DIR/.env.example")
printf "<<ENV_PREFIX>>_LOG_LEVEL=debug\n" >> "$FIXTURES_DIR/.env.example"
DIRTY_DEFAULTS=$(non_empty_defaults "$FIXTURES_DIR/.env.example")
printf ".env.local\n" > "$FIXTURES_DIR/.gitignore"
NOT_GITIGNORED=$(ignore_status "$FIXTURES_DIR")
printf ".env\n" > "$FIXTURES_DIR/.gitignore"
rm -f "$FIXTURES_DIR/.dockerignore"
NO_DOCKERIGNORE=$(ignore_status "$FIXTURES_DIR")
if [ "$CLEAN_IGNORE" = "OK" ] && [ "$NOT_GITIGNORED" = "FAIL" ] && [ "$NO_DOCKERIGNORE" = "FAIL" ] && \
   [ "$CLEAN_DEFAULTS" -eq 0 ] && [ "$DIRTY_DEFAULTS" -eq 1 ]; then
  assert_pass ".env ignored (not-gitignored and missing .dockerignore both flagged); empty defaults pass, a shipped value is flagged"
else
  assert_fail "ignore=$CLEAN_IGNORE (want OK), not-gitignored=$NOT_GITIGNORED (want FAIL), no-dockerignore=$NO_DOCKERIGNORE (want FAIL), clean defaults=$CLEAN_DEFAULTS (want 0), dirty=$DIRTY_DEFAULTS (want 1)"
fi

# Test 2: REPLACE_ME placeholder detected, clean file not flagged
cleanup
setup_valid_env
CLEAN_PH=$(placeholder_values "$FIXTURES_DIR/.env.example")
printf "<<ENV_PREFIX>>_API_KEY=sk-REPLACE_ME\n" >> "$FIXTURES_DIR/.env.example"
DIRTY_PH=$(placeholder_values "$FIXTURES_DIR/.env.example")
if [ "$CLEAN_PH" -eq 0 ] && [ "$DIRTY_PH" -eq 1 ]; then
  assert_pass "REPLACE_ME placeholder detected in .env.example (clean file passes)"
else
  assert_fail "placeholders: clean=$CLEAN_PH (want 0), dirty=$DIRTY_PH (want 1)"
fi

# Test 3: Code-read not in .env.example detected; declared read passes
cleanup
setup_valid_env
mkdir -p "$FIXTURES_DIR/backend"
printf "const port = process.env['<<ENV_PREFIX>>_PORT'];\n" > "$FIXTURES_DIR/backend/server.js"
DECLARED_ONLY=$(undeclared_reads "$FIXTURES_DIR")
printf "const url = process.env['<<ENV_PREFIX>>_REDIS_URL'];\n" >> "$FIXTURES_DIR/backend/server.js"
WITH_UNDECLARED=$(undeclared_reads "$FIXTURES_DIR")
if [ "$DECLARED_ONLY" -eq 0 ] && [ "$WITH_UNDECLARED" -eq 1 ]; then
  assert_pass "code-read env var not in .env.example detected (declared read passes)"
else
  assert_fail "undeclared reads: declared-only=$DECLARED_ONLY (want 0), with REDIS=$WITH_UNDECLARED (want 1)"
fi

# Test 4: Missing .env.example detected (Step 1); present schema passes
cleanup
mkdir -p "$FIXTURES_DIR"
printf ".env\n" > "$FIXTURES_DIR/.gitignore"
MISSING_STATE=$(schema_status "$FIXTURES_DIR")
setup_valid_env
PRESENT_STATE=$(schema_status "$FIXTURES_DIR")
if [ "$MISSING_STATE" = "MISSING" ] && [ "$PRESENT_STATE" = "PRESENT" ]; then
  assert_pass "missing .env.example detected; present schema passes"
else
  assert_fail "schema status: without=$MISSING_STATE (want MISSING), with=$PRESENT_STATE (want PRESENT)"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-env-audit tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
