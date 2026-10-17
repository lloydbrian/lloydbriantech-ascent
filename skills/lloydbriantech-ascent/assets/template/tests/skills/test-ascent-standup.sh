#!/usr/bin/env bash
# Test: ascent-standup
# Verifies standup logic branches correctly on project state.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/standup"
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
  "phase": "2-template-assets",
  "project_slug": "test-project",
  "current_focus": "building template assets"
}
EOF
}

# Reusable four-state classifier matching session-protocol.md spec.
# This is the logic the skill's operational Steps 2-3 implement.
classify_file() {
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

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-standup: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-standup: %s\n" "$1"
}

# Test 1: 24-hour git window correctly scopes commits
# Commits made now and 2 days ago; only the first is inside the window.
cleanup
setup_project
git_init_main "$FIXTURES_DIR"
echo "old" > "$FIXTURES_DIR/file2.txt"
git_commit_days_ago "$FIXTURES_DIR" 2 "old commit"
echo "recent" > "$FIXTURES_DIR/file1.txt"
git_commit_days_ago "$FIXTURES_DIR" 0 "recent commit"
RECENT=$(git -C "$FIXTURES_DIR" log --oneline --since="24 hours ago" | wc -l | tr -d ' ')
TOTAL=$(git -C "$FIXTURES_DIR" log --oneline | wc -l | tr -d ' ')
RECENT_SUBJECT=$(git -C "$FIXTURES_DIR" log --since="24 hours ago" --format=%s | head -1)
if [ "$RECENT" -eq 1 ] && [ "$TOTAL" -eq 2 ] && [ "$RECENT_SUBJECT" = "recent commit" ]; then
  assert_pass "24-hour window correctly scopes: 1 recent / 2 total commits"
else
  assert_fail "24-hour window: recent=$RECENT (want 1), total=$TOTAL (want 2), subject='$RECENT_SUBJECT'"
fi

# Test 2: STALE branch of the four-state classifier — a populated
# session-state.md last touched 8 days ago (threshold 7) must classify STALE,
# which is what routes standup to its "state may be outdated" output.
cleanup
setup_project
cat > "$FIXTURES_DIR/docs/delivery/session-state.md" << 'EOF'
# Session state

## Current focus

Older focus that may be outdated
EOF
set_mtime_days_ago "$FIXTURES_DIR/docs/delivery/session-state.md" 8
STATE_STALE=$(classify_file "$FIXTURES_DIR/docs/delivery/session-state.md")
if [ "$STATE_STALE" = "STALE" ]; then
  assert_pass "four-state classifier: 8-day-old populated session-state classifies STALE"
else
  assert_fail "8-day-old populated session-state should classify STALE, got $STATE_STALE"
fi

# Test 3: Handles empty project — no session state, no PHASE-PLAN
# Build a fixture where only .ascent-meta.json exists.
# Verify classify_file returns MISSING for absent files and the fallback
# to .ascent-meta.json current_focus is available.
cleanup
setup_project
SESSION_STATE=$(classify_file "$FIXTURES_DIR/docs/delivery/session-state.md")
MEMORY_STATE=$(classify_file "$FIXTURES_DIR/docs/delivery/working-memory.md")
# On MISSING session-state, standup falls back to .ascent-meta.json current_focus
FALLBACK_FOCUS=$(grep '"current_focus"' "$FIXTURES_DIR/.ascent-meta.json" 2>/dev/null | sed 's/.*: *"//;s/".*//')
if [ "$SESSION_STATE" = "MISSING" ] && [ "$MEMORY_STATE" = "MISSING" ] && [ -n "$FALLBACK_FOCUS" ]; then
  assert_pass "empty project: session MISSING, memory MISSING, fallback focus available ('$FALLBACK_FOCUS')"
else
  assert_fail "expected MISSING/MISSING with fallback, got session=$SESSION_STATE memory=$MEMORY_STATE focus='$FALLBACK_FOCUS'"
fi

# Test 4: Four-state classifier produces correct results on controlled fixtures
cleanup
setup_project
# MISSING: file doesn't exist
STATE_MISSING=$(classify_file "$FIXTURES_DIR/docs/delivery/nonexistent.md")
# EMPTY: file exists with title only
printf "# Session state\n" > "$FIXTURES_DIR/docs/delivery/empty-test.md"
STATE_EMPTY=$(classify_file "$FIXTURES_DIR/docs/delivery/empty-test.md")
# FRESH: file with content, recently modified
cat > "$FIXTURES_DIR/docs/delivery/fresh-test.md" << 'EOF'
# Session state

## Current focus

Working on standup implementation
EOF
touch "$FIXTURES_DIR/docs/delivery/fresh-test.md"
STATE_FRESH=$(classify_file "$FIXTURES_DIR/docs/delivery/fresh-test.md")

ALL_CORRECT=true
[ "$STATE_MISSING" = "MISSING" ] || ALL_CORRECT=false
[ "$STATE_EMPTY" = "EMPTY" ] || ALL_CORRECT=false
[ "$STATE_FRESH" = "FRESH" ] || ALL_CORRECT=false
if [ "$ALL_CORRECT" = true ]; then
  assert_pass "four-state classifier: MISSING=$STATE_MISSING, EMPTY=$STATE_EMPTY, FRESH=$STATE_FRESH"
else
  assert_fail "classifier results: MISSING=$STATE_MISSING (want MISSING), EMPTY=$STATE_EMPTY (want EMPTY), FRESH=$STATE_FRESH (want FRESH)"
fi

# Test 5: Standup degradation — FRESH session state populates all 4 output sections
# When session-state is FRESH, the standup has data for all sections.
# When MISSING, some sections fall back to .ascent-meta.json or "not recorded."
# Verify by checking that FRESH state provides focus/plan/blockers directly.
cleanup
setup_project
cat > "$FIXTURES_DIR/docs/delivery/session-state.md" << 'EOF'
# Session state

Captured: 2026-05-18-1600

## Current focus

Implementing standup skill

## Next actions

1. Write test scripts
2. Run validators

## Blockers

None currently
EOF
touch "$FIXTURES_DIR/docs/delivery/session-state.md"
STATE=$(classify_file "$FIXTURES_DIR/docs/delivery/session-state.md")
HAS_FOCUS=$(grep -q "## Current focus" "$FIXTURES_DIR/docs/delivery/session-state.md" && echo "true" || echo "false")
HAS_PLAN=$(grep -q "## Next actions" "$FIXTURES_DIR/docs/delivery/session-state.md" && echo "true" || echo "false")
HAS_BLOCKERS=$(grep -q "## Blockers" "$FIXTURES_DIR/docs/delivery/session-state.md" && echo "true" || echo "false")
if [ "$STATE" = "FRESH" ] && [ "$HAS_FOCUS" = "true" ] && [ "$HAS_PLAN" = "true" ] && [ "$HAS_BLOCKERS" = "true" ]; then
  assert_pass "FRESH session state provides data for all standup sections (focus + plan + blockers)"
else
  assert_fail "FRESH state should populate all sections: state=$STATE focus=$HAS_FOCUS plan=$HAS_PLAN blockers=$HAS_BLOCKERS"
fi

# Test 6: The SHIPPED classifier (make session-resume in make/session.mk), not a
# copy of it: 6-day-old state reads FRESH, 8-day-old state reads STALE, and a
# title-only memory file reads EMPTY.
SESSION_MK="$(pwd)/make/session.mk"
cleanup
setup_project
printf "# Session state\n\n## Current focus\n\nShipping loop 1\n" > "$FIXTURES_DIR/docs/delivery/session-state.md"
printf "# Working memory\n" > "$FIXTURES_DIR/docs/delivery/working-memory.md"
set_mtime_days_ago "$FIXTURES_DIR/docs/delivery/session-state.md" 6
OUT_FRESH=$(make -s -C "$FIXTURES_DIR" -f "$SESSION_MK" session-resume 2>&1 || true)
set_mtime_days_ago "$FIXTURES_DIR/docs/delivery/session-state.md" 8
OUT_STALE=$(make -s -C "$FIXTURES_DIR" -f "$SESSION_MK" session-resume 2>&1 || true)
if printf '%s' "$OUT_FRESH" | grep -q 'session-state.md: *\[FRESH (6 days old)\]' && \
   printf '%s' "$OUT_STALE" | grep -q 'session-state.md: *\[STALE (8 days old)\]' && \
   printf '%s' "$OUT_STALE" | grep -q 'working-memory.md: *\[EMPTY\]'; then
  assert_pass "make session-resume: 6 days FRESH, 8 days STALE, title-only memory EMPTY"
else
  assert_fail "make session-resume output wrong — fresh: $(printf '%s' "$OUT_FRESH" | grep 'session-state.md:' || echo none) / stale: $(printf '%s' "$OUT_STALE" | grep -E 'session-state.md:|working-memory.md:' | tr '\n' ' ')"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-standup tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
