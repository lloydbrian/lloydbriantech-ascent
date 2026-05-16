import express from 'express';
import { createServer } from 'node:http';
import { randomUUID } from 'node:crypto';
import { logger } from './observability/logger.js';
import { requestId } from './middleware/request-id.js';
import { httpLogger } from './middleware/logger.js';
import { errorHandler } from './middleware/error-handler.js';
import { healthRoutes } from './routes/health.js';
import { itemRoutes } from './routes/items.js';
import { openDb, closeDb } from './storage/db.js';

const PORT = process.env[`<<ENV_PREFIX>>_PORT`] || 3001;
const HOST = process.env[`<<ENV_PREFIX>>_HOST`] || '0.0.0.0';

const app = express();
const server = createServer(app);

// Middleware stack (order matters)
app.use(requestId);
app.use(httpLogger);
app.use(express.json({ limit: '100kb' }));

// Routes
app.use(healthRoutes);
app.use('/api', itemRoutes);

// Error handler — must be last
app.use(errorHandler);

async function start() {
  const db = openDb();
  logger.info({
    event: 'service.started',
    version: process.env.npm_package_version || '<<PROJECT_VERSION>>',
    host: HOST,
    port: PORT,
    engine: process.env['<<INSIDE_CONTAINER_MARKER>>'] ? 'container' : 'host',
  }, `<<PROJECT_TITLE>> listening on ${HOST}:${PORT}`);

  server.listen(PORT, HOST);
}

// Graceful shutdown (Principle 12)
function shutdown(signal) {
  logger.info({ event: 'service.draining', signal }, `${signal} received, draining`);
  server.close(() => {
    closeDb();
    logger.info({ event: 'service.stopped' }, 'Server stopped');
    process.exit(0);
  });
  setTimeout(() => {
    logger.error({ event: 'service.forced_exit' }, 'Forced exit after drain timeout');
    process.exit(1);
  }, 15000);
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

start().catch((err) => {
  logger.fatal({ err }, 'Failed to start server');
  process.exit(1);
});
