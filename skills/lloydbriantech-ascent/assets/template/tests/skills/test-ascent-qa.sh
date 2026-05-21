#!/usr/bin/env bash
# Test: ascent-qa
# Verifies surface-level quality gate: structural integrity, ADR spot-check,
# conditional recommendation logic.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/qa"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

setup_healthy_project() {
  mkdir -p "$FIXTURES_DIR/backend" \
           "$FIXTURES_DIR/make" \
           "$FIXTURES_DIR/docs/architecture/decisions" \
           "$FIXTURES_DIR/.claude/skills/ascent-self-audit"
  echo "FROM node:22" > "$FIXTURES_DIR/backend/Dockerfile"
  echo ".DEFAULT_GOAL := help" > "$FIXTURES_DIR/Makefile"
  echo "dev-up:" > "$FIXTURES_DIR/make/dev.mk"
  echo "services:" > "$FIXTURES_DIR/docker-compose.yml"
  cat > "$FIXTURES_DIR/.ascent-meta.json" << 'EOF'
{ "phase": "2-template-assets", "project_slug": "test-project" }
EOF
  cat > "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md" << 'EOF'
| # | Title | Status | Date | Summary |
|---|---|---|---|---|
| [001](ADR-001-container.md) | Container-first | Accepted | 2026-05-14 | Dev in containers |
EOF
  cat > "$FIXTURES_DIR/docs/architecture/decisions/ADR-001-container.md" << 'EOF'
# ADR-001: Container-first
**Status:** Accepted
## Context
Context.
## Decision
Decision.
## Alternatives considered
Alts.
## Consequences
Consequences.
## Cost implications
Cost.
EOF
  cat > "$FIXTURES_DIR/.claude/skills/INTENT-MAP.md" << 'EOF'
| Intent | Skill | Cadence |
|---|---|---|
| "audit" | [ascent-self-audit](ascent-self-audit/SKILL.md) | Weekly |
EOF
  cat > "$FIXTURES_DIR/.claude/skills/ascent-self-audit/SKILL.md" << 'EOF'
---
name: ascent-self-audit
description: Umbrella audit.
version: 1.0.0
allowed-tools:
  - Read
---
EOF
}

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-qa: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-qa: %s\n" "$1"
}

# Reusable: check structural integrity (matches skill Step 1 logic)
check_structural() {
  local dir="$1"
  local missing=0
  [ -f "$dir/backend/Dockerfile" ] || missing=$((missing + 1))
  [ -f "$dir/Makefile" ] || missing=$((missing + 1))
  [ -f "$dir/docker-compose.yml" ] || missing=$((missing + 1))
  [ -f "$dir/.ascent-meta.json" ] || missing=$((missing + 1))
  echo "$missing"
}

# Reusable: ADR spot-check (matches skill Step 2 logic)
REQUIRED_SECTIONS="## Context|## Decision|## Alternatives considered|## Consequences|## Cost implications"
adr_spot_check() {
  local decisions_dir="$1"
  local first_adr
  first_adr=$(ls "$decisions_dir"/ADR-*.md 2>/dev/null | head -1)
  [ -z "$first_adr" ] && echo "no_adrs" && return
  local missing=0
  IFS='|' read -ra SECS <<< "$REQUIRED_SECTIONS"
  for sec in "${SECS[@]}"; do
    grep -q "$sec" "$first_adr" 2>/dev/null || missing=$((missing + 1))
  done
  echo "$missing"
}

# Test 1: Structural integrity — healthy fixture PASS, missing Dockerfile CONCERN
cleanup
setup_healthy_project
HEALTHY_MISSING=$(check_structural "$FIXTURES_DIR")
rm "$FIXTURES_DIR/backend/Dockerfile"
BROKEN_MISSING=$(check_structural "$FIXTURES_DIR")
if [ "$HEALTHY_MISSING" -eq 0 ] && [ "$BROKEN_MISSING" -eq 1 ]; then
  assert_pass "structural integrity: healthy=0 missing, no Dockerfile=1 missing"
else
  assert_fail "structural: healthy=$HEALTHY_MISSING (want 0), broken=$BROKEN_MISSING (want 1)"
fi

# Test 2: ADR spot-check — complete ADR passes, missing section flagged
cleanup
setup_healthy_project
CLEAN_MISSING=$(adr_spot_check "$FIXTURES_DIR/docs/architecture/decisions")
# Remove Cost implications from the ADR
sed -i '' '/## Cost implications/,$d' "$FIXTURES_DIR/docs/architecture/decisions/ADR-001-container.md" 2>/dev/null || \
  sed -i '/## Cost implications/,$d' "$FIXTURES_DIR/docs/architecture/decisions/ADR-001-container.md" 2>/dev/null
BROKEN_MISSING=$(adr_spot_check "$FIXTURES_DIR/docs/architecture/decisions")
if [ "$CLEAN_MISSING" -eq 0 ] && [ "$BROKEN_MISSING" -eq 1 ]; then
  assert_pass "ADR spot-check: complete ADR=0 missing, no Cost implications=1 missing"
else
  assert_fail "ADR: clean=$CLEAN_MISSING (want 0), broken=$BROKEN_MISSING (want 1)"
fi

# Test 3: Conditional recommendation — concern triggers recommendation, clean does not
# Simulate the aggregation logic: when a concern exists, the recommendation map fires.
cleanup
setup_healthy_project
# Map: surface check area → recommended sub-skill (matches skill Step 6 logic)
recommend_for_area() {
  local area="$1"
  local concern_count="$2"
  if [ "$concern_count" -gt 0 ]; then
    case "$area" in
      structural)    echo "/ascent-self-audit" ;;
      adr)           echo "/ascent-adr-conformance" ;;
      dependency)    echo "/ascent-dependency-health" ;;
      documentation) echo "/ascent-doc-sweep" ;;
      skills)        echo "/ascent-skills-doctor" ;;
    esac
  else
    echo ""
  fi
}
REC_CLEAN=$(recommend_for_area "adr" 0)
REC_CONCERN=$(recommend_for_area "adr" 1)
if [ -z "$REC_CLEAN" ] && [ "$REC_CONCERN" = "/ascent-adr-conformance" ]; then
  assert_pass "conditional recommendation: clean=no recommendation, concern=recommend /ascent-adr-conformance"
else
  assert_fail "recommendation: clean='$REC_CLEAN' (want empty), concern='$REC_CONCERN' (want /ascent-adr-conformance)"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-qa tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
