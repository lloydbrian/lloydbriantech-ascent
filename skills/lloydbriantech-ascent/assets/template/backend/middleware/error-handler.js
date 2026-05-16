import { logger } from '../observability/logger.js';

// Catch-all error handler — must be registered last in the middleware stack.
//
// Logs the error with trace_id for correlation, then returns a sanitized
// response. Stack traces are included only in non-production environments.
// Internal error details never leak to the client in production.

export function errorHandler(err, req, res, _next) {
  const status = err.status || err.statusCode || 500;
  const message = status < 500 ? err.message : 'Internal server error';

  logger.error({
    err: {
      type: err.constructor.name,
      message: err.message,
      stack: err.stack,
    },
    trace_id: req.traceId,
    method: req.method,
    url: req.url,
  }, `${req.method} ${req.url} error: ${err.message}`);

  const body = {
    error: {
      message,
      status,
    },
  };

  if (process.env[`<<ENV_PREFIX>>_NODE_ENV`] !== 'production') {
    body.error.stack = err.stack;
  }

  res.status(status).json(body);
}
