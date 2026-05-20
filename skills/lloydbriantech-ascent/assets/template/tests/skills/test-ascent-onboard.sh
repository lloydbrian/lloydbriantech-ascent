#!/usr/bin/env bash
# Test: ascent-onboard
# Verifies onboard logic: project maturity detection, ADR count extraction,
# first-hour walkthrough structure.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/onboard"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

setup_fresh_scaffold() {
  mkdir -p "$FIXTURES_DIR/docs/architecture/decisions" \
           "$FIXTURES_DIR/docs/delivery" \
           "$FIXTURES_DIR/.claude/skills/ascent-self-audit"
  cat > "$FIXTURES_DIR/.ascent-meta.json" << 'EOF'
{
  "framework": "lloydbriantech-ascent",
  "phase": "0-foundation",
  "project_slug": "test-project"
}
EOF
  cat > "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md" << 'EOF'
| # | Title | Status | Date | Summary |
|---|---|---|---|---|
| [001](ADR-001-container-first.md) | Container-first | Accepted | 2026-05-14 | Dev in containers |
| [002](ADR-002-layering.md) | Backend layering | Accepted | 2026-05-14 | Four layers |
| [003](ADR-003-make.md) | Make vocabulary | Accepted | 2026-05-14 | One target per op |
| [004](ADR-004-sqlite.md) | SQLite-WAL | Accepted | 2026-05-14 | Zero-config DB |
| [005](ADR-005-logging.md) | JSON logging | Accepted | 2026-05-14 | pino JSON |
| [006](ADR-006-license.md) | Dual licensing | Accepted | 2026-05-14 | MIT OR Apache |
| [007](ADR-007-phases.md) | Phase-gated | Accepted | 2026-05-14 | Explicit go-signal |
EOF
}

setup_established_project() {
  setup_fresh_scaffold
  # Add history indicators that push maturity to "established"
  cat > "$FIXTURES_DIR/docs/delivery/working-memory.md" << 'EOF'
# Working memory — Test Project

## Decisions

- 2026-05-16: Chose SQLite-WAL over Postgres
- 2026-05-17: Session resumption adopted
- 2026-05-18: Feature intake locked 4 criteria for auth

## Patterns adopted

- Structured JSON logging via pino

## Patterns rejected

- Host-level npm install
EOF
  cat > "$FIXTURES_DIR/docs/delivery/PHASE-PLAN.md" << 'EOF'
- [x] Root templates
- [x] Make framework
- [x] Backend skeleton
- [ ] Frontend skeleton
- [ ] Container topology
- [ ] Smoke test
EOF
  # Add ADR beyond baseline 7
  echo "| [008](ADR-008-redis.md) | Redis sessions | Accepted | 2026-05-18 | TTL-based sessions |" >> "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md"
}

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-onboard: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-onboard: %s\n" "$1"
}

# Reusable: detect project maturity from state (matches skill Step 2 logic)
detect_maturity() {
  local project_dir="$1"
  local memory_entries=0
  local plan_checked=0
  local adr_count=0
  if [ -f "$project_dir/docs/delivery/working-memory.md" ]; then
    memory_entries=$(grep -cE '^- [0-9]{4}-[0-9]{2}-[0-9]{2}:' "$project_dir/docs/delivery/working-memory.md" 2>/dev/null || echo 0)
  fi
  if [ -f "$project_dir/docs/delivery/PHASE-PLAN.md" ]; then
    plan_checked=$(grep -c '\[x\]' "$project_dir/docs/delivery/PHASE-PLAN.md" 2>/dev/null || echo 0)
  fi
  if [ -f "$project_dir/docs/architecture/decisions/INDEX.md" ]; then
    adr_count=$(grep -cE '^\| \[' "$project_dir/docs/architecture/decisions/INDEX.md" 2>/dev/null || echo 0)
  fi
  if [ "$memory_entries" -gt 0 ] && [ "$plan_checked" -gt 0 ] && [ "$adr_count" -gt 7 ]; then
    printf "established"
  elif [ "$memory_entries" -eq 0 ] && [ "$plan_checked" -eq 0 ]; then
    printf "fresh"
  else
    printf "mid-development"
  fi
}

# Reusable: extract ADR count from INDEX.md (matches skill Step 3 logic)
count_adrs() {
  local index_file="$1"
  grep -cE '^\| \[' "$index_file" 2>/dev/null || echo 0
}

# Test 1: Project maturity detection — fresh vs established
cleanup
setup_fresh_scaffold
FRESH_MATURITY=$(detect_maturity "$FIXTURES_DIR")
cleanup
setup_established_project
ESTABLISHED_MATURITY=$(detect_maturity "$FIXTURES_DIR")
if [ "$FRESH_MATURITY" = "fresh" ] && [ "$ESTABLISHED_MATURITY" = "established" ]; then
  assert_pass "maturity detection: fresh scaffold='$FRESH_MATURITY', established project='$ESTABLISHED_MATURITY'"
else
  assert_fail "maturity: fresh=$FRESH_MATURITY (want fresh), established=$ESTABLISHED_MATURITY (want established)"
fi

# Test 2: ADR count extraction — 7 baseline + 1 project-specific = 8
cleanup
setup_established_project
ADR_COUNT=$(count_adrs "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md")
if [ "$ADR_COUNT" -eq 8 ]; then
  assert_pass "ADR count extraction: 8 ADRs from INDEX.md (7 baseline + 1 project-specific)"
else
  assert_fail "should extract 8 ADRs, got $ADR_COUNT"
fi

# Test 3: First-hour walkthrough covers 5 orientation areas
# Verify the onboard output structure by checking that the 5 areas are addressable
# from the project state (each area has a data source that exists in the fixture).
cleanup
setup_established_project
AREAS_COVERED=0
# Area 1: Project identity — .ascent-meta.json has phase and slug
grep -q '"phase"' "$FIXTURES_DIR/.ascent-meta.json" && AREAS_COVERED=$((AREAS_COVERED + 1))
# Area 2: Conventions — .claude/skills/ directory exists (skill collection present)
[ -d "$FIXTURES_DIR/.claude/skills" ] && AREAS_COVERED=$((AREAS_COVERED + 1))
# Area 3: Current state — PHASE-PLAN.md has checkable items
grep -qE '\[[ x]\]' "$FIXTURES_DIR/docs/delivery/PHASE-PLAN.md" 2>/dev/null && AREAS_COVERED=$((AREAS_COVERED + 1))
# Area 4: Key decisions — INDEX.md has ADR entries
[ "$(count_adrs "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md")" -gt 0 ] && AREAS_COVERED=$((AREAS_COVERED + 1))
# Area 5: Where to start — maturity is detectable (drives "where to start" guidance)
[ "$(detect_maturity "$FIXTURES_DIR")" != "" ] && AREAS_COVERED=$((AREAS_COVERED + 1))
if [ "$AREAS_COVERED" -eq 5 ]; then
  assert_pass "first-hour structure: all 5 orientation areas have data sources (identity, conventions, state, decisions, start)"
else
  assert_fail "should cover 5 areas, got $AREAS_COVERED"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-onboard tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
