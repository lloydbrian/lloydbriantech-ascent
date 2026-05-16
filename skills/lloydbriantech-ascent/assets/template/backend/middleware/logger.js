import pinoHttp from 'pino-http';
import { logger } from '../observability/logger.js';

// Structured JSON request logging middleware.
// Emits one log entry per completed request with the canonical fields
// from observability-contract.md: level, ts, trace_id, msg, ctx.
//
// The trace_id is injected from req.traceId (set by request-id middleware).

export const httpLogger = pinoHttp({
  logger,
  genReqId: (req) => req.traceId,
  customProps: (req) => ({
    trace_id: req.traceId,
  }),
  customSuccessMessage: (req, res) =>
    `${req.method} ${req.url} ${res.statusCode}`,
  customErrorMessage: (req, res) =>
    `${req.method} ${req.url} ${res.statusCode}`,
  serializers: {
    req: (req) => ({
      method: req.method,
      url: req.url,
      headers: {
        'user-agent': req.headers['user-agent'],
        'content-type': req.headers['content-type'],
      },
    }),
    res: (res) => ({
      statusCode: res.statusCode,
    }),
  },
});
