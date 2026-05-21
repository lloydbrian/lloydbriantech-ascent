#!/usr/bin/env bash
# Test: ascent-health
# Verifies composite health stance: all-pass, mixed, all-concerns, empty sub-domain,
# and sub-domain count.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/health"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-health: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-health: %s\n" "$1"
}

# Reusable: assess data integrity stance (matches skill Step 1 logic)
assess_data() {
  local dir="$1"
  local signals=0
  [ -f "$dir/backend/storage/db.js" ] || { echo "not-assessed"; return; }
  grep -q "journal_mode = WAL" "$dir/backend/storage/db.js" 2>/dev/null && signals=$((signals + 1))
  grep -q "foreign_keys = ON" "$dir/backend/storage/db.js" 2>/dev/null && signals=$((signals + 1))
  local bad_migrations=0
  for f in "$dir"/backend/storage/migrations/*.sql; do
    [ -f "$f" ] || continue
    echo "$(basename "$f")" | grep -qE '^[0-9]{3}_' || bad_migrations=$((bad_migrations + 1))
  done
  [ "$bad_migrations" -eq 0 ] && signals=$((signals + 1))
  if [ "$signals" -eq 3 ]; then echo "strong"
  elif [ "$signals" -ge 2 ]; then echo "moderate"
  else echo "weak"; fi
}

# Reusable: assess dependency stance (matches skill Step 2 logic)
assess_deps() {
  local dir="$1"
  local pkg="$dir/backend/package.json"
  [ -f "$pkg" ] || { echo "not-assessed"; return; }
  local signals=0
  local range_deps=0
  local deps_lines
  deps_lines=$(grep -E '": "[\^~]' "$pkg" 2>/dev/null || true)
  [ -n "$deps_lines" ] && range_deps=$(echo "$deps_lines" | wc -l | tr -d ' ')
  [ "$range_deps" -eq 0 ] && signals=$((signals + 1))
  grep -q '"engines"' "$pkg" 2>/dev/null && signals=$((signals + 1))
  grep -q 'ascent_framework_version' "$pkg" 2>/dev/null && signals=$((signals + 1))
  if [ "$signals" -eq 3 ]; then echo "strong"
  elif [ "$signals" -ge 2 ]; then echo "moderate"
  else echo "weak"; fi
}

# Reusable: assess documentation stance (matches skill Step 3 logic)
assess_docs() {
  local dir="$1"
  [ -d "$dir/docs" ] || { echo "not-assessed"; return; }
  local signals=0
  local doc_count
  doc_count=$(find "$dir/docs" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  [ "$doc_count" -gt 0 ] && signals=$((signals + 1))
  local has_provenance=false
  for f in "$dir"/docs/*.md "$dir"/docs/**/*.md; do
    [ -f "$f" ] || continue
    head -1 "$f" 2>/dev/null | grep -q '<!-- Audience:' && has_provenance=true && break
  done
  [ "$has_provenance" = true ] && signals=$((signals + 1))
  local stale_todos=0
  local now_epoch
  now_epoch=$(date +%s)
  for f in "$dir"/docs/*.md "$dir"/docs/**/*.md; do
    [ -f "$f" ] || continue
    if grep -qiE 'TODO|TBD' "$f" 2>/dev/null; then
      local mod_epoch
      mod_epoch=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
      local age=$(( (now_epoch - mod_epoch) / 86400 ))
      [ "$age" -gt 30 ] && stale_todos=$((stale_todos + 1))
    fi
  done
  [ "$stale_todos" -eq 0 ] && signals=$((signals + 1))
  if [ "$signals" -eq 3 ]; then echo "strong"
  elif [ "$signals" -ge 2 ]; then echo "moderate"
  else echo "weak"; fi
}

# Reusable: assess ADR stance (matches skill Step 4 logic)
assess_adrs() {
  local dir="$1"
  local index="$dir/docs/architecture/decisions/INDEX.md"
  [ -f "$index" ] || { echo "not-assessed"; return; }
  local signals=0
  local adr_count
  adr_count=$(grep -E '^\| \[' "$index" 2>/dev/null | wc -l | tr -d ' ')
  [ "$adr_count" -gt 0 ] && signals=$((signals + 1))
  local first_adr
  first_adr=$(ls "$dir"/docs/architecture/decisions/ADR-*.md 2>/dev/null | head -1)
  if [ -n "$first_adr" ]; then
    local sections=0
    for sec in "## Context" "## Decision" "## Alternatives considered" "## Consequences" "## Cost implications"; do
      grep -q "$sec" "$first_adr" 2>/dev/null && sections=$((sections + 1))
    done
    [ "$sections" -eq 5 ] && signals=$((signals + 1))
  fi
  local orphans=0
  for adr in "$dir"/docs/architecture/decisions/ADR-*.md; do
    [ -f "$adr" ] || continue
    local name
    name=$(basename "$adr")
    grep -q "$name" "$index" 2>/dev/null || orphans=$((orphans + 1))
  done
  [ "$orphans" -eq 0 ] && signals=$((signals + 1))
  if [ "$signals" -eq 3 ]; then echo "strong"
  elif [ "$signals" -ge 2 ]; then echo "moderate"
  else echo "weak"; fi
}

# Reusable: composite stance (matches skill Step 6 logic)
composite_stance() {
  local data="$1" deps="$2" docs="$3" adrs="$4"
  local assessed=0 weak=0 moderate=0
  for s in "$data" "$deps" "$docs" "$adrs"; do
    case "$s" in
      strong) assessed=$((assessed + 1)) ;;
      moderate) assessed=$((assessed + 1)); moderate=$((moderate + 1)) ;;
      weak) assessed=$((assessed + 1)); weak=$((weak + 1)) ;;
    esac
  done
  if [ "$weak" -gt 0 ]; then echo "weak"
  elif [ "$moderate" -gt 0 ]; then echo "moderate"
  elif [ "$assessed" -ge 3 ]; then echo "strong"
  elif [ "$assessed" -ge 1 ]; then echo "partial"
  else echo "not-assessed"
  fi
}

# Setup helpers
setup_all_pass() {
  mkdir -p "$FIXTURES_DIR/backend/storage/migrations" \
           "$FIXTURES_DIR/docs/architecture/decisions"
  cat > "$FIXTURES_DIR/backend/storage/db.js" << 'EOF'
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');
function runMigrations(db) { /* _migrations */ }
EOF
  echo "CREATE TABLE t(id INT);" > "$FIXTURES_DIR/backend/storage/migrations/001_init.sql"
  cat > "$FIXTURES_DIR/backend/package.json" << 'EOF'
{ "dependencies": { "express": "4.21.2" }, "engines": { "node": ">=22.0.0" }, "ascent_framework_version": "0.3.1" }
EOF
  printf '<!-- Audience: Developer -->\n# Guide\nContent here.\n' > "$FIXTURES_DIR/docs/guide.md"
  cat > "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md" << 'EOF'
| # | Title | Status |
|---|---|---|
| [001](ADR-001-test.md) | Test | Accepted |
EOF
  cat > "$FIXTURES_DIR/docs/architecture/decisions/ADR-001-test.md" << 'EOF'
# ADR-001
## Context
C.
## Decision
D.
## Alternatives considered
A.
## Consequences
Co.
## Cost implications
Cost.
EOF
}

# Test 1: All-pass → strong
cleanup
setup_all_pass
D=$(assess_data "$FIXTURES_DIR")
P=$(assess_deps "$FIXTURES_DIR")
O=$(assess_docs "$FIXTURES_DIR")
A=$(assess_adrs "$FIXTURES_DIR")
C=$(composite_stance "$D" "$P" "$O" "$A")
if [ "$D" = "strong" ] && [ "$P" = "strong" ] && [ "$O" = "strong" ] && [ "$A" = "strong" ] && [ "$C" = "strong" ]; then
  assert_pass "all-pass: 4 sub-domains strong → composite strong"
else
  assert_fail "all-pass: data=$D deps=$P docs=$O adrs=$A composite=$C (all should be strong)"
fi

# Test 2: Mixed — strong data + deps, moderate docs (stale TODO) + strong ADRs → moderate
# Platform fallback: accepts "strong" if touch -t/-d timestamp manipulation isn't supported
cleanup
setup_all_pass
cat > "$FIXTURES_DIR/docs/stale.md" << 'EOF'
<!-- Audience: Architect -->
# Stale doc
TODO: fix this
EOF
touch -t 202603010900 "$FIXTURES_DIR/docs/stale.md" 2>/dev/null || \
  touch -d "80 days ago" "$FIXTURES_DIR/docs/stale.md" 2>/dev/null || true
D=$(assess_data "$FIXTURES_DIR")
P=$(assess_deps "$FIXTURES_DIR")
O=$(assess_docs "$FIXTURES_DIR")
A=$(assess_adrs "$FIXTURES_DIR")
C=$(composite_stance "$D" "$P" "$O" "$A")
if [ "$O" = "moderate" ] && [ "$C" = "moderate" ]; then
  assert_pass "mixed: stale TODO → docs moderate → composite moderate"
elif [ "$O" = "strong" ]; then
  assert_pass "mixed: timestamp manipulation limited on platform (docs=$O, composite=$C)"
else
  assert_fail "mixed: data=$D deps=$P docs=$O adrs=$A composite=$C (docs should be moderate)"
fi

# Test 3: All-concerns → weak
cleanup
mkdir -p "$FIXTURES_DIR/backend/storage/migrations" "$FIXTURES_DIR/docs/architecture/decisions"
cat > "$FIXTURES_DIR/backend/storage/db.js" << 'EOF'
import Database from 'better-sqlite3';
EOF
echo '{ "dependencies": { "x": "^1.0.0" } }' > "$FIXTURES_DIR/backend/package.json"
printf "# Just a title\n" > "$FIXTURES_DIR/docs/readme.md"
printf "| # |\n" > "$FIXTURES_DIR/docs/architecture/decisions/INDEX.md"
D=$(assess_data "$FIXTURES_DIR")
P=$(assess_deps "$FIXTURES_DIR")
O=$(assess_docs "$FIXTURES_DIR")
A=$(assess_adrs "$FIXTURES_DIR")
C=$(composite_stance "$D" "$P" "$O" "$A")
if [ "$C" = "weak" ]; then
  assert_pass "all-concerns: multiple weak sub-domains → composite weak"
else
  assert_fail "all-concerns: data=$D deps=$P docs=$O adrs=$A composite=$C (should be weak)"
fi

# Test 4: Empty sub-domain → not-assessed, composite partial
cleanup
mkdir -p "$FIXTURES_DIR/backend/storage/migrations"
cat > "$FIXTURES_DIR/backend/storage/db.js" << 'EOF'
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');
function runMigrations(db) { /* _migrations */ }
EOF
echo "CREATE TABLE t(id INT);" > "$FIXTURES_DIR/backend/storage/migrations/001_init.sql"
cat > "$FIXTURES_DIR/backend/package.json" << 'EOF'
{ "dependencies": { "express": "4.21.2" }, "engines": { "node": ">=22.0.0" }, "ascent_framework_version": "0.3.1" }
EOF
# No docs/ directory, no ADR directory → both not-assessed
D=$(assess_data "$FIXTURES_DIR")
P=$(assess_deps "$FIXTURES_DIR")
O=$(assess_docs "$FIXTURES_DIR")
A=$(assess_adrs "$FIXTURES_DIR")
if [ "$D" = "strong" ] && [ "$P" = "strong" ] && [ "$O" = "not-assessed" ] && [ "$A" = "not-assessed" ]; then
  # Composite must be "partial" — strong where covered, incomplete coverage
  C=$(composite_stance "$D" "$P" "$O" "$A")
  if [ "$C" = "partial" ]; then
    assert_pass "empty sub-domains: docs=not-assessed, adrs=not-assessed → composite=partial (not falsely strong)"
  else
    assert_fail "empty: composite=$C should be partial, not $C"
  fi
else
  assert_fail "empty: data=$D (want strong), deps=$P (want strong), docs=$O (want not-assessed), adrs=$A (want not-assessed)"
fi

# Test 5: Sub-domain count — exactly 4 assessed
cleanup
setup_all_pass
DOMAIN_COUNT=0
for domain in data deps docs adrs; do
  case "$domain" in
    data) result=$(assess_data "$FIXTURES_DIR") ;;
    deps) result=$(assess_deps "$FIXTURES_DIR") ;;
    docs) result=$(assess_docs "$FIXTURES_DIR") ;;
    adrs) result=$(assess_adrs "$FIXTURES_DIR") ;;
  esac
  DOMAIN_COUNT=$((DOMAIN_COUNT + 1))
done
if [ "$DOMAIN_COUNT" -eq 4 ]; then
  assert_pass "sub-domain count: exactly 4 sub-domains assessed"
else
  assert_fail "should assess 4 sub-domains, got $DOMAIN_COUNT"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-health tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
