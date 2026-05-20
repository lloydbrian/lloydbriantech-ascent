#!/usr/bin/env bash
# Test: ascent-data-health
# Verifies SQLite-WAL configuration checks: pragma detection, migration tracking, ordering.
# Per PHASE-3-PLAN.md §4: bash test, self-contained, trap-based cleanup.
set -euo pipefail

FIXTURES_DIR="tests/skills/.fixtures/data-health"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  rm -rf "$FIXTURES_DIR"
}
trap cleanup EXIT

setup_healthy_backend() {
  mkdir -p "$FIXTURES_DIR/backend/storage/migrations"
  cat > "$FIXTURES_DIR/backend/storage/db.js" << 'DBEOF'
import Database from 'better-sqlite3';

let db = null;

export function openDb() {
  db = new Database('./data/app.sqlite');
  db.pragma('journal_mode = WAL');
  db.pragma('busy_timeout = 5000');
  db.pragma('foreign_keys = ON');
  runMigrations(db);
  return db;
}

function runMigrations(database) {
  database.exec(`CREATE TABLE IF NOT EXISTS _migrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    applied_at TEXT NOT NULL DEFAULT (datetime('now'))
  )`);
}
DBEOF
  echo "CREATE TABLE items (id INTEGER PRIMARY KEY);" > "$FIXTURES_DIR/backend/storage/migrations/001_initial.sql"
  echo "ALTER TABLE items ADD COLUMN name TEXT;" > "$FIXTURES_DIR/backend/storage/migrations/002_add_name.sql"
}

assert_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "PASS  ascent-data-health: %s\n" "$1"
}

assert_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "FAIL  ascent-data-health: %s\n" "$1"
}

# Reusable: check pragma presence (matches skill Steps 1-2 logic)
check_pragma() {
  local db_file="$1"
  local pragma_name="$2"
  grep -q "pragma.*${pragma_name}" "$db_file" 2>/dev/null
}

# Reusable: check migration runner presence (matches skill Step 3 logic)
check_migration_runner() {
  local db_file="$1"
  grep -q "_migrations" "$db_file" 2>/dev/null && grep -q "runMigrations\|run_migrations" "$db_file" 2>/dev/null
}

# Reusable: validate migration file ordering (matches skill Step 4 logic)
check_migration_ordering() {
  local migrations_dir="$1"
  local bad_files=0
  for f in "$migrations_dir"/*.sql; do
    [ -f "$f" ] || continue
    local basename
    basename=$(basename "$f")
    if ! echo "$basename" | grep -qE '^[0-9]{3}_'; then
      bad_files=$((bad_files + 1))
    fi
  done
  return $bad_files
}

# Test 1: WAL + FK pragma detection on healthy fixture
cleanup
setup_healthy_backend
WAL_OK=false
FK_OK=false
RUNNER_OK=false
check_pragma "$FIXTURES_DIR/backend/storage/db.js" "journal_mode = WAL" && WAL_OK=true
check_pragma "$FIXTURES_DIR/backend/storage/db.js" "foreign_keys = ON" && FK_OK=true
check_migration_runner "$FIXTURES_DIR/backend/storage/db.js" && RUNNER_OK=true
if [ "$WAL_OK" = true ] && [ "$FK_OK" = true ] && [ "$RUNNER_OK" = true ]; then
  assert_pass "healthy backend: WAL mode, foreign keys, migration runner all detected"
else
  assert_fail "healthy backend should pass all 3 checks: WAL=$WAL_OK FK=$FK_OK runner=$RUNNER_OK"
fi

# Test 2: Migration ordering — valid NNN_ prefix vs invalid non-padded prefix
cleanup
setup_healthy_backend
# Valid ordering check
if check_migration_ordering "$FIXTURES_DIR/backend/storage/migrations"; then
  # Now add a bad file and verify detection
  echo "CREATE TABLE bad;" > "$FIXTURES_DIR/backend/storage/migrations/3_bad.sql"
  if check_migration_ordering "$FIXTURES_DIR/backend/storage/migrations"; then
    assert_fail "should detect non-padded migration file '3_bad.sql'"
  else
    assert_pass "migration ordering: 001_/002_ valid, 3_ detected as non-padded"
  fi
else
  assert_fail "valid migration files 001_/002_ should pass ordering check"
fi

# Test 3: Missing migration runner detection
cleanup
mkdir -p "$FIXTURES_DIR/backend/storage"
cat > "$FIXTURES_DIR/backend/storage/db.js" << 'DBEOF'
import Database from 'better-sqlite3';
let db = null;
export function openDb() {
  db = new Database('./data/app.sqlite');
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  return db;
}
DBEOF
if check_migration_runner "$FIXTURES_DIR/backend/storage/db.js"; then
  assert_fail "db.js without migration runner should be detected"
else
  assert_pass "missing migration runner: detected (no _migrations pattern in db.js)"
fi

# Summary
TOTAL=$((PASS_COUNT + FAIL_COUNT))
printf "\nascent-data-health tests: %s/%s PASS\n" "$PASS_COUNT" "$TOTAL"
[ "$FAIL_COUNT" -eq 0 ] || exit 1
