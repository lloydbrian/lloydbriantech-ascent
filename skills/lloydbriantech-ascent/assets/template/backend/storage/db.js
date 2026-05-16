import Database from 'better-sqlite3';
import { readFileSync, readdirSync, mkdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { logger } from '../observability/logger.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
const MIGRATIONS_DIR = join(__dirname, 'migrations');

let db = null;

export function openDb() {
  const dbUrl = process.env[`<<ENV_PREFIX>>_DB_URL`] || 'file:./data/<<PROJECT_SLUG>>.sqlite';
  const dbPath = dbUrl.replace(/^file:/, '');

  const dir = dirname(dbPath);
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }

  db = new Database(dbPath);

  // WAL mode for concurrent reads during writes
  db.pragma('journal_mode = WAL');
  db.pragma('busy_timeout = 5000');
  db.pragma('foreign_keys = ON');

  runMigrations(db);

  logger.info({ dbPath, journalMode: 'WAL' }, 'Database connected');
  return db;
}

export function getDb() {
  if (!db) {
    throw new Error('Database not initialized — call openDb() first');
  }
  return db;
}

export function closeDb() {
  if (db) {
    db.close();
    logger.info('Database connection closed');
    db = null;
  }
}

function runMigrations(database) {
  database.exec(`
    CREATE TABLE IF NOT EXISTS _migrations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      applied_at TEXT NOT NULL DEFAULT (datetime('now'))
    )
  `);

  const applied = new Set(
    database.prepare('SELECT name FROM _migrations').all().map((r) => r.name)
  );

  const files = readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();

  let count = 0;
  for (const file of files) {
    if (applied.has(file)) continue;
    const sql = readFileSync(join(MIGRATIONS_DIR, file), 'utf-8');
    database.exec(sql);
    database.prepare('INSERT INTO _migrations (name) VALUES (?)').run(file);
    count++;
    logger.info({ migration: file }, `Applied migration: ${file}`);
  }

  if (count > 0) {
    logger.info({ count }, `${count} migration(s) applied`);
  }
}
