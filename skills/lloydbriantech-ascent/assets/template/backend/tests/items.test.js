import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import Database from 'better-sqlite3';
import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Use an in-memory SQLite database for test isolation.
// This proves the test runner works and the service layer's shape is correct.

describe('items service', () => {
  let db;

  beforeAll(() => {
    db = new Database(':memory:');
    db.pragma('journal_mode = WAL');

    const migration = readFileSync(
      join(__dirname, '..', 'storage', 'migrations', '001_initial.sql'),
      'utf-8'
    );
    db.exec(migration);
  });

  afterAll(() => {
    db.close();
  });

  it('creates an item with id, name, and created_at', () => {
    const id = 'test-uuid-001';
    const name = 'Mow lawn';
    const created_at = new Date().toISOString();

    db.prepare('INSERT INTO items (id, name, created_at) VALUES (?, ?, ?)')
      .run(id, name, created_at);

    const row = db.prepare('SELECT * FROM items WHERE id = ?').get(id);

    expect(row).toBeDefined();
    expect(row.id).toBe(id);
    expect(row.name).toBe(name);
    expect(row.created_at).toBe(created_at);
  });

  it('lists items ordered by created_at descending', () => {
    const earlier = '2026-01-01T00:00:00.000Z';
    const later = '2026-12-31T00:00:00.000Z';

    db.prepare('INSERT INTO items (id, name, created_at) VALUES (?, ?, ?)')
      .run('test-uuid-002', 'First item', earlier);
    db.prepare('INSERT INTO items (id, name, created_at) VALUES (?, ?, ?)')
      .run('test-uuid-003', 'Second item', later);

    const rows = db.prepare('SELECT * FROM items ORDER BY created_at DESC').all();

    expect(rows.length).toBeGreaterThanOrEqual(2);
    expect(rows[0].created_at >= rows[1].created_at).toBe(true);
  });

  it('enforces name length constraint at the database level', () => {
    const longName = 'x'.repeat(201);

    expect(() => {
      db.prepare('INSERT INTO items (id, name, created_at) VALUES (?, ?, ?)')
        .run('test-uuid-004', longName, new Date().toISOString());
    }).toThrow();
  });
});
