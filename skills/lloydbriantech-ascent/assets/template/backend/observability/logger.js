import pino from 'pino';

// Structured JSON logger per observability-contract.md.
//
// Canonical fields emitted on every log entry:
//   level   — info, warn, error, debug (pino native)
//   ts      — timestamp in epoch ms (pino native; formatters convert to ISO)
//   msg     — human-readable event message
//   trace_id — propagated via child loggers from request-id middleware
//   ctx     — structured contextual data (spread into the log object)
//
// Usage:
//   logger.info({ trace_id, key: 'value' }, 'Human-readable message');
//   const child = logger.child({ trace_id: req.traceId });
//   child.info({ ctx: { userId: '...' } }, 'Request processed');

const level = process.env[`<<ENV_PREFIX>>_LOG_LEVEL`] || 'info';

export const logger = pino({
  level,
  timestamp: pino.stdTimeFunctions.isoTime,
  formatters: {
    level: (label) => ({ level: label }),
  },
  base: {
    service: '<<PROJECT_SLUG>>',
  },
});
