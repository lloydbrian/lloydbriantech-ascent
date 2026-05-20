#!/usr/bin/env bash
# Test: ascent-skills-doctor
# Verifies skill collection integrity: frontmatter validation, INTENT-MAP sync,
# cross-skill reference integrity.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/skills-doctor"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

setup_skill_collection() {
  mkdir -p "$FIXTURES_DIR/.claude/skills/ascent-foo" \
           "$FIXTURES_DIR/.claude/skills/ascent-bar"
  cat > "$FIXTURES_DIR/.claude/skills/ascent-foo/SKILL.md" << 'EOF'
---
name: ascent-foo
description: A test skill for validation.
version: 1.0.0
allowed-tools:
  - Read
  - Grep
---

# ascent-foo

Test skill. References [ascent-bar](../ascent-bar/SKILL.md).

## Operational logic

### Step 1 — Read project state

**Condition:** Project root exists.
**Action on PASS:** Report findings.
EOF
  cat > "$FIXTURES_DIR/.claude/skills/ascent-bar/SKILL.md" << 'EOF'
---
name: ascent-bar
description: Another test skill.
version: 1.0.0
allowed-tools:
  - Read
---

# ascent-bar

Test skill.

## Operational logic

### Step 1 — Check state

**Condition:** Files exist.
**Action on PASS:** Report.
EOF
  cat > "$FIXTURES_DIR/.claude/skills/INTENT-MAP.md" << 'EOF'
# INTENT-MAP

| Intent shape | Skill | Cadence |
|---|---|---|
| "check foo" | [ascent-foo](ascent-foo/SKILL.md) | Daily |
| "check bar" | [ascent-bar](ascent-bar/SKILL.md) | Weekly |
EOF
}

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-skills-doctor: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-skills-doctor: %s\n" "$1"
}

# Reusable: validate frontmatter fields (matches skill Step 1 logic)
validate_frontmatter() {
  local skill_file="$1"
  local missing=0
  for field in "name:" "description:" "version:" "allowed-tools:"; do
    grep -q "$field" "$skill_file" 2>/dev/null || missing=$((missing + 1))
  done
  echo "$missing"
}

# Test 1: Frontmatter validation — valid vs missing version field
cleanup
setup_skill_collection
MISSING_VALID=$(validate_frontmatter "$FIXTURES_DIR/.claude/skills/ascent-foo/SKILL.md")
if [ "$MISSING_VALID" -eq 0 ]; then
  # Create skill with missing version
  mkdir -p "$FIXTURES_DIR/.claude/skills/ascent-broken"
  cat > "$FIXTURES_DIR/.claude/skills/ascent-broken/SKILL.md" << 'EOF'
---
name: ascent-broken
description: Missing version field.
allowed-tools:
  - Read
---

# ascent-broken
EOF
  MISSING_BROKEN=$(validate_frontmatter "$FIXTURES_DIR/.claude/skills/ascent-broken/SKILL.md")
  if [ "$MISSING_BROKEN" -eq 1 ]; then
    assert_pass "frontmatter: ascent-foo valid (0 missing), ascent-broken missing 1 field (version)"
  else
    assert_fail "broken skill should be missing 1 field, got $MISSING_BROKEN"
  fi
else
  assert_fail "valid skill should have 0 missing fields, got $MISSING_VALID"
fi

# Test 2: INTENT-MAP sync — directory exists but not in INTENT-MAP → detected
cleanup
setup_skill_collection
# Add a skill directory not listed in INTENT-MAP
mkdir -p "$FIXTURES_DIR/.claude/skills/ascent-orphan"
cat > "$FIXTURES_DIR/.claude/skills/ascent-orphan/SKILL.md" << 'EOF'
---
name: ascent-orphan
description: Not in INTENT-MAP.
version: 1.0.0
allowed-tools:
  - Read
---

# ascent-orphan
EOF
# Check: every ascent-* directory should be in INTENT-MAP (matches skill Step 2 logic)
UNSYNCED=0
for skill_dir in "$FIXTURES_DIR/.claude/skills"/ascent-*/; do
  [ -d "$skill_dir" ] || continue
  local_name=$(basename "$skill_dir")
  if ! grep -q "$local_name" "$FIXTURES_DIR/.claude/skills/INTENT-MAP.md" 2>/dev/null; then
    UNSYNCED=$((UNSYNCED + 1))
  fi
done
if [ "$UNSYNCED" -eq 1 ]; then
  assert_pass "INTENT-MAP sync: ascent-orphan detected as unlisted (1 unsynced)"
else
  assert_fail "should detect exactly 1 unsynced skill, got $UNSYNCED"
fi

# Test 3: Cross-skill reference — valid link resolves, broken link detected
cleanup
setup_skill_collection
# ascent-foo links to ../ascent-bar/SKILL.md (valid)
# Add a broken reference to ascent-nonexistent
cat >> "$FIXTURES_DIR/.claude/skills/ascent-foo/SKILL.md" << 'EOF'

See also [ascent-nonexistent](../ascent-nonexistent/SKILL.md).
EOF
# Check: extract cross-skill links and verify targets (matches skill Step 3 logic)
BROKEN_REFS=0
VALID_REFS=0
while IFS= read -r link; do
  [ -z "$link" ] && continue
  SKILL_DIR=$(dirname "$FIXTURES_DIR/.claude/skills/ascent-foo/SKILL.md")
  TARGET="$SKILL_DIR/$link"
  if [ -f "$TARGET" ]; then
    VALID_REFS=$((VALID_REFS + 1))
  else
    BROKEN_REFS=$((BROKEN_REFS + 1))
  fi
done < <(grep -oE '\.\./ascent-[^)]*SKILL\.md' "$FIXTURES_DIR/.claude/skills/ascent-foo/SKILL.md" 2>/dev/null)
if [ "$VALID_REFS" -eq 1 ] && [ "$BROKEN_REFS" -eq 1 ]; then
  assert_pass "cross-references: 1 valid (ascent-bar), 1 broken (ascent-nonexistent)"
else
  assert_fail "should have 1 valid + 1 broken ref, got valid=$VALID_REFS broken=$BROKEN_REFS"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-skills-doctor tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
