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
# shellcheck source=lib/portable.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/portable.sh"

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-vitality: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-vitality: %s\n" "$1"
}

# Stand-ins for the skill's Step 1 and Step 3 logic.
# last_commit_age_days DIR — whole days since the newest commit (%ct, committer date).
last_commit_age_days() {
  local ct
  ct=$(git -C "$1" log -1 --format=%ct)
  printf '%s' $(( ($(date +%s) - ct) / 86400 ))
}

# stale_branch_count DIR [THRESHOLD_DAYS] — unmerged branches whose tip is older
# than the threshold (default 30 days).
stale_branch_count() {
  local d="$1" threshold="${2:-30}" now count=0 branch ct
  now=$(date +%s)
  while IFS= read -r branch; do
    [ -z "$branch" ] && continue
    ct=$(git -C "$d" log -1 --format=%ct "$branch")
    if [ $(( (now - ct) / 86400 )) -gt "$threshold" ]; then
      count=$((count + 1))
    fi
  done < <(git -C "$d" for-each-ref --no-merged=main --format='%(refname:short)' refs/heads)
  printf '%s' "$count"
}

# changelog_stance FILE — ACTIVE if the newest dated entry is ≤60 days old, else STALE.
changelog_stance() {
  local latest epoch
  latest=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$1" | head -1 || true)
  [ -n "$latest" ] || { printf 'UNKNOWN'; return 0; }
  epoch=$(ymd_to_epoch "$latest")
  if [ $(( ($(date +%s) - epoch) / 86400 )) -le 60 ]; then printf 'ACTIVE'; else printf 'STALE'; fi
}

write_changelog() {
  printf '# Changelog\n\n## v0.4.0 — %s\n\n### Added\n\n- All skills implemented\n' "$2" > "$1"
}

# Test 1: Last-commit age at the 14-day threshold — 13 days is ACTIVE, 15 is not.
cleanup
git_init_main "$FIXTURES_DIR"
echo "initial" > "$FIXTURES_DIR/file.txt"
git_commit_days_ago "$FIXTURES_DIR" 13 "recent commit"
RECENT_AGE=$(last_commit_age_days "$FIXTURES_DIR")
cleanup
git_init_main "$FIXTURES_DIR"
echo "initial" > "$FIXTURES_DIR/file.txt"
git_commit_days_ago "$FIXTURES_DIR" 15 "old commit"
OLD_AGE=$(last_commit_age_days "$FIXTURES_DIR")
if [ "$RECENT_AGE" -le 14 ] && [ "$OLD_AGE" -gt 14 ]; then
  assert_pass "last-commit age: recent=$RECENT_AGE days (ACTIVE), old=$OLD_AGE days (not ACTIVE)"
else
  assert_fail "last-commit age: recent=$RECENT_AGE (want ≤14), old=$OLD_AGE (want >14)"
fi

# Test 2: Stale-branch detection at the 30-day threshold — of two unmerged
# branches, the 31-day-old one is stale and the 29-day-old one is not.
cleanup
git_init_main "$FIXTURES_DIR"
echo "main" > "$FIXTURES_DIR/file.txt"
git_commit_days_ago "$FIXTURES_DIR" 50 "main commit"
git -C "$FIXTURES_DIR" checkout -q -b stale-feature
echo "stale" > "$FIXTURES_DIR/stale.txt"
git_commit_days_ago "$FIXTURES_DIR" 31 "stale branch commit"
git -C "$FIXTURES_DIR" checkout -q main
git -C "$FIXTURES_DIR" checkout -q -b fresh-feature
echo "fresh" > "$FIXTURES_DIR/fresh.txt"
git_commit_days_ago "$FIXTURES_DIR" 29 "fresh branch commit"
git -C "$FIXTURES_DIR" checkout -q main
STALE_BRANCHES=$(stale_branch_count "$FIXTURES_DIR")
if [ "$STALE_BRANCHES" -eq 1 ]; then
  assert_pass "stale-branch detection: 31-day branch stale, 29-day branch not (30-day threshold)"
else
  assert_fail "stale-branch detection: expected exactly 1 stale branch, got $STALE_BRANCHES"
fi

# Test 3: CHANGELOG recency at the 60-day threshold — 58 days ACTIVE, 62 days
# STALE (2-day margin: calendar dates, not timestamps).
cleanup
mkdir -p "$FIXTURES_DIR"
write_changelog "$FIXTURES_DIR/CHANGELOG.md" "$(ymd_days_ago 58)"
RECENT_STANCE=$(changelog_stance "$FIXTURES_DIR/CHANGELOG.md")
write_changelog "$FIXTURES_DIR/CHANGELOG.md" "$(ymd_days_ago 62)"
OLD_STANCE=$(changelog_stance "$FIXTURES_DIR/CHANGELOG.md")
if [ "$RECENT_STANCE" = "ACTIVE" ] && [ "$OLD_STANCE" = "STALE" ]; then
  assert_pass "CHANGELOG recency: 58-day entry ACTIVE, 62-day entry STALE (60-day threshold)"
else
  assert_fail "CHANGELOG recency: 58-day=$RECENT_STANCE (want ACTIVE), 62-day=$OLD_STANCE (want STALE)"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-vitality tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
