# ADR-005: Structured JSON logging

**Status:** Accepted
**Date:** <<SCAFFOLD_DATE>> (America/New_York)
**Decider:** <<BRAND>> · ASCENT v<<FRAMEWORK_VERSION>> baseline

## Context

<<PROJECT_TITLE>> runs in containers per [ADR-001](ADR-001-container-first-development.md). Logs emitted from those containers need to be greppable, parseable, correlatable across requests, and ingestible by log-aggregation systems (CloudWatch, Datadog, ELK, Loki). The alternative — plain-text `console.log` — produces human-readable-ish output that fails the moment you need to search, filter, or correlate.

The observability contract for this project requires every log entry to carry:

- `level` — info, warn, error, debug
- `ts` — ISO 8601 timestamp
- `trace_id` — W3C TraceContext trace-id for request correlation
- `msg` — human-readable event message
- `ctx` — structured contextual data (user_id, operation, etc.)

This shape enables: "show me all error logs for trace-id X in the last hour" — a query that's impossible with plain text.

## Decision

<<PROJECT_TITLE>> uses pino for structured JSON logging. Every log entry is a JSON object emitted to stdout. The log level is configurable via `<<ENV_PREFIX>>_LOG_LEVEL` (default: `info` in production, `debug` in development).

The logging library (pino) is chosen for:

- Native JSON output (no format transformation needed)
- ISO timestamp support
- Child-logger pattern (propagates `trace_id` through the request lifecycle)
- Low overhead (~30% faster than Winston in benchmarks)
- Minimal API surface

## Alternatives considered

**Plain text (`console.log`).** Rejected because plain-text logs are ungreppable by field, uncorrelatable across requests (no trace_id), and unparseable by log-aggregation tools without a regex-based parser that breaks every time the format changes.

**Extended Log Format (ELF).** Rejected because ELF is a W3C standard designed for web server access logs, not application-level structured logging. It's tab-separated with a fixed schema that doesn't accommodate the `ctx` field's variable structure.

**CSV logging.** Rejected because CSV requires a fixed column order, doesn't handle nested objects (like `ctx`), and is fragile against messages containing commas or newlines.

**Winston.** Rejected in favor of pino because Winston's transport-based architecture adds configuration complexity and runtime overhead that pino avoids. Winston is more configurable; pino is faster and simpler for the "emit JSON to stdout" use case that containerized services need.

## Consequences

**Easier:**

- Every log entry is a parseable JSON object — grep, jq, and log-aggregation tools work out of the box
- Request correlation via `trace_id` works across services when the project adds them
- Log level filtering is one environment variable (`<<ENV_PREFIX>>_LOG_LEVEL`)
- Child loggers automatically include `trace_id` in every entry without manual propagation
- Debug logs in development; info+ in production — configurable without code changes

**Harder:**

- Raw JSON in the terminal is less readable than plain text during development — mitigated by pino-pretty (or similar) in dev mode
- Developers must use the logger (`logger.info(...)`) rather than `console.log(...)` — a discipline shift
- Every log entry has overhead (timestamp generation, JSON serialization) — negligible in practice but non-zero

**Neutral:**

- Log volume in production is comparable to plain text (info-level events are logged either way; the format changes, not the quantity)

## Cost implications

**Time:** One-time cost to configure pino (already done in the scaffold). Ongoing time savings when debugging production issues (structured search vs. regex-guessing on plain text).

**Complexity:** Minimal. One logger module, one middleware. Lower complexity than the alternative (debugging plain-text logs in production under time pressure).

**Future flexibility:** The JSON shape is stable; switching from pino to another JSON logger (if ever needed) changes one file. The observability contract (the field names and shapes) is independent of the library.

**Money:** None. Pino is MIT-licensed and free.
