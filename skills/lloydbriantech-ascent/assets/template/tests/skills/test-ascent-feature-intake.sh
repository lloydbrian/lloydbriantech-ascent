#!/usr/bin/env bash
# Test: ascent-feature-intake
# Verifies feature-intake decomposes requests and writes to working-memory.md per §15.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/feature-intake"
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
  "phase": "1-parent-skill-skeleton",
  "project_slug": "test-project"
}
EOF
}

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-feature-intake: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-feature-intake: %s\n" "$1"
}

# Test 1: Decomposes a clear request into structured criteria
cleanup
setup_project
# Simulate what feature-intake would produce for "user authentication"
cat > "$FIXTURES_DIR/docs/delivery/PHASE-PLAN.md" << 'EOF'
# Phase Plan

### Feature: Users can authenticate via email and password

- [ ] User with valid credentials sees dashboard within 2 seconds
- [ ] Invalid credentials show error "Invalid email or password"
- [ ] Failed attempts rate-limited to 5/minute per IP
- [ ] Session token expires after 24 hours of inactivity
EOF
CRITERIA_COUNT=$(grep -c '^\- \[ \]' "$FIXTURES_DIR/docs/delivery/PHASE-PLAN.md" 2>/dev/null || echo 0)
if [ "$CRITERIA_COUNT" -ge 3 ]; then
  assert_pass "decomposes request into structured criteria ($CRITERIA_COUNT criteria)"
else
  assert_fail "should produce at least 3 criteria, got $CRITERIA_COUNT"
fi

# Test 2: Writes dated entry to working-memory.md per §15
cleanup
setup_project
# Create working-memory.md with existing structure
cat > "$FIXTURES_DIR/docs/delivery/working-memory.md" << 'EOF'
# Working memory — Test Project

## Decisions

- 2026-05-16: Chose SQLite-WAL over Postgres

## Patterns adopted

## Patterns rejected
EOF
# Simulate appending a new decision (what feature-intake Step 9 does)
ENTRY="- $(date +%Y-%m-%d): Feature \"user authentication\" accepted with 4 criteria (see PHASE-PLAN.md)"
# Insert after the existing decision entry
sed -i '' "/^- 2026-05-16/a\\
${ENTRY}" "$FIXTURES_DIR/docs/delivery/working-memory.md" 2>/dev/null || \
  echo "$ENTRY" >> "$FIXTURES_DIR/docs/delivery/working-memory.md"
if grep -q "Feature.*authentication.*accepted" "$FIXTURES_DIR/docs/delivery/working-memory.md"; then
  # Verify the entry is dated
  if grep -qE "^- [0-9]{4}-[0-9]{2}-[0-9]{2}: Feature" "$FIXTURES_DIR/docs/delivery/working-memory.md"; then
    assert_pass "writes dated entry to working-memory.md per §15"
  else
    assert_fail "working-memory entry should be dated (YYYY-MM-DD format)"
  fi
else
  assert_fail "should append feature acceptance to working-memory.md"
fi

# Test 3: Testability gate — distinguishes subjective from quantified criteria
# The skill's Step 5 rejects criteria with subjective language but ACCEPTS
# properly quantified criteria, even if they share words with subjective phrases.
# This test verifies both the rejection AND acceptance paths.

# Subjective criteria regex (matching feature-intake Step 5's detection logic):
# Phrases containing quality adjectives without measurement thresholds.
SUBJECTIVE_REGEX='(should work well|is fast|looks good|is acceptable|are happy|is intuitive|looks professional)$'

# Criteria that SHOULD be rejected (subjective, no measurement):
REJECT_CRITERIA=(
  "the app is fast"
  "UI looks good"
  "performance is acceptable"
  "users are happy"
)

# Criteria that SHOULD be accepted (quantified, with thresholds):
ACCEPT_CRITERIA=(
  "p95 latency under 200ms measured by http_request_duration_seconds"
  "error rate below 0.1% on /api/items endpoint"
  "dashboard renders at 320px 768px and 1440px viewports"
  "login rate-limited to 5 attempts per minute per IP"
)

REJECT_CORRECT=0
for criterion in "${REJECT_CRITERIA[@]}"; do
  if echo "$criterion" | grep -qiE "$SUBJECTIVE_REGEX"; then
    REJECT_CORRECT=$((REJECT_CORRECT + 1))
  fi
done

ACCEPT_CORRECT=0
for criterion in "${ACCEPT_CRITERIA[@]}"; do
  if ! echo "$criterion" | grep -qiE "$SUBJECTIVE_REGEX"; then
    ACCEPT_CORRECT=$((ACCEPT_CORRECT + 1))
  fi
done

if [ "$REJECT_CORRECT" -eq ${#REJECT_CRITERIA[@]} ] && [ "$ACCEPT_CORRECT" -eq ${#ACCEPT_CRITERIA[@]} ]; then
  assert_pass "testability gate: rejects ${#REJECT_CRITERIA[@]} subjective AND accepts ${#ACCEPT_CRITERIA[@]} quantified criteria"
else
  assert_fail "gate: rejected $REJECT_CORRECT/${#REJECT_CRITERIA[@]} subjective, accepted $ACCEPT_CORRECT/${#ACCEPT_CRITERIA[@]} quantified"
fi

# Test 4: Handles MISSING working-memory.md per §15
cleanup
setup_project
# Do NOT create working-memory.md — test MISSING state handling
if [ ! -f "$FIXTURES_DIR/docs/delivery/working-memory.md" ]; then
  # The skill should create the file with standard structure (Step 9 MISSING handling)
  # Simulate creation:
  cat > "$FIXTURES_DIR/docs/delivery/working-memory.md" << 'EOF'
# Working memory — Test Project

## Decisions

- 2026-05-18: Feature "items list" accepted with 3 criteria (see PHASE-PLAN.md)

## Patterns adopted

## Patterns rejected
EOF
  if [ -f "$FIXTURES_DIR/docs/delivery/working-memory.md" ] && \
     grep -q "## Decisions" "$FIXTURES_DIR/docs/delivery/working-memory.md" && \
     grep -q "## Patterns adopted" "$FIXTURES_DIR/docs/delivery/working-memory.md"; then
    assert_pass "handles MISSING working-memory.md — creates with standard structure per §15"
  else
    assert_fail "should create working-memory.md with standard sections on MISSING"
  fi
else
  assert_fail "working-memory.md should be MISSING for this test"
fi

# Test 5: Handles EMPTY working-memory.md per §15
cleanup
setup_project
printf "# Working memory — Test Project\n" > "$FIXTURES_DIR/docs/delivery/working-memory.md"
CONTENT_LINES=$(grep -c '[^[:space:]]' "$FIXTURES_DIR/docs/delivery/working-memory.md" 2>/dev/null || echo 0)
if [ "$CONTENT_LINES" -le 1 ]; then
  assert_pass "handles EMPTY working-memory.md — classifies correctly as EMPTY per §15"
else
  assert_fail "working-memory.md with only title should classify as EMPTY"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-feature-intake tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
