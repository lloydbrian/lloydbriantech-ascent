#!/usr/bin/env bash
# Test: ascent-release-readiness
# Verifies release gate logic: CHANGELOG validation, version consistency, tag uniqueness.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/release-readiness"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

setup_meta_repo() {
  mkdir -p "$FIXTURES_DIR"
  cat > "$FIXTURES_DIR/Makefile" << 'EOF'
FRAMEWORK_VERSION := 0.4.0
.DEFAULT_GOAL := help
EOF
  cat > "$FIXTURES_DIR/CHANGELOG.md" << 'CHEOF'
# Changelog

## v0.4.0

### Added

- All 28 project-embedded skills implemented
- Test suite: 28 skill tests passing

## v0.3.1

### Added

- Session resumption protocol (Principle §15)
CHEOF
}

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-release-readiness: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-release-readiness: %s\n" "$1"
}

# Reusable: validate CHANGELOG entry (matches skill Step 2 logic)
check_changelog() {
  local changelog="$1"
  local version="$2"
  local header_pattern="## v${version}"
  if ! grep -q "$header_pattern" "$changelog" 2>/dev/null; then
    echo "no_header"
    return
  fi
  local header_line
  header_line=$(grep -n "$header_pattern" "$changelog" | head -1 | cut -d: -f1)
  local next_header_line
  next_header_line=$(awk -v start="$((header_line + 1))" 'NR > start && /^## / { print NR; exit }' "$changelog")
  local section_text content_lines
  if [ -n "$next_header_line" ]; then
    section_text=$(sed -n "$((header_line + 1)),$((next_header_line - 1))p" "$changelog")
  else
    section_text=$(sed -n "$((header_line + 1)),\$p" "$changelog")
  fi
  content_lines=$(printf '%s\n' "$section_text" | grep '[^[:space:]]' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$content_lines" -ge 2 ]; then
    echo "pass"
  else
    echo "empty_section"
  fi
}

# Reusable: check version consistency (matches skill Step 3 logic, meta-repo context)
check_version_consistency() {
  local makefile="$1"
  local changelog="$2"
  local target="$3"
  local makefile_version
  makefile_version=$(grep 'FRAMEWORK_VERSION' "$makefile" 2>/dev/null | sed 's/.*:= *//' | tr -d ' ')
  local changelog_has_version="false"
  grep -q "## v${target}" "$changelog" 2>/dev/null && changelog_has_version="true"
  if [ "$makefile_version" = "$target" ] && [ "$changelog_has_version" = "true" ]; then
    echo "consistent"
  else
    echo "mismatch:makefile=${makefile_version},changelog=${changelog_has_version}"
  fi
}

# Reusable: check tag uniqueness (matches skill Step 5 logic)
check_tag_exists() {
  local tag="$1"
  local fixture_dir="$2"
  if [ -f "$fixture_dir/.fake-tags" ]; then
    grep -q "^${tag}$" "$fixture_dir/.fake-tags" 2>/dev/null && echo "exists" || echo "available"
  else
    echo "available"
  fi
}

# Test 1: CHANGELOG validation — section with content PASS, empty section FAIL
cleanup
setup_meta_repo
RESULT_GOOD=$(check_changelog "$FIXTURES_DIR/CHANGELOG.md" "0.4.0")
# Create a CHANGELOG with empty v0.5.0 section
cat >> "$FIXTURES_DIR/CHANGELOG.md" << 'EOF'

## v0.5.0
EOF
RESULT_EMPTY=$(check_changelog "$FIXTURES_DIR/CHANGELOG.md" "0.5.0")
# Missing version entirely
RESULT_MISSING=$(check_changelog "$FIXTURES_DIR/CHANGELOG.md" "9.9.9")
if [ "$RESULT_GOOD" = "pass" ] && [ "$RESULT_EMPTY" = "empty_section" ] && [ "$RESULT_MISSING" = "no_header" ]; then
  assert_pass "CHANGELOG validation: v0.4.0=pass, v0.5.0(empty)=empty_section, v9.9.9=no_header"
else
  assert_fail "CHANGELOG: good=$RESULT_GOOD (want pass), empty=$RESULT_EMPTY (want empty_section), missing=$RESULT_MISSING (want no_header)"
fi

# Test 2: Version consistency — matching versions PASS, mismatch detected
cleanup
setup_meta_repo
CONSISTENT=$(check_version_consistency "$FIXTURES_DIR/Makefile" "$FIXTURES_DIR/CHANGELOG.md" "0.4.0")
MISMATCH=$(check_version_consistency "$FIXTURES_DIR/Makefile" "$FIXTURES_DIR/CHANGELOG.md" "0.5.0")
if [ "$CONSISTENT" = "consistent" ] && echo "$MISMATCH" | grep -q "mismatch"; then
  assert_pass "version consistency: 0.4.0=consistent, 0.5.0=mismatch (Makefile has 0.4.0)"
else
  assert_fail "consistency: target 0.4.0=$CONSISTENT (want consistent), target 0.5.0=$MISMATCH (want mismatch)"
fi

# Test 3: Tag uniqueness — new tag available, existing tag blocked
cleanup
setup_meta_repo
printf "v0.3.0\nv0.3.1\n" > "$FIXTURES_DIR/.fake-tags"
AVAILABLE=$(check_tag_exists "v0.4.0" "$FIXTURES_DIR")
EXISTS=$(check_tag_exists "v0.3.1" "$FIXTURES_DIR")
if [ "$AVAILABLE" = "available" ] && [ "$EXISTS" = "exists" ]; then
  assert_pass "tag uniqueness: v0.4.0=available, v0.3.1=exists (blocked)"
else
  assert_fail "tags: v0.4.0=$AVAILABLE (want available), v0.3.1=$EXISTS (want exists)"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-release-readiness tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
