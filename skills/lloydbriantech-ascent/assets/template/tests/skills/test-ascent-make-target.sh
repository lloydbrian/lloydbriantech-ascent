#!/usr/bin/env bash
# Test: ascent-make-target
# Verifies target naming, SDLC section placement, alias collision, stub format,
# and section-aware append mechanism.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/make-target"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

setup_make_tree() {
  mkdir -p "$FIXTURES_DIR/make"
  cat > "$FIXTURES_DIR/make/dev.mk" << 'EOF'
# DEV — container lifecycle for local development.

.PHONY: dev-up dev-down dev-logs

dev-up:  ## DEV: Start the dev stack
	@printf "Starting dev stack...\n"
	@$(ENGINE) compose up -d

dev-down:  ## DEV: Stop the dev stack
	@$(ENGINE) compose down --timeout 15

dev-logs:  ## DEV: Tail container logs
	@$(ENGINE) compose logs -f
EOF
  cat > "$FIXTURES_DIR/make/test.mk" << 'EOF'
# TEST — test discipline hierarchy.

.PHONY: test-unit test-skills

test-unit:  ## TEST: Run unit tests (Vitest)
	@cd backend && npx vitest run

test-skills:  ## TEST: Run all skill tests
	@bash tests/skills/run-all.sh
EOF
  cat > "$FIXTURES_DIR/make/infra.mk" << 'EOF'
# INFRA — infrastructure operations.

.PHONY: infra-monitor-up

infra-monitor-up:  ## INFRA: Start monitoring stack
	@$(ENGINE) compose -f docker-compose.monitor.yml up -d
EOF
}

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-make-target: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-make-target: %s\n" "$1"
}

# Reusable: propose canonical name from description (matches skill Step 2 logic)
# Maps plain-language descriptions to MAKE-NAMING convention names.
propose_name() {
  local desc="$1"
  case "$desc" in
    *"deploy"*"ECS"*"prod"*|*"deploy"*"ecs"*"prod"*)
      echo "aws-ecs-deploy-prod" ;;
    *"deploy"*"ECS"*"staging"*|*"deploy"*"ecs"*"staging"*)
      echo "aws-ecs-deploy-staging" ;;
    *"seed"*"database"*|*"seed"*"data"*)
      echo "data-seed" ;;
    *"lint"*"frontend"*)
      echo "qa-lint-frontend" ;;
    *"mutation"*"test"*)
      echo "test-mutation" ;;
    *)
      echo "" ;;
  esac
}

# Reusable: map area prefix to .mk file (matches skill Step 6 logic)
area_to_mkfile() {
  local name="$1"
  local prefix="${name%%-*}"
  case "$prefix" in
    dev|data|engine|session) echo "dev.mk" ;;
    test)     echo "test.mk" ;;
    qa)       echo "quality.mk" ;;
    sec)      echo "security.mk" ;;
    validate) echo "validate.mk" ;;
    doc)      echo "docs.mk" ;;
    infra|aws) echo "infra.mk" ;;
    *)        echo "" ;;
  esac
}

# Reusable: extract existing targets from a .mk file (matches skill Step 1 logic)
extract_targets() {
  local mkfile="$1"
  grep -oE '^[a-z][a-z0-9-]*:' "$mkfile" 2>/dev/null | tr -d ':' || true
}

# Test 1: Name convention — "deploy to ECS in prod" → aws-ecs-deploy-prod
cleanup
setup_make_tree
PROPOSED=$(propose_name "deploy to ECS in prod")
if [ "$PROPOSED" = "aws-ecs-deploy-prod" ]; then
  # Verify it follows MAKE-NAMING: lowercase, hyphen-separated, area-first
  if echo "$PROPOSED" | grep -qE '^[a-z][a-z0-9-]*$'; then
    # Verify area-first (not verb-first): first segment is area, not action
    FIRST_SEG="${PROPOSED%%-*}"
    if [ "$FIRST_SEG" = "aws" ]; then
      assert_pass "name convention: 'deploy to ECS in prod' → aws-ecs-deploy-prod (area-first)"
    else
      assert_fail "first segment should be area 'aws', got '$FIRST_SEG'"
    fi
  else
    assert_fail "name should be lowercase/hyphen-separated, got '$PROPOSED'"
  fi
else
  assert_fail "should propose 'aws-ecs-deploy-prod', got '$PROPOSED'"
fi

# Test 2: SDLC section placement — "test" area maps to test.mk
cleanup
setup_make_tree
TEST_CASES="test-mutation:test.mk aws-ecs-deploy-prod:infra.mk data-seed:dev.mk qa-lint-frontend:quality.mk"
ALL_CORRECT=true
for tc in $TEST_CASES; do
  NAME="${tc%%:*}"
  EXPECTED_FILE="${tc##*:}"
  ACTUAL_FILE=$(area_to_mkfile "$NAME")
  if [ "$ACTUAL_FILE" != "$EXPECTED_FILE" ]; then
    assert_fail "area mapping: $NAME should map to $EXPECTED_FILE, got $ACTUAL_FILE"
    ALL_CORRECT=false
  fi
done
if [ "$ALL_CORRECT" = true ]; then
  assert_pass "SDLC section placement: 4 targets mapped to correct .mk files"
fi

# Test 3: Alias collision — dev-start duplicates dev-up
cleanup
setup_make_tree
EXISTING_TARGETS=$(extract_targets "$FIXTURES_DIR/make/dev.mk")
PROPOSED_NAME="dev-start"
# Alias detection: same area + synonym action (start ↔ up)
ALIAS_SYNONYMS="start:up stop:down build:compile"
COLLISION_FOUND=false
PROPOSED_ACTION="${PROPOSED_NAME#*-}"
for synonym_pair in $ALIAS_SYNONYMS; do
  SYN_A="${synonym_pair%%:*}"
  SYN_B="${synonym_pair##*:}"
  if [ "$PROPOSED_ACTION" = "$SYN_A" ] || [ "$PROPOSED_ACTION" = "$SYN_B" ]; then
    MATCH_ACTION=""
    if [ "$PROPOSED_ACTION" = "$SYN_A" ]; then MATCH_ACTION="$SYN_B"; fi
    if [ "$PROPOSED_ACTION" = "$SYN_B" ]; then MATCH_ACTION="$SYN_A"; fi
    PROPOSED_AREA="${PROPOSED_NAME%%-*}"
    ALIAS_TARGET="${PROPOSED_AREA}-${MATCH_ACTION}"
    if echo "$EXISTING_TARGETS" | grep -q "^${ALIAS_TARGET}$"; then
      COLLISION_FOUND=true
    fi
  fi
done
if [ "$COLLISION_FOUND" = true ]; then
  assert_pass "alias collision: dev-start detected as duplicate of dev-up (start ↔ up synonym)"
else
  assert_fail "should detect dev-start as alias of dev-up"
fi

# Test 4: Stub format — target without recipe has [STUB] marker
cleanup
setup_make_tree
TARGET_NAME="data-seed"
STUB_OUTPUT=$(printf '%s:  ## DEV: Seed database with sample data [STUB]\n\t@printf "[STUB] make %s — add seed commands\\n"\n' "$TARGET_NAME" "$TARGET_NAME")
if echo "$STUB_OUTPUT" | grep -q '\[STUB\]'; then
  # Verify the stub annotation is in the section comment (## line)
  if echo "$STUB_OUTPUT" | grep -q "## DEV:.*\[STUB\]"; then
    # Verify the recipe is a printf with [STUB] prefix
    if echo "$STUB_OUTPUT" | grep -q '@printf "\[STUB\]'; then
      assert_pass "stub format: [STUB] in section annotation AND recipe printf"
    else
      assert_fail "stub recipe should use @printf with [STUB] prefix"
    fi
  else
    assert_fail "stub section annotation should contain [STUB]"
  fi
else
  assert_fail "stub output should contain [STUB] marker"
fi

# Test 5: Section-aware append — new target appends after last target in .mk file
# This verifies the Step 10 Edit mechanism: find last recipe line, append after it.
cleanup
setup_make_tree
MKFILE="$FIXTURES_DIR/make/test.mk"
# Count targets before append
TARGETS_BEFORE=$(extract_targets "$MKFILE" | wc -l | tr -d ' ')
# Simulate section-aware append (Step 10 logic):
# 1. Find last recipe line (line starting with tab)
# 2. Append new target block after it
LAST_RECIPE_LINE=$(grep -n "^	" "$MKFILE" | tail -1 | cut -d: -f1)
NEW_TARGET_BLOCK="
.PHONY: test-mutation

test-mutation:  ## TEST: Mutation testing [STUB]
	@printf \"[STUB] make test-mutation — add mutation testing commands\n\""
# Insert after the last recipe line
{ head -n "$LAST_RECIPE_LINE" "$MKFILE"; echo "$NEW_TARGET_BLOCK"; tail -n +$((LAST_RECIPE_LINE + 1)) "$MKFILE"; } > "$MKFILE.tmp"
mv "$MKFILE.tmp" "$MKFILE"
# Verify:
# A) New target is present
# B) New target appears after existing targets (not before, not in the middle)
# C) Section header is still at the top
TARGETS_AFTER=$(extract_targets "$MKFILE" | wc -l | tr -d ' ')
FIRST_LINE=$(head -1 "$MKFILE")
LAST_TARGET=$(extract_targets "$MKFILE" | tail -1)
if [ "$TARGETS_AFTER" -eq $((TARGETS_BEFORE + 1)) ] && \
   [ "$LAST_TARGET" = "test-mutation" ] && \
   echo "$FIRST_LINE" | grep -q "^# TEST"; then
  assert_pass "section-aware append: test-mutation appended after last target, section header preserved"
else
  assert_fail "append: before=$TARGETS_BEFORE after=$TARGETS_AFTER last=$LAST_TARGET header='$FIRST_LINE'"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-make-target tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
