import { getDb } from './db.js';

// Storage layer: SQL queries only.
// No business logic, no HTTP concepts. Only this layer writes to the database.

export function listAll() {
  const db = getDb();
  return db.prepare('SELECT id, name, created_at FROM items ORDER BY created_at DESC').all();
}

export function insertOne({ id, name, created_at }) {
  const db = getDb();
  db.prepare('INSERT INTO items (id, name, created_at) VALUES (?, ?, ?)').run(id, name, created_at);
}
