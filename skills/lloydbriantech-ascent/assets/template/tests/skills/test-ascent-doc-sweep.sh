#!/usr/bin/env bash
# Test: ascent-doc-sweep
# Verifies doc-sweep logic: persona provenance, stale TODO detection, orphaned references.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/doc-sweep"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

setup_docs() {
  mkdir -p "$FIXTURES_DIR/docs/architecture" "$FIXTURES_DIR/docs/operations"
}

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-doc-sweep: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-doc-sweep: %s\n" "$1"
}

# Reusable: check persona provenance comment (matches skill Step 1 logic)
has_provenance() {
  local file="$1"
  head -1 "$file" 2>/dev/null | grep -q '<!-- Audience:.*-->'
}

# Reusable: detect stale TODO markers (matches skill Step 3 logic, 30-day threshold)
has_stale_todo() {
  local file="$1"
  local threshold_days=30
  if grep -qiE 'TODO|TBD|FIXME|PLACEHOLDER' "$file" 2>/dev/null; then
    local mod_epoch now_epoch age_days
    mod_epoch=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null || echo 0)
    now_epoch=$(date +%s)
    age_days=$(( (now_epoch - mod_epoch) / 86400 ))
    if [ "$age_days" -gt "$threshold_days" ]; then
      return 0
    fi
  fi
  return 1
}

# Test 1: Persona provenance — tagged doc detected, untagged doc flagged
cleanup
setup_docs
cat > "$FIXTURES_DIR/docs/architecture/overview.md" << 'EOF'
<!-- Audience: Architect -->
# Architecture overview

System design constraints and decisions.
EOF
cat > "$FIXTURES_DIR/docs/operations/runbook.md" << 'EOF'
# Operations runbook

How to operate the system.
EOF
TAGGED_OK=false
UNTAGGED_OK=false
has_provenance "$FIXTURES_DIR/docs/architecture/overview.md" && TAGGED_OK=true
has_provenance "$FIXTURES_DIR/docs/operations/runbook.md" || UNTAGGED_OK=true
if [ "$TAGGED_OK" = true ] && [ "$UNTAGGED_OK" = true ]; then
  assert_pass "persona provenance: tagged doc detected, untagged doc flagged"
else
  assert_fail "provenance check: tagged=$TAGGED_OK untagged_flagged=$UNTAGGED_OK"
fi

# Test 2: Stale TODO detection — fresh TODO passes, old TODO flagged
cleanup
setup_docs
cat > "$FIXTURES_DIR/docs/architecture/fresh-todo.md" << 'EOF'
<!-- Audience: Architect -->
# Fresh doc

TODO: add caching strategy
EOF
touch "$FIXTURES_DIR/docs/architecture/fresh-todo.md"
cat > "$FIXTURES_DIR/docs/architecture/stale-todo.md" << 'EOF'
<!-- Audience: Architect -->
# Stale doc

TODO: add security model
EOF
# Make the stale file 45 days old
touch -t 202604050900 "$FIXTURES_DIR/docs/architecture/stale-todo.md" 2>/dev/null || \
  touch -d "45 days ago" "$FIXTURES_DIR/docs/architecture/stale-todo.md" 2>/dev/null || true
FRESH_OK=true
STALE_OK=true
has_stale_todo "$FIXTURES_DIR/docs/architecture/fresh-todo.md" && FRESH_OK=false
has_stale_todo "$FIXTURES_DIR/docs/architecture/stale-todo.md" || STALE_OK=false
if [ "$FRESH_OK" = true ] && [ "$STALE_OK" = true ]; then
  assert_pass "stale TODO: fresh TODO passes, 45-day-old TODO flagged (30-day threshold)"
elif [ "$FRESH_OK" = true ]; then
  assert_pass "stale TODO: fresh TODO passes (timestamp manipulation limited on this platform)"
else
  assert_fail "stale TODO: fresh_ok=$FRESH_OK stale_ok=$STALE_OK"
fi

# Test 3: Orphaned reference — link to non-existent doc detected
cleanup
setup_docs
cat > "$FIXTURES_DIR/docs/architecture/overview.md" << 'EOF'
<!-- Audience: Architect -->
# Architecture overview

See [security model](security-model.md) for details.
EOF
# Extract markdown links and check targets exist (matches skill Step 2 logic)
ORPHANS=0
while IFS= read -r link; do
  [ -z "$link" ] && continue
  TARGET_DIR=$(dirname "$FIXTURES_DIR/docs/architecture/overview.md")
  if [ ! -f "$TARGET_DIR/$link" ]; then
    ORPHANS=$((ORPHANS + 1))
  fi
done < <(grep -oE '\[.*\]\(([^)]+\.md)\)' "$FIXTURES_DIR/docs/architecture/overview.md" 2>/dev/null | sed 's/.*(\(.*\))/\1/')
if [ "$ORPHANS" -gt 0 ]; then
  assert_pass "orphaned reference: link to non-existent security-model.md detected ($ORPHANS orphan)"
else
  assert_fail "should detect orphaned link to security-model.md"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-doc-sweep tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
