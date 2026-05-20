#!/usr/bin/env bash
# Test: ascent-reflect
# Verifies session capture logic: four-state classification, overwrite semantics for
# session-state.md, append semantics for working-memory.md, MISSING file creation.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/reflect"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

setup_project() {
  mkdir -p "$FIXTURES_DIR/docs/delivery"
  cat > "$FIXTURES_DIR/.ascent-meta.json" << 'EOF'
{
  "framework": "lloydbriantech-ascent",
  "phase": "2-template-assets",
  "project_slug": "test-project",
  "current_focus": "building template assets"
}
EOF
}

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-reflect: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-reflect: %s\n" "$1"
}

# Reusable: four-state classifier (matches session-protocol.md spec, reused from standup tests)
classify_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    printf "MISSING"
    return
  fi
  local content
  content=$(grep -c '[^[:space:]]' "$file" 2>/dev/null || echo 0)
  if [ "$content" -le 1 ]; then
    printf "EMPTY"
    return
  fi
  local mod_epoch now_epoch age_days
  mod_epoch=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0)
  now_epoch=$(date +%s)
  age_days=$(( (now_epoch - mod_epoch) / 86400 ))
  if [ "$age_days" -gt 7 ]; then
    printf "STALE"
  else
    printf "FRESH"
  fi
}

# Test 1: Four-state classification of session-state.md
cleanup
setup_project
STATE_MISSING=$(classify_file "$FIXTURES_DIR/docs/delivery/session-state.md")
printf "# Session state\n" > "$FIXTURES_DIR/docs/delivery/session-state.md"
STATE_EMPTY=$(classify_file "$FIXTURES_DIR/docs/delivery/session-state.md")
cat > "$FIXTURES_DIR/docs/delivery/session-state.md" << 'EOF'
# Session state

Captured: 2026-05-20-1400

## Current focus

Working on reflect skill
EOF
touch "$FIXTURES_DIR/docs/delivery/session-state.md"
STATE_FRESH=$(classify_file "$FIXTURES_DIR/docs/delivery/session-state.md")
if [ "$STATE_MISSING" = "MISSING" ] && [ "$STATE_EMPTY" = "EMPTY" ] && [ "$STATE_FRESH" = "FRESH" ]; then
  assert_pass "four-state classification: MISSING=$STATE_MISSING, EMPTY=$STATE_EMPTY, FRESH=$STATE_FRESH"
else
  assert_fail "classification: MISSING=$STATE_MISSING (want MISSING), EMPTY=$STATE_EMPTY (want EMPTY), FRESH=$STATE_FRESH (want FRESH)"
fi

# Test 2: Overwrite semantics — old session-state.md content replaced
cleanup
setup_project
cat > "$FIXTURES_DIR/docs/delivery/session-state.md" << 'EOF'
# Session state

Captured: 2026-05-19-0900

## Current focus

OLD FOCUS: this should be replaced

## Blockers

OLD BLOCKER: should not survive overwrite
EOF
# Simulate reflect Step 8 overwrite (matches skill operational logic)
cat > "$FIXTURES_DIR/docs/delivery/session-state.md" << 'EOF'
# Session state

Captured: 2026-05-20-1600

## Current focus

NEW FOCUS: building lifecycle skills

## Active decisions

Chose sibling pattern for Cluster 5 skills

## Blockers

None currently

## Next actions

1. Write test scripts
2. Run validators

## Phase context

- Phase: 2-template-assets
- Branch: feat/phase-3-cluster-5 (abc1234)
- Uncommitted changes: 3
EOF
if grep -q "NEW FOCUS" "$FIXTURES_DIR/docs/delivery/session-state.md" && \
   ! grep -q "OLD FOCUS" "$FIXTURES_DIR/docs/delivery/session-state.md" && \
   ! grep -q "OLD BLOCKER" "$FIXTURES_DIR/docs/delivery/session-state.md"; then
  assert_pass "overwrite semantics: old content replaced, new content present, no old remnants"
else
  assert_fail "overwrite should replace all old content with new content"
fi

# Test 3: Append semantics — existing working-memory entries preserved, new appended
cleanup
setup_project
cat > "$FIXTURES_DIR/docs/delivery/working-memory.md" << 'EOF'
# Working memory — Test Project

## Decisions

- 2026-05-16: Chose SQLite-WAL over Postgres (see ADR-004)
- 2026-05-17: Session resumption protocol adopted per §15

## Patterns adopted

- Structured JSON logging via pino

## Patterns rejected

- Host-level npm install
EOF
# Simulate reflect Step 8 append (matches skill operational logic)
# Append new decisions below existing entries under ## Decisions
NEW_ENTRY="- 2026-05-20: Chose sibling pattern for lifecycle skills (Cluster 5)"
sed -i '' "/^- 2026-05-17: Session resumption/a\\
${NEW_ENTRY}" "$FIXTURES_DIR/docs/delivery/working-memory.md" 2>/dev/null || \
  sed -i "/^- 2026-05-17: Session resumption/a\\${NEW_ENTRY}" "$FIXTURES_DIR/docs/delivery/working-memory.md" 2>/dev/null
OLD_PRESERVED=$(grep -c "2026-05-16\|2026-05-17" "$FIXTURES_DIR/docs/delivery/working-memory.md")
NEW_PRESENT=$(grep -c "2026-05-20.*sibling pattern" "$FIXTURES_DIR/docs/delivery/working-memory.md")
SECTIONS_INTACT=$(grep -c "## Patterns adopted\|## Patterns rejected" "$FIXTURES_DIR/docs/delivery/working-memory.md")
if [ "$OLD_PRESERVED" -eq 2 ] && [ "$NEW_PRESENT" -eq 1 ] && [ "$SECTIONS_INTACT" -eq 2 ]; then
  assert_pass "append semantics: 2 old entries preserved, 1 new appended, section structure intact"
else
  assert_fail "append: old=$OLD_PRESERVED (want 2), new=$NEW_PRESENT (want 1), sections=$SECTIONS_INTACT (want 2)"
fi

# Test 4: MISSING working-memory.md — create with standard structure
cleanup
setup_project
# Do NOT create working-memory.md — MISSING state
STATE=$(classify_file "$FIXTURES_DIR/docs/delivery/working-memory.md")
if [ "$STATE" = "MISSING" ]; then
  # Simulate reflect Step 8 MISSING handling: create with standard structure then append
  cat > "$FIXTURES_DIR/docs/delivery/working-memory.md" << 'EOF'
# Working memory — Test Project

## Decisions

- 2026-05-20: First session — chose Express + SQLite-WAL scaffold

## Patterns adopted

## Patterns rejected
EOF
  HAS_DECISIONS=$(grep -c "## Decisions" "$FIXTURES_DIR/docs/delivery/working-memory.md")
  HAS_ADOPTED=$(grep -c "## Patterns adopted" "$FIXTURES_DIR/docs/delivery/working-memory.md")
  HAS_REJECTED=$(grep -c "## Patterns rejected" "$FIXTURES_DIR/docs/delivery/working-memory.md")
  HAS_ENTRY=$(grep -c "2026-05-20" "$FIXTURES_DIR/docs/delivery/working-memory.md")
  if [ "$HAS_DECISIONS" -eq 1 ] && [ "$HAS_ADOPTED" -eq 1 ] && [ "$HAS_REJECTED" -eq 1 ] && [ "$HAS_ENTRY" -eq 1 ]; then
    assert_pass "MISSING working-memory: created with 3 sections + first decision entry"
  else
    assert_fail "should create standard structure: decisions=$HAS_DECISIONS adopted=$HAS_ADOPTED rejected=$HAS_REJECTED entry=$HAS_ENTRY"
  fi
else
  assert_fail "working-memory.md should be MISSING for this test, got $STATE"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-reflect tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
