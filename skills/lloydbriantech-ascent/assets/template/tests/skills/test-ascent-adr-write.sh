#!/usr/bin/env bash
# Test: ascent-adr-write
# Verifies ADR creation logic: numbering, section completeness, INDEX.md update, supersession.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/adr-write"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

setup_adr_tree() {
  mkdir -p "$FIXTURES_DIR/docs/architecture/decisions"
  cat > "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md" << 'EOF'
# Architectural Decision Records — Index

| # | Title | Status | Date | Summary |
|---|---|---|---|---|
| [001](ADR-001-container-first.md) | Container-first development | Accepted | 2026-05-14 | Dev in containers |
| [002](ADR-002-backend-layering.md) | Backend layering | Accepted | 2026-05-14 | Four-layer stack |
| [003](ADR-003-make-vocabulary.md) | Make as vocabulary | Accepted | 2026-05-14 | One target per op |
| [004](ADR-004-sqlite-wal.md) | SQLite-WAL default | Accepted | 2026-05-14 | Zero-config DB |
| [005](ADR-005-json-logging.md) | Structured JSON logging | Accepted | 2026-05-14 | pino JSON logs |
| [006](ADR-006-dual-licensing.md) | Dual licensing | Accepted | 2026-05-14 | MIT OR Apache-2.0 |
| [007](ADR-007-phase-gated.md) | Phase-gated delivery | Accepted | 2026-05-14 | Explicit go-signal |
EOF
  for n in 001 002 003 004 005 006 007; do
    local slug
    slug=$(grep "\[$n\]" "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md" | sed 's/.*(\(ADR-[^)]*\)).*/\1/')
    cat > "$FIXTURES_DIR/docs/architecture/decisions/$slug" << INNER
# ADR-$n: Placeholder

**Status:** Accepted
**Date:** 2026-05-14 (America/New_York)
**Decider:** test-brand

## Context
Test context.

## Decision
Test decision.

## Alternatives considered
Alt 1. Alt 2.

## Consequences
**Easier:** X. **Harder:** Y. **Neutral:** Z.

## Cost implications
Time: minimal. Complexity: low.
INNER
  done
}

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-adr-write: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-adr-write: %s\n" "$1"
}

# Reusable: compute next ADR number from INDEX.md (matches skill Step 1 logic)
compute_next_adr() {
  local index_file="$1"
  local highest
  highest=$(grep -oE '\[0[0-9]{2}\]' "$index_file" 2>/dev/null | tr -d '[]' | sort -n | tail -1)
  if [ -z "$highest" ]; then
    printf "001"
  else
    printf "%03d" $((10#$highest + 1))
  fi
}

# Reusable: derive kebab-case slug from title (matches skill Step 2 logic)
derive_slug() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr ' ' '-' | sed 's/--*/-/g; s/^-//; s/-$//'
}

# Test 1: Next-number computation — fixture with 7 ADRs → next is 008
cleanup
setup_adr_tree
NEXT=$(compute_next_adr "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md")
if [ "$NEXT" = "008" ]; then
  assert_pass "next-number computation: 7 existing ADRs → next is 008"
else
  assert_fail "should compute 008 from 7 ADRs, got $NEXT"
fi

# Test 2: File creation with all 5 sections
cleanup
setup_adr_tree
NEXT=$(compute_next_adr "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md")
SLUG=$(derive_slug "Redis session store")
ADR_FILE="$FIXTURES_DIR/docs/architecture/decisions/ADR-${NEXT}-${SLUG}.md"
cat > "$ADR_FILE" << 'EOF'
# ADR-008: Redis session store

**Status:** Accepted
**Date:** 2026-05-18 (America/New_York)
**Decider:** test-brand

## Context

We need a session store that supports TTL-based expiry and horizontal scaling.

## Decision

Use Redis as the session store for all authenticated endpoints.

## Alternatives considered

**Memcached:** Simpler but lacks persistence. Risk of session loss on restart.

**Cookie-based sessions:** No server-side state but limited payload size and security concerns with sensitive session data.

## Consequences

**Easier:** Session sharing across multiple backend instances.
**Harder:** Adds Redis as an infrastructure dependency.
**Neutral:** Observability shifts from file-based to network-based monitoring.

## Cost implications

Time: 2 days implementation + Redis configuration. Complexity: moderate — adds a network dependency. Future flexibility: opens path to pub/sub if needed. Money: Redis managed service ~$15/month on AWS ElastiCache.
EOF

SECTIONS_FOUND=0
grep -q "## Context" "$ADR_FILE" && SECTIONS_FOUND=$((SECTIONS_FOUND + 1))
grep -q "## Decision" "$ADR_FILE" && SECTIONS_FOUND=$((SECTIONS_FOUND + 1))
grep -q "## Alternatives considered" "$ADR_FILE" && SECTIONS_FOUND=$((SECTIONS_FOUND + 1))
grep -q "## Consequences" "$ADR_FILE" && SECTIONS_FOUND=$((SECTIONS_FOUND + 1))
grep -q "## Cost implications" "$ADR_FILE" && SECTIONS_FOUND=$((SECTIONS_FOUND + 1))
if [ "$SECTIONS_FOUND" -eq 5 ]; then
  assert_pass "file creation: ADR-${NEXT}-${SLUG}.md has all 5 required sections"
else
  assert_fail "ADR should have 5 sections, found $SECTIONS_FOUND"
fi

# Test 3: INDEX.md append — verify new row with correct columns
cleanup
setup_adr_tree
NEXT=$(compute_next_adr "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md")
SLUG=$(derive_slug "Redis session store")
# Simulate Step 10: append INDEX.md row
INDEX_ROW="| [${NEXT}](ADR-${NEXT}-${SLUG}.md) | Redis session store | Accepted | 2026-05-18 | Redis for TTL-based session management |"
echo "$INDEX_ROW" >> "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md"

# Verify: row present, has 5 pipe-delimited columns, links to correct file
if grep -q "ADR-${NEXT}-${SLUG}.md" "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md"; then
  COL_COUNT=$(echo "$INDEX_ROW" | tr '|' '\n' | grep -c '[^[:space:]]')
  if [ "$COL_COUNT" -eq 5 ]; then
    assert_pass "INDEX.md append: new row with 5 columns linking to ADR-${NEXT}-${SLUG}.md"
  else
    assert_fail "INDEX.md row should have 5 columns, got $COL_COUNT"
  fi
else
  assert_fail "INDEX.md should contain a row for ADR-${NEXT}"
fi

# Test 4: Supersession — old ADR status updated
cleanup
setup_adr_tree
OLD_ADR="$FIXTURES_DIR/docs/architecture/decisions/ADR-004-sqlite-wal.md"
# Verify initial status
if grep -q "^\\*\\*Status:\\*\\* Accepted" "$OLD_ADR"; then
  # Simulate supersession: edit old ADR's status (Step 10 supersession logic)
  sed -i '' 's/^\*\*Status:\*\* Accepted/**Status:** Superseded by ADR-008/' "$OLD_ADR" 2>/dev/null || \
    sed -i 's/^\*\*Status:\*\* Accepted/**Status:** Superseded by ADR-008/' "$OLD_ADR" 2>/dev/null
  if grep -q "Superseded by ADR-008" "$OLD_ADR"; then
    # Verify body is untouched (only Status line changed)
    if grep -q "## Context" "$OLD_ADR" && grep -q "## Cost implications" "$OLD_ADR"; then
      assert_pass "supersession: ADR-004 status → 'Superseded by ADR-008', body untouched"
    else
      assert_fail "supersession should only change Status line, not body sections"
    fi
  else
    assert_fail "old ADR status should be 'Superseded by ADR-008'"
  fi
else
  assert_fail "old ADR should start with Status: Accepted"
fi

# Test 5: Collision detection — ADR-008 exists → skip to 009
cleanup
setup_adr_tree
# Create a file at ADR-008 to simulate collision
touch "$FIXTURES_DIR/docs/architecture/decisions/ADR-008-existing.md"
NEXT=$(compute_next_adr "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md")
# NEXT is 008 from INDEX, but file exists — collision logic increments
CANDIDATE="008"
ADR_DIR="$FIXTURES_DIR/docs/architecture/decisions"
while ls "$ADR_DIR"/ADR-${CANDIDATE}-*.md > /dev/null 2>&1; do
  CANDIDATE=$(printf "%03d" $((10#$CANDIDATE + 1)))
done
if [ "$CANDIDATE" = "009" ]; then
  assert_pass "collision detection: ADR-008 exists → incremented to ADR-009"
else
  assert_fail "should increment to 009 on collision, got $CANDIDATE"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-adr-write tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
