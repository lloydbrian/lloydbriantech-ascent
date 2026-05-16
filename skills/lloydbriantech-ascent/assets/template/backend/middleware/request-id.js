import { randomUUID } from 'node:crypto';

// Request ID middleware.
// Extracts trace-id from W3C TraceContext `traceparent` header if present;
// generates a new UUID v4 otherwise.
//
// The trace ID propagates into:
//   - req.traceId (available to all downstream middleware and routes)
//   - res 'x-trace-id' header (returned to caller)
//   - Every log entry via pino child logger (see middleware/logger.js)
//
// W3C TraceContext format: 00-<trace-id>-<span-id>-<flags>
// We extract the <trace-id> segment (32 hex chars).

const TRACEPARENT_REGEX = /^00-([0-9a-f]{32})-[0-9a-f]{16}-[0-9a-f]{2}$/;

export function requestId(req, res, next) {
  const traceparent = req.headers['traceparent'];
  let traceId;

  if (traceparent) {
    const match = traceparent.match(TRACEPARENT_REGEX);
    traceId = match ? match[1] : randomUUID().replace(/-/g, '');
  } else {
    traceId = randomUUID().replace(/-/g, '');
  }

  req.traceId = traceId;
  res.setHeader('x-trace-id', traceId);

  // Propagate traceparent on response for upstream correlation
  if (!traceparent) {
    const spanId = randomUUID().replace(/-/g, '').slice(0, 16);
    res.setHeader('traceparent', `00-${traceId}-${spanId}-01`);
  } else {
    res.setHeader('traceparent', traceparent);
  }

  next();
}
