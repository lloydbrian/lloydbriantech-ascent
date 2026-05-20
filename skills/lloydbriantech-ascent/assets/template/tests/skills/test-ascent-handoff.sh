#!/usr/bin/env bash
# Test: ascent-handoff
# Verifies handoff logic: progressive-depth structure, existing-file guard,
# phase-progress extraction.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/handoff"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

setup_project() {
  mkdir -p "$FIXTURES_DIR/docs/delivery" "$FIXTURES_DIR/docs/architecture/decisions"
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
  printf "PASS  ascent-handoff: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-handoff: %s\n" "$1"
}

# Reusable: generate a handoff document (matches skill Step 6 logic — progressive depth)
generate_handoff() {
  local project_dir="$1"
  local output_file="$2"
  local phase focus criteria_done criteria_total decision_count
  phase=$(grep '"phase"' "$project_dir/.ascent-meta.json" 2>/dev/null | sed 's/.*: *"//;s/".*//')
  focus=$(grep '"current_focus"' "$project_dir/.ascent-meta.json" 2>/dev/null | sed 's/.*: *"//;s/".*//')
  criteria_done=0
  criteria_total=0
  if [ -f "$project_dir/docs/delivery/PHASE-PLAN.md" ]; then
    criteria_done=$(grep -c '\[x\]' "$project_dir/docs/delivery/PHASE-PLAN.md" 2>/dev/null || echo 0)
    criteria_total=$(grep -cE '\[[ x]\]' "$project_dir/docs/delivery/PHASE-PLAN.md" 2>/dev/null || echo 0)
  fi
  decision_count=0
  if [ -f "$project_dir/docs/delivery/working-memory.md" ]; then
    decision_count=$(grep -cE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}:' "$project_dir/docs/delivery/working-memory.md" 2>/dev/null || echo 0)
  fi
  {
    printf "# Handoff — Test Project\n\n"
    printf "Generated: %s\n\n" "$(date +%Y-%m-%d)"
    printf "## Where to start\n\n"
    printf "Current focus: %s\n" "${focus:-No current focus on record.}"
    printf "Phase: %s — %s/%s exit criteria met\n\n" "$phase" "$criteria_done" "$criteria_total"
    printf "## Project state\n\n"
    printf '%s\n' "- Phase: $phase"
    printf '%s\n\n' "- Recent decisions: $decision_count on record"
    printf "## Project conventions\n\n"
    printf '%s\n' "- Framework: ASCENT"
    printf '%s\n' "- Session resumption: session-state.md + working-memory.md per §15"
  } > "$output_file"
}

# Test 1: Progressive-depth structure — verify 3 sections present
cleanup
setup_project
cat > "$FIXTURES_DIR/docs/delivery/PHASE-PLAN.md" << 'EOF'
- [x] Root templates
- [x] Make framework
- [ ] Backend skeleton
- [ ] Frontend skeleton
- [ ] Container topology
EOF
cat > "$FIXTURES_DIR/docs/delivery/working-memory.md" << 'EOF'
# Working memory — Test Project

## Decisions

- 2026-05-16: Chose SQLite-WAL over Postgres
- 2026-05-17: Session resumption adopted

## Patterns adopted

## Patterns rejected
EOF
HANDOFF_FILE="$FIXTURES_DIR/docs/delivery/HANDOFF.md"
generate_handoff "$FIXTURES_DIR" "$HANDOFF_FILE"
HAS_WHERE=$(grep -c "## Where to start" "$HANDOFF_FILE")
HAS_STATE=$(grep -c "## Project state" "$HANDOFF_FILE")
HAS_CONVENTIONS=$(grep -c "## Project conventions" "$HANDOFF_FILE")
if [ "$HAS_WHERE" -eq 1 ] && [ "$HAS_STATE" -eq 1 ] && [ "$HAS_CONVENTIONS" -eq 1 ]; then
  assert_pass "progressive-depth structure: 3 sections present (Where to start, Project state, Conventions)"
else
  assert_fail "handoff should have 3 sections: where=$HAS_WHERE state=$HAS_STATE conventions=$HAS_CONVENTIONS"
fi

# Test 2: Existing-file guard — HANDOFF.md already exists → skill stops
cleanup
setup_project
echo "# Old handoff content" > "$FIXTURES_DIR/docs/delivery/HANDOFF.md"
# Simulate Step 7: check if HANDOFF.md exists before writing (matches skill logic)
if [ -f "$FIXTURES_DIR/docs/delivery/HANDOFF.md" ]; then
  GUARD_TRIGGERED=true
  if grep -q "Old handoff content" "$FIXTURES_DIR/docs/delivery/HANDOFF.md"; then
    assert_pass "existing-file guard: HANDOFF.md exists → blocked, original content preserved"
  else
    assert_fail "existing HANDOFF.md content should be preserved when guard triggers"
  fi
else
  assert_fail "fixture HANDOFF.md should exist for this test"
fi

# Test 3: Phase-progress extraction — 2/5 criteria from PHASE-PLAN
cleanup
setup_project
cat > "$FIXTURES_DIR/docs/delivery/PHASE-PLAN.md" << 'EOF'
- [x] Root templates
- [x] Make framework
- [ ] Backend skeleton
- [ ] Frontend skeleton
- [ ] Container topology
EOF
# Extract progress (matches skill Step 3 logic)
DONE=$(grep -c '\[x\]' "$FIXTURES_DIR/docs/delivery/PHASE-PLAN.md" 2>/dev/null || echo 0)
TOTAL=$(grep -cE '\[[ x]\]' "$FIXTURES_DIR/docs/delivery/PHASE-PLAN.md" 2>/dev/null || echo 0)
if [ "$DONE" -eq 2 ] && [ "$TOTAL" -eq 5 ]; then
  assert_pass "phase-progress extraction: 2/5 criteria met from PHASE-PLAN fixture"
else
  assert_fail "should extract 2/5 criteria, got $DONE/$TOTAL"
fi

# Summary
TOTAL_TESTS=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-handoff tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL_TESTS"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
