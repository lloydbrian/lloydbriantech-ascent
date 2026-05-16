import { Router } from 'express';
import { getDb } from '../storage/db.js';

export const healthRoutes = Router();

// GET /healthz — liveness check.
// Returns 200 if the process is responsive. NO database check.
// Orchestrators poll this to decide whether to restart the container.
// A degraded backend (DB down but process alive) passes /healthz so
// the orchestrator doesn't restart it — restart wouldn't fix DB.
healthRoutes.get('/healthz', (_req, res) => {
  res.json({ status: 'ok' });
});

// GET /readyz — readiness check.
// Returns 200 only if:
//   1. DB is reachable (SELECT 1 succeeds)
//   2. Schema migrations applied (items table exists)
//   3. Ready to serve traffic
// Orchestrators use this to decide whether to route traffic to the container.
healthRoutes.get('/readyz', (_req, res) => {
  try {
    const db = getDb();
    db.prepare('SELECT 1').get();
    const table = db.prepare(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='items'"
    ).get();
    if (!table) {
      return res.status(503).json({
        status: 'not ready',
        reason: 'schema not initialized',
      });
    }
    res.json({ status: 'ready' });
  } catch (err) {
    res.status(503).json({
      status: 'not ready',
      reason: 'database unreachable',
    });
  }
});
