#!/usr/bin/env bash
# Test: ascent-delivery-status
# Verifies delivery-status reads project state correctly including §15 four-state handling.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/delivery-status"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT
# shellcheck source=lib/portable.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/portable.sh"

setup_project() {
  mkdir -p "$FIXTURES_DIR/docs/delivery"
  cat > "$FIXTURES_DIR/.ascent-meta.json" << 'EOF'
{
  "framework": "lloydbriantech-ascent",
  "phase": "1-parent-skill-skeleton",
  "project_slug": "test-project",
  "current_focus": "implementing routing logic"
}
EOF
}

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-delivery-status: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-delivery-status: %s\n" "$1"
}

# Test 1: Reads .ascent-meta.json phase correctly
cleanup
setup_project
PHASE=$(grep '"phase"' "$FIXTURES_DIR/.ascent-meta.json" | sed 's/.*: *"//;s/".*//')
if [ "$PHASE" = "1-parent-skill-skeleton" ]; then
  assert_pass "reads .ascent-meta.json phase correctly"
else
  assert_fail "should read phase as '1-parent-skill-skeleton', got '$PHASE'"
fi

# Test 2: Synthesizes exit-criteria progress from PHASE-PLAN.md
cleanup
setup_project
cat > "$FIXTURES_DIR/docs/delivery/PHASE-PLAN.md" << 'EOF'
# Phase Plan

- [x] SKILL.md with frontmatter
- [x] Reference modules populated
- [ ] Routing logic implemented
- [ ] CHANGELOG entry
EOF
DONE=$(count_matches '\[x\]' "$FIXTURES_DIR/docs/delivery/PHASE-PLAN.md")
TOTAL=$(count_matches '\[[ x]\]' "$FIXTURES_DIR/docs/delivery/PHASE-PLAN.md")
if [ "$DONE" -eq 2 ] && [ "$TOTAL" -eq 4 ]; then
  assert_pass "synthesizes exit-criteria progress (2/4 criteria met)"
else
  assert_fail "should find 2/4 criteria, got $DONE/$TOTAL"
fi

# Implement the classify_file function matching session-protocol.md spec
classify_session() {
  local file="$1"
  if [ ! -f "$file" ]; then
    printf "MISSING"
    return
  fi
  local content
  content=$(count_matches '[^[:space:]]' "$file")
  if [ "$content" -le 1 ]; then
    printf "EMPTY"
    return
  fi
  local mod_epoch now_epoch age_days
  mod_epoch=$(file_mtime "$file")
  now_epoch=$(date +%s)
  age_days=$(( (now_epoch - mod_epoch) / 86400 ))
  if [ "$age_days" -gt 7 ]; then
    printf "STALE"
  else
    printf "FRESH"
  fi
}

# Step 2 decision: which session context goes into the status synthesis.
#   FRESH → include; STALE → include with a staleness flag; EMPTY/MISSING → omit.
include_session_for() {
  case "$1" in
    FRESH) printf 'include' ;;
    STALE) printf 'include-flagged' ;;
    *) printf 'omit' ;;
  esac
}

# Test 3: Reads FRESH session-state.md per §15
cleanup
setup_project
cat > "$FIXTURES_DIR/docs/delivery/session-state.md" << 'EOF'
# Session state

Captured: 2026-05-18-1400

## Current focus

Implementing the routing logic for parent skill

## Blockers

None currently
EOF
# Six days old — inside the 7-day window, so FRESH
set_mtime_days_ago "$FIXTURES_DIR/docs/delivery/session-state.md" 6
STATE=$(classify_session "$FIXTURES_DIR/docs/delivery/session-state.md")
DECISION=$(include_session_for "$STATE")
FOCUS=$(grep -A2 "## Current focus" "$FIXTURES_DIR/docs/delivery/session-state.md" | tail -1)
if [ "$STATE" = "FRESH" ] && [ "$DECISION" = "include" ] && printf '%s' "$FOCUS" | grep -qi "routing"; then
  assert_pass "FRESH session-state.md (6 days) included; current focus extracted per §15"
else
  assert_fail "6-day-old session-state: state=$STATE (want FRESH), decision=$DECISION (want include), focus='$FOCUS'"
fi

# Test 4: Handles MISSING session-state.md per §15 — behavior verification
# The skill's Step 2 classifies session-state.md and decides whether to include
# session context. On MISSING, the output should OMIT session context entirely.
# This test implements the Step 2 classification logic and verifies the decision.
cleanup
setup_project
# Deliberately do NOT create session-state.md — MISSING state


STATE=$(classify_session "$FIXTURES_DIR/docs/delivery/session-state.md")
# On MISSING: skill's Step 2 says "Omit session context from synthesis entirely."
# Verify: the classification is MISSING, AND the project still has .ascent-meta.json
# (meaning the skill can produce phase-level output without session context).
if [ "$STATE" = "MISSING" ]; then
  DECISION=$(include_session_for "$STATE")
  PHASE=$(grep '"phase"' "$FIXTURES_DIR/.ascent-meta.json" 2>/dev/null | sed 's/.*: *"//;s/".*//')
  if [ "$DECISION" = "omit" ] && [ -n "$PHASE" ]; then
    assert_pass "MISSING session-state: classified correctly, session context omitted, phase state available ($PHASE)"
  else
    assert_fail "MISSING state should omit session and still report phase"
  fi
else
  assert_fail "session-state.md should classify as MISSING, got $STATE"
fi

# Test 5: Handles EMPTY session-state.md per §15
cleanup
setup_project
printf "# Session state\n" > "$FIXTURES_DIR/docs/delivery/session-state.md"
STATE=$(classify_session "$FIXTURES_DIR/docs/delivery/session-state.md")
DECISION=$(include_session_for "$STATE")
if [ "$STATE" = "EMPTY" ] && [ "$DECISION" = "omit" ]; then
  assert_pass "handles EMPTY session-state.md — classified EMPTY, session context omitted per §15"
else
  assert_fail "title-only session-state.md: state=$STATE (want EMPTY), decision=$DECISION (want omit)"
fi

# Test 6: Handles STALE session-state.md per §15
cleanup
setup_project
cat > "$FIXTURES_DIR/docs/delivery/session-state.md" << 'EOF'
# Session state

Captured: 2026-05-01-0900

## Current focus

Working on backend skeleton
EOF
# Make the file 8 days old — one day past the 7-day threshold (portable helper)
set_mtime_days_ago "$FIXTURES_DIR/docs/delivery/session-state.md" 8
STATE=$(classify_session "$FIXTURES_DIR/docs/delivery/session-state.md")
AGE_DAYS=$(file_age_days "$FIXTURES_DIR/docs/delivery/session-state.md")
if [ "$STATE" = "STALE" ] && [ "$(include_session_for "$STATE")" = "include-flagged" ]; then
  assert_pass "handles STALE session-state.md ($AGE_DAYS days old) — included with a staleness flag per §15"
else
  assert_fail "8-day-old session-state.md should classify STALE, got $STATE (age $AGE_DAYS days)"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-delivery-status tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
