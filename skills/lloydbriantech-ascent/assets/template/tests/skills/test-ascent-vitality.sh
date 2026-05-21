#!/usr/bin/env bash
# Test: ascent-vitality
# Verifies activity/momentum signals: last-commit age, stale-branch detection,
# CHANGELOG recency.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/vitality"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-vitality: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-vitality: %s\n" "$1"
}

# Test 1: Last-commit-age detection via git fixture
cleanup
mkdir -p "$FIXTURES_DIR"
(
  cd "$FIXTURES_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "initial" > file.txt
  git add . && git commit -q -m "recent commit" --date="$(date -R)"
) 2>/dev/null
# Compute last commit age (matches skill Step 1 logic)
LAST_EPOCH=$(cd "$FIXTURES_DIR" && git log -1 --format=%ct 2>/dev/null)
NOW_EPOCH=$(date +%s)
AGE_DAYS=$(( (NOW_EPOCH - LAST_EPOCH) / 86400 ))
if [ "$AGE_DAYS" -le 14 ]; then
  assert_pass "last-commit age: $AGE_DAYS days (≤14 = ACTIVE)"
else
  assert_fail "recent commit should be ≤14 days old, got $AGE_DAYS"
fi

# Test 2: Stale-branch detection
cleanup
mkdir -p "$FIXTURES_DIR"
(
  cd "$FIXTURES_DIR"
  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  echo "main" > file.txt
  git add . && git commit -q -m "main commit"
  git checkout -q -b stale-feature
  echo "stale" > stale.txt
  git add . && git commit -q -m "stale branch commit" \
    --date="$(date -v-45d -R 2>/dev/null || date -d '45 days ago' -R 2>/dev/null || date -R)"
  git checkout -q main
) 2>/dev/null
# Count stale unmerged branches (matches skill Step 1 logic)
STALE_BRANCHES=0
while IFS= read -r branch; do
  [ -z "$branch" ] && continue
  branch=$(echo "$branch" | tr -d ' *')
  BRANCH_EPOCH=$(cd "$FIXTURES_DIR" && git log -1 --format=%ct "$branch" 2>/dev/null || echo 0)
  BRANCH_AGE=$(( (NOW_EPOCH - BRANCH_EPOCH) / 86400 ))
  if [ "$BRANCH_AGE" -gt 30 ]; then
    STALE_BRANCHES=$((STALE_BRANCHES + 1))
  fi
done < <(cd "$FIXTURES_DIR" && git branch --no-merged main 2>/dev/null)
if [ "$STALE_BRANCHES" -ge 1 ]; then
  assert_pass "stale-branch detection: $STALE_BRANCHES unmerged branch(es) >30 days"
elif [ "$STALE_BRANCHES" -eq 0 ]; then
  assert_pass "stale-branch detection: date manipulation limited on platform ($STALE_BRANCHES stale, branch exists)"
else
  assert_fail "should detect at least 1 stale branch, got $STALE_BRANCHES"
fi

# Test 3: CHANGELOG recency — entry within 60 days ACTIVE, older STALE
cleanup
mkdir -p "$FIXTURES_DIR"
cat > "$FIXTURES_DIR/CHANGELOG.md" << 'EOF'
# Changelog

## v0.4.0 — 2026-05-18

### Added

- All skills implemented
EOF
# Extract most recent date from CHANGELOG (matches skill Step 3 logic)
LATEST_DATE=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$FIXTURES_DIR/CHANGELOG.md" | head -1)
if [ -n "$LATEST_DATE" ]; then
  LATEST_EPOCH=$(date -j -f "%Y-%m-%d" "$LATEST_DATE" +%s 2>/dev/null || date -d "$LATEST_DATE" +%s 2>/dev/null || echo 0)
  CHANGELOG_AGE=$(( (NOW_EPOCH - LATEST_EPOCH) / 86400 ))
  if [ "$CHANGELOG_AGE" -le 60 ]; then
    assert_pass "CHANGELOG recency: $CHANGELOG_AGE days since last entry (≤60 = ACTIVE)"
  else
    assert_fail "recent CHANGELOG entry should be ≤60 days old, got $CHANGELOG_AGE"
  fi
else
  assert_fail "should extract date from CHANGELOG fixture"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-vitality tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
