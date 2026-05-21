#!/usr/bin/env bash
# Test: ascent-ai-evals
# Verifies eval suite detection: no-op when absent, scenario structure validation.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/ai-evals"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-ai-evals: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-ai-evals: %s\n" "$1"
}

# Reusable: detect eval suite (matches skill Step 1 logic)
detect_eval_suite() {
  local project_dir="$1"
  local evals_dir="$project_dir/tests/evals"
  if [ -d "$evals_dir" ]; then
    local count
    count=$(find "$evals_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -gt 0 ] && echo "present:$count" || echo "empty"
  else
    echo "absent"
  fi
}

# Reusable: validate scenario structure (matches skill Step 2 logic)
check_scenario_structure() {
  local scenario_file="$1"
  local missing=0
  for section in "## Prompt" "## Expected" "## Context"; do
    grep -q "$section" "$scenario_file" 2>/dev/null || missing=$((missing + 1))
  done
  echo "$missing"
}

# Test 1: No-op detection — no tests/evals/ directory → exits zero
cleanup
mkdir -p "$FIXTURES_DIR"
RESULT=$(detect_eval_suite "$FIXTURES_DIR")
if [ "$RESULT" = "absent" ]; then
  assert_pass "no-op detection: no tests/evals/ → absent (skill would exit zero)"
else
  assert_fail "should detect absent eval suite, got $RESULT"
fi

# Test 2: Scenario structure — well-formed passes, missing section flagged
cleanup
mkdir -p "$FIXTURES_DIR/tests/evals"
cat > "$FIXTURES_DIR/tests/evals/greeting.md" << 'EOF'
# Greeting eval

## Prompt

Say hello to the user.

## Expected

A friendly greeting that includes the user's name.

## Context

Used in the onboarding flow.
EOF
GOOD_MISSING=$(check_scenario_structure "$FIXTURES_DIR/tests/evals/greeting.md")
cat > "$FIXTURES_DIR/tests/evals/incomplete.md" << 'EOF'
# Incomplete eval

## Prompt

Summarize the document.
EOF
BAD_MISSING=$(check_scenario_structure "$FIXTURES_DIR/tests/evals/incomplete.md")
if [ "$GOOD_MISSING" -eq 0 ] && [ "$BAD_MISSING" -eq 2 ]; then
  assert_pass "scenario structure: greeting.md=0 missing, incomplete.md=2 missing (Expected + Context)"
else
  assert_fail "structure: good=$GOOD_MISSING (want 0), bad=$BAD_MISSING (want 2)"
fi

# Test 3: Prompt-test coverage — prompts with matching eval scenarios
cleanup
mkdir -p "$FIXTURES_DIR/tests/evals" "$FIXTURES_DIR/backend/prompts"
echo "system: Summarize the document concisely." > "$FIXTURES_DIR/backend/prompts/summarize.md"
echo "system: Classify the input by category." > "$FIXTURES_DIR/backend/prompts/classify.md"
cat > "$FIXTURES_DIR/tests/evals/summarize.md" << 'EOF'
## Prompt
Summarize this.
## Expected
A concise summary.
## Context
Document review flow.
EOF
# Mechanical: list prompts, check each has matching eval file (matches skill Step 3 logic)
UNCOVERED=0
for prompt in "$FIXTURES_DIR"/backend/prompts/*.md; do
  [ -f "$prompt" ] || continue
  PROMPT_NAME=$(basename "$prompt")
  [ -f "$FIXTURES_DIR/tests/evals/$PROMPT_NAME" ] || UNCOVERED=$((UNCOVERED + 1))
done
if [ "$UNCOVERED" -eq 1 ]; then
  assert_pass "prompt coverage: 2 prompts, 1 uncovered (classify.md has no eval)"
else
  assert_fail "prompt coverage: expected 1 uncovered, got $UNCOVERED"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-ai-evals tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
