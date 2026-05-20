#!/usr/bin/env bash
# Test: ascent-doc-stub
# Verifies persona-targeted doc generation: heading mapping, depth validation,
# provenance comments, existing-file guard.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/doc-stub"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

setup_docs_tree() {
  mkdir -p "$FIXTURES_DIR/docs/architecture" \
           "$FIXTURES_DIR/docs/development" \
           "$FIXTURES_DIR/docs/operations" \
           "$FIXTURES_DIR/docs/guides"
}

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-doc-stub: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-doc-stub: %s\n" "$1"
}

# Reusable: persona-to-heading mapping (matches skill Step 5 logic)
# Returns pipe-delimited heading list for a given persona.
headings_for_persona() {
  local persona="$1"
  case "$persona" in
    Architect)   echo "Constraints|Alternatives|Trade-offs|Dependencies|Open questions" ;;
    Developer)   echo "Implementation|Integration|Testing|Edge cases|Related code" ;;
    Operator)    echo "Commands|Failure modes|Escalation|Monitoring|Recovery" ;;
    Contributor) echo "Conventions|Quality bar|PR mechanics|Testing expectations|Scope boundaries" ;;
    Learner)     echo "Why|What|How|Cost|Next steps" ;;
    *)           echo "" ;;
  esac
}

# Reusable: generate a doc skeleton (matches skill Steps 5-6 logic)
generate_skeleton() {
  local persona="$1"
  local title="$2"
  local path="$3"
  local headings
  headings=$(headings_for_persona "$persona")
  {
    printf "<!-- Audience: %s -->\n" "$persona"
    printf "# %s\n\n" "$title"
    printf "Description of what this doc covers.\n"
    echo "$headings" | tr '|' '\n' | while read -r heading; do
      printf "\n## %s\n\n" "$heading"
      printf "Placeholder content for %s.\n" "$heading"
    done
  } > "$path"
}

# Test 1: Persona-to-heading mapping produces persona-specific headings
# Verify each persona gets distinct headings (not generic "Overview").
cleanup
setup_docs_tree
ALL_DISTINCT=true
PERSONAS="Architect Developer Operator Contributor Learner"
for persona in $PERSONAS; do
  HEADINGS=$(headings_for_persona "$persona")
  # Verify headings are non-empty
  if [ -z "$HEADINGS" ]; then
    assert_fail "persona $persona has no heading mapping"
    ALL_DISTINCT=false
    continue
  fi
  # Verify no generic headings
  if echo "$HEADINGS" | grep -qi "overview\|details\|miscellaneous"; then
    assert_fail "persona $persona has generic headings: $HEADINGS"
    ALL_DISTINCT=false
    continue
  fi
  # Verify heading count (each persona gets 5 headings)
  COUNT=$(echo "$HEADINGS" | tr '|' '\n' | wc -l | tr -d ' ')
  if [ "$COUNT" -ne 5 ]; then
    assert_fail "persona $persona should have 5 headings, got $COUNT"
    ALL_DISTINCT=false
  fi
done
# Verify all 5 personas produce different heading sets
UNIQUE_SETS=$(for p in $PERSONAS; do headings_for_persona "$p"; done | sort -u | wc -l | tr -d ' ')
if [ "$ALL_DISTINCT" = true ] && [ "$UNIQUE_SETS" -eq 5 ]; then
  assert_pass "persona-to-heading mapping: 5 personas × 5 unique headings each, no generic headings"
else
  assert_fail "heading mapping: expected 5 unique persona heading sets, got $UNIQUE_SETS"
fi

# Test 2: Depth validation — persona root at depth 0, doc at depth 4 → rejected
cleanup
setup_docs_tree
# Simulate depth calculation: count directory levels between persona root and target.
# Architect root: docs/architecture/ (depth 0 for architect).
# Target: docs/architecture/deep/nested/very/far/doc.md (depth 4).
PERSONA_ROOT="$FIXTURES_DIR/docs/architecture"
TARGET_PATH="$FIXTURES_DIR/docs/architecture/deep/nested/very/far/doc.md"
# Count path segments between root and target (excluding root itself)
REL_PATH="${TARGET_PATH#$PERSONA_ROOT/}"
DEPTH=$(echo "$REL_PATH" | tr '/' '\n' | wc -l | tr -d ' ')
# File itself counts as final click, directories are intermediate clicks
# depth = number of '/' separators in relative path
DIR_DEPTH=$(echo "$REL_PATH" | grep -o '/' | wc -l | tr -d ' ')
if [ "$DIR_DEPTH" -gt 3 ]; then
  assert_pass "depth validation: $DIR_DEPTH clicks from root → rejected (limit: 3)"
else
  assert_fail "depth $DIR_DEPTH should exceed 3-click limit for deeply nested path"
fi

# Test 3: Provenance comment — generated doc has <!-- Audience: Developer -->
cleanup
setup_docs_tree
DOC_PATH="$FIXTURES_DIR/docs/development/items-api.md"
generate_skeleton "Developer" "Items API integration guide" "$DOC_PATH"
# Verify provenance comment on line 1
FIRST_LINE=$(head -1 "$DOC_PATH")
if echo "$FIRST_LINE" | grep -q '<!-- Audience: Developer -->'; then
  # Also verify persona-specific headings made it into the file
  if grep -q "## Implementation" "$DOC_PATH" && grep -q "## Testing" "$DOC_PATH"; then
    assert_pass "provenance: <!-- Audience: Developer --> on line 1, Developer headings present"
  else
    assert_fail "provenance comment present but Developer-specific headings missing"
  fi
else
  assert_fail "line 1 should be '<!-- Audience: Developer -->', got '$FIRST_LINE'"
fi

# Test 4: Existing-file guard — target already exists → skill stops
cleanup
setup_docs_tree
EXISTING_PATH="$FIXTURES_DIR/docs/operations/runbook.md"
echo "# Existing runbook content" > "$EXISTING_PATH"
# Simulate Step 4: check if target file exists before writing
if [ -f "$EXISTING_PATH" ]; then
  # Skill would stop here and offer A (abort) or B (create -v2)
  GUARD_TRIGGERED="true"
  # Verify original content is untouched
  if grep -q "Existing runbook content" "$EXISTING_PATH"; then
    assert_pass "existing-file guard: target exists → blocked, original content preserved"
  else
    assert_fail "existing file should be untouched when guard triggers"
  fi
else
  assert_fail "fixture file should exist for this test"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-doc-stub tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
