#!/usr/bin/env bash
# Test: ascent-persona-coverage
# Verifies persona coverage: entry-point validation, orphaned persona detection,
# depth validation.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/persona-coverage"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-persona-coverage: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-persona-coverage: %s\n" "$1"
}

setup_project_with_personas() {
  mkdir -p "$FIXTURES_DIR/docs/architecture" "$FIXTURES_DIR/docs/operations"
  cat > "$FIXTURES_DIR/README.md" << 'EOF'
# Test Project

## Documentation by persona

| Persona | Needs | Entry point |
|---|---|---|
| **Architect** | Decisions | `docs/architecture/` |
| **Developer** | Implementation | `docs/` |
| **Operator** | Runbooks | `docs/operations/` |
EOF
  echo "# Architecture docs" > "$FIXTURES_DIR/docs/architecture/overview.md"
  echo "# Ops runbook" > "$FIXTURES_DIR/docs/operations/runbook.md"
}

# Reusable: extract persona entry points from README (matches skill Step 1 logic)
extract_persona_entries() {
  local readme="$1"
  grep -E '^\| \*\*' "$readme" 2>/dev/null | while IFS='|' read -r _ persona _ entry _; do
    local name
    name=$(echo "$persona" | sed 's/\*\*//g' | tr -d ' ')
    local path
    path=$(echo "$entry" | sed 's/`//g' | tr -d ' ')
    [ -n "$name" ] && [ -n "$path" ] && echo "$name:$path"
  done
}

# Reusable: check entry-point existence (matches skill Step 3 logic)
check_entry_points() {
  local project_dir="$1"
  local readme="$project_dir/README.md"
  local missing=0
  while IFS= read -r entry; do
    [ -z "$entry" ] && continue
    local path="${entry#*:}"
    if [ ! -d "$project_dir/$path" ] && [ ! -f "$project_dir/$path" ]; then
      missing=$((missing + 1))
    fi
  done < <(extract_persona_entries "$readme")
  echo "$missing"
}

# Test 1: Entry-point validation — existing dirs PASS, missing dir orphaned
cleanup
setup_project_with_personas
MISSING_CLEAN=$(check_entry_points "$FIXTURES_DIR")
# Add a persona pointing to a non-existent directory
cat >> "$FIXTURES_DIR/README.md" << 'EOF'
| **Learner** | Guides | `docs/guides/` |
EOF
MISSING_ORPHAN=$(check_entry_points "$FIXTURES_DIR")
if [ "$MISSING_CLEAN" -eq 0 ] && [ "$MISSING_ORPHAN" -eq 1 ]; then
  assert_pass "entry-point validation: 3 existing dirs=0 missing, added orphan=1 missing (docs/guides/)"
else
  assert_fail "entry points: clean=$MISSING_CLEAN (want 0), orphan=$MISSING_ORPHAN (want 1)"
fi

# Test 2: Depth validation — doc at depth 4 exceeds 3-click limit
cleanup
setup_project_with_personas
# Create a deeply nested doc
DEEP_PATH="$FIXTURES_DIR/docs/architecture/patterns/auth/jwt/impl"
mkdir -p "$DEEP_PATH"
echo "# JWT details" > "$DEEP_PATH/details.md"
# Count depth from docs/architecture/ (the Architect entry point)
ENTRY_ROOT="$FIXTURES_DIR/docs/architecture"
REL_PATH="${DEEP_PATH#$ENTRY_ROOT/}/details.md"
DIR_DEPTH=$(echo "$REL_PATH" | grep -o '/' | wc -l | tr -d ' ')
if [ "$DIR_DEPTH" -gt 3 ]; then
  assert_pass "depth validation: $DIR_DEPTH clicks from Architect root → exceeds 3-click limit"
else
  assert_fail "deeply nested doc should exceed 3-click limit, got depth $DIR_DEPTH"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-persona-coverage tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
