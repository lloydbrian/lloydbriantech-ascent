#!/usr/bin/env bash
# Test: ascent-adr-conformance
# Verifies ADR conformance checks: section completeness, INDEX sync, supersession
# bidirectionality (canonical phrase pattern), status consistency.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/adr-conformance"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

setup_adr_tree() {
  mkdir -p "$FIXTURES_DIR/docs/architecture/decisions"
  cat > "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md" << 'EOF'
| # | Title | Status | Date | Summary |
|---|---|---|---|---|
| [001](ADR-001-container-first.md) | Container-first | Accepted | 2026-05-14 | Dev in containers |
| [002](ADR-002-layering.md) | Backend layering | Accepted | 2026-05-14 | Four layers |
EOF
  for n in 001 002; do
    local slug
    slug=$(grep "\[$n\]" "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md" | sed 's/.*(\(ADR-[^)]*\)).*/\1/')
    cat > "$FIXTURES_DIR/docs/architecture/decisions/$slug" << INNER
# ADR-$n: Placeholder

**Status:** Accepted
**Date:** 2026-05-14

## Context
Context here.

## Decision
Decision here.

## Alternatives considered
Alt 1. Alt 2.

## Consequences
Trade-offs here.

## Cost implications
Cost here.
INNER
  done
}

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-adr-conformance: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-adr-conformance: %s\n" "$1"
}

# Reusable: check 5-section completeness (matches skill Step 1 logic)
REQUIRED_SECTIONS="## Context|## Decision|## Alternatives considered|## Consequences|## Cost implications"
check_sections() {
  local adr_file="$1"
  local missing=0
  IFS='|' read -ra SECS <<< "$REQUIRED_SECTIONS"
  for sec in "${SECS[@]}"; do
    grep -q "$sec" "$adr_file" 2>/dev/null || missing=$((missing + 1))
  done
  echo "$missing"
}

# Test 1: Section completeness — all 5 present vs missing Cost implications
cleanup
setup_adr_tree
MISSING_COMPLETE=$(check_sections "$FIXTURES_DIR/docs/architecture/decisions/ADR-001-container-first.md")
if [ "$MISSING_COMPLETE" -eq 0 ]; then
  # Now create an ADR missing Cost implications
  cat > "$FIXTURES_DIR/docs/architecture/decisions/ADR-003-incomplete.md" << 'EOF'
# ADR-003: Incomplete

**Status:** Accepted

## Context
Context.

## Decision
Decision.

## Alternatives considered
Alts.

## Consequences
Consequences.
EOF
  MISSING_INCOMPLETE=$(check_sections "$FIXTURES_DIR/docs/architecture/decisions/ADR-003-incomplete.md")
  if [ "$MISSING_INCOMPLETE" -eq 1 ]; then
    assert_pass "section completeness: ADR-001 has 5/5, ADR-003 missing 1 (Cost implications)"
  else
    assert_fail "ADR-003 should be missing 1 section, found $MISSING_INCOMPLETE missing"
  fi
else
  assert_fail "complete ADR-001 should have 0 missing sections, got $MISSING_COMPLETE"
fi

# Test 2: INDEX sync — ADR-008 exists but not in INDEX → detected as orphan
cleanup
setup_adr_tree
cat > "$FIXTURES_DIR/docs/architecture/decisions/ADR-008-orphan.md" << 'EOF'
# ADR-008: Orphan

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
# Check: file exists but not in INDEX (matches skill Step 2 logic)
ORPHANED=0
for adr_file in "$FIXTURES_DIR/docs/architecture/decisions"/ADR-*.md; do
  [ -f "$adr_file" ] || continue
  local_name=$(basename "$adr_file")
  if ! grep -q "$local_name" "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md" 2>/dev/null; then
    ORPHANED=$((ORPHANED + 1))
  fi
done
if [ "$ORPHANED" -eq 1 ]; then
  assert_pass "INDEX sync: ADR-008-orphan.md detected as unindexed (1 orphan)"
else
  assert_fail "should detect exactly 1 orphaned ADR, got $ORPHANED"
fi

# Test 3: Supersession bidirectionality — canonical phrase pattern
# Clean case: ADR-004 says "Superseded by ADR-008", ADR-008 Context starts with
# "This ADR supersedes ADR-004" → bidirectional, PASS.
# Broken case: ADR-004 says "Superseded by ADR-008" but ADR-008 Context does NOT
# have the canonical phrase → unidirectional, FAIL.
cleanup
setup_adr_tree

# Build clean supersession pair
cat > "$FIXTURES_DIR/docs/architecture/decisions/ADR-004-sqlite-wal.md" << 'EOF'
# ADR-004: SQLite-WAL

**Status:** Superseded by ADR-008

## Context
Original context.
## Decision
Use SQLite-WAL.
## Alternatives considered
Alts.
## Consequences
Consequences.
## Cost implications
Cost.
EOF

# Clean ADR-008: has canonical phrase
cat > "$FIXTURES_DIR/docs/architecture/decisions/ADR-008-postgres.md" << 'EOF'
# ADR-008: Migrate to Postgres

**Status:** Accepted

## Context
This ADR supersedes ADR-004: SQLite-WAL. The project has outgrown single-file storage.
## Decision
Use Postgres.
## Alternatives considered
Alts.
## Consequences
Consequences.
## Cost implications
Cost.
EOF

# Verify clean case passes (matches skill Step 4 logic)
check_supersession_bidirectional() {
  local decisions_dir="$1"
  local broken=0
  for adr_file in "$decisions_dir"/ADR-*.md; do
    [ -f "$adr_file" ] || continue
    local old_num
    old_num=$(grep -oE 'Superseded by ADR-[0-9]+' "$adr_file" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    [ -z "$old_num" ] && continue
    local old_adr_num
    old_adr_num=$(basename "$adr_file" | grep -oE 'ADR-[0-9]+' | grep -oE '[0-9]+')
    local new_adr
    new_adr=$(ls "$decisions_dir"/ADR-"$(printf '%03d' "$((10#$old_num))")"*.md 2>/dev/null | head -1)
    if [ -z "$new_adr" ] || [ ! -f "$new_adr" ]; then
      broken=$((broken + 1))
      continue
    fi
    if ! grep -q "This ADR supersedes ADR-${old_adr_num}" "$new_adr" 2>/dev/null; then
      broken=$((broken + 1))
    fi
  done
  echo "$broken"
}

CLEAN_BROKEN=$(check_supersession_bidirectional "$FIXTURES_DIR/docs/architecture/decisions")
if [ "$CLEAN_BROKEN" -eq 0 ]; then
  # Now break it: replace ADR-008's Context with one lacking the canonical phrase
  cat > "$FIXTURES_DIR/docs/architecture/decisions/ADR-008-postgres.md" << 'EOF'
# ADR-008: Migrate to Postgres

**Status:** Accepted

## Context
We need a more scalable database. Postgres was chosen.
## Decision
Use Postgres.
## Alternatives considered
Alts.
## Consequences
Consequences.
## Cost implications
Cost.
EOF
  BROKEN_COUNT=$(check_supersession_bidirectional "$FIXTURES_DIR/docs/architecture/decisions")
  if [ "$BROKEN_COUNT" -eq 1 ]; then
    assert_pass "supersession bidirectionality: clean pair passes, broken pair (missing canonical phrase) detected"
  else
    assert_fail "broken supersession should detect 1 violation, got $BROKEN_COUNT"
  fi
else
  assert_fail "clean supersession pair should have 0 broken links, got $CLEAN_BROKEN"
fi

# Test 4: Status consistency — INDEX says Accepted, file says Superseded → mismatch
cleanup
setup_adr_tree
# ADR-001 is Accepted in both INDEX and file (clean)
# Modify ADR-002's file status to Superseded but leave INDEX as Accepted
sed -i '' 's/\*\*Status:\*\* Accepted/**Status:** Superseded by ADR-099/' \
  "$FIXTURES_DIR/docs/architecture/decisions/ADR-002-layering.md" 2>/dev/null || \
sed -i 's/\*\*Status:\*\* Accepted/**Status:** Superseded by ADR-099/' \
  "$FIXTURES_DIR/docs/architecture/decisions/ADR-002-layering.md" 2>/dev/null
# Check: extract status from file and from INDEX, compare (matches skill Step 5 logic)
FILE_STATUS=$(grep '^\*\*Status:\*\*' "$FIXTURES_DIR/docs/architecture/decisions/ADR-002-layering.md" | sed 's/\*\*Status:\*\* //')
INDEX_STATUS=$(grep 'ADR-002' "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md" | awk -F'|' '{print $4}' | tr -d ' ')
if [ "$FILE_STATUS" != "$INDEX_STATUS" ]; then
  assert_pass "status consistency: ADR-002 mismatch detected (file='$FILE_STATUS' vs INDEX='$INDEX_STATUS')"
else
  assert_fail "should detect status mismatch between file and INDEX for ADR-002"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-adr-conformance tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
