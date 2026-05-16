import { randomUUID } from 'node:crypto';
import * as itemsStorage from '../storage/items.js';

// Service layer: business logic.
// Generates IDs, sets timestamps, orchestrates storage calls.
// No HTTP concepts here — no req, no res, no status codes.

export function getAll() {
  return itemsStorage.listAll();
}

export function create({ name }) {
  const item = {
    id: randomUUID(),
    name,
    created_at: new Date().toISOString(),
  };
  itemsStorage.insertOne(item);
  return item;
}
