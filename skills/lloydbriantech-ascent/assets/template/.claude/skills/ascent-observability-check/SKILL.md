---
name: ascent-observability-check
description: >-
  Verifies that <<PROJECT_TITLE>>'s backend services emit observability
  data per the observability contract: structured JSON logs with the
  required fields, /healthz and /readyz endpoints, lifecycle events
  (service.started, service.draining, service.stopped), and trace-id
  propagation via W3C TraceContext. Can run standalone or as a component
  of ascent-self-audit's umbrella.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-observability-check

Validates that <<PROJECT_TITLE>>'s services emit observability data per the observability contract. Checks log field presence, healthcheck endpoints, lifecycle events, and trace propagation — the baseline that makes production debugging possible without special tools. Runs standalone or as a component of [ascent-self-audit](../ascent-self-audit/SKILL.md)'s umbrella audit.

## When this skill engages

- Before deploying to staging or production — "is this service observable?"
- After adding a new service or endpoint — "does it emit correctly?"
- As a component of ascent-self-audit's comprehensive check (delegated invocation)
- When debugging reveals missing trace correlation or log fields
- After modifying the logger, middleware, or healthcheck handlers
- When onboarding a developer to explain the observability contract

## Inputs

- **Backend source directory** — defaults to `backend/`
- **Specific service or endpoint** (optional) — focus the check on a subset of the backend
- **Invocation mode** — standalone (full output with guidance) or component (structured PASS/FAIL for umbrella aggregation)

## Outputs

- **Observability report** — each contract requirement checked with PASS or FAIL status
- **Per-violation detail** — the specific gap, the file that should contain it, and what to add
- **Categories** — logs (field presence), health (endpoint existence), lifecycle (event emission), traces (propagation)
- **Summary line** — "N/M observability checks passing"
- **Exit code** — 0 if all checks pass, 1 if any check fails

## Operational logic

The skill executes these checks in order. Each check produces PASS or FAIL. Step numbers are local to this skill.

### Step 1 — Verify logger module exists and emits required fields

**Condition:** `backend/observability/logger.js` (or equivalent) exists. The logger configuration includes: `level` as a string label (not numeric), `timestamp` in ISO format, and a `service` base field set to the project slug.

**Action on PASS:** Report "Logger module present with required field configuration — PASS."

**Action on FAIL:** Report what's missing. Example: "FAIL: backend/observability/logger.js missing — create a structured JSON logger per observability-contract.md." Or: "FAIL: logger does not configure ISO timestamps — add `timestamp: pino.stdTimeFunctions.isoTime`."

**Fallback:** If the logger uses a different library than pino, check for equivalent field configuration rather than pino-specific API calls.

### Step 2 — Verify request-id middleware extracts or generates trace-id

**Condition:** `backend/middleware/request-id.js` (or equivalent) exists. The middleware either extracts `trace-id` from the W3C `traceparent` header or generates a new UUID. The trace-id is attached to `req.traceId` and propagated to response headers.

**Action on PASS:** Report "Request-id middleware with W3C TraceContext support — PASS."

**Action on FAIL:** Report what's missing. Example: "FAIL: no request-id middleware found — create backend/middleware/request-id.js that extracts traceparent or generates a UUID per request."

**Inline example:** A middleware that generates `req.id` without checking `traceparent` → FAIL: "trace-id must be extracted from traceparent header when present, not always generated fresh."

### Step 3 — Verify HTTP logger middleware emits trace_id

**Condition:** `backend/middleware/logger.js` (or equivalent) exists. The middleware configuration includes `trace_id` propagation from `req.traceId` into every log entry.

**Action on PASS:** Report "HTTP logger middleware propagates trace_id — PASS."

**Action on FAIL:** Report "FAIL: HTTP logger does not propagate trace_id — add `customProps: (req) => ({ trace_id: req.traceId })` or equivalent."

### Step 4 — Verify /healthz endpoint exists (liveness, no DB)

**Condition:** `backend/routes/health.js` (or equivalent) exists and defines a `GET /healthz` route. The handler does NOT import or call any database module — it returns 200 if the process is responsive, nothing more.

**Action on PASS:** Report "/healthz endpoint present, no database dependency — PASS."

**Action on FAIL (missing):** Report "FAIL: /healthz endpoint not found — create it in routes/health.js. It should return 200 with `{status: 'ok'}` and must NOT check the database."

**Action on FAIL (DB dependency):** Report "FAIL: /healthz imports database module — remove the dependency. /healthz is for liveness (is the process alive?), not readiness. A degraded backend (DB down) should still pass /healthz so the orchestrator doesn't restart it."

### Step 5 — Verify /readyz endpoint exists (readiness, checks DB)

**Condition:** `backend/routes/health.js` defines a `GET /readyz` route. The handler checks database connectivity (e.g., `SELECT 1`) and schema initialization. Returns 200 when ready, 503 when not.

**Action on PASS:** Report "/readyz endpoint present with database connectivity check — PASS."

**Action on FAIL (missing):** Report "FAIL: /readyz endpoint not found — create it in routes/health.js with a DB connectivity check."

**Action on FAIL (no DB check):** Report "FAIL: /readyz does not check database — it must verify DB is reachable and schema is initialized. Without this, the orchestrator routes traffic to an unready service."

### Step 6 — Verify /healthz and /readyz are differentiated

**Condition:** `/healthz` does NOT check the database. `/readyz` DOES check the database. The two endpoints serve different purposes (liveness vs readiness) and must not be conflated.

**Action on PASS:** Report "/healthz and /readyz correctly differentiated — PASS."

**Action on FAIL:** Report "FAIL: /healthz and /readyz are not differentiated — /healthz checks DB (it shouldn't) or /readyz doesn't check DB (it should). See observability-contract.md for the distinction."

### Step 7 — Verify lifecycle events in server startup/shutdown

**Condition:** `backend/server.js` emits three lifecycle events:
- `service.started` — after server begins listening (with version, host, port in the log entry)
- `service.draining` — on SIGTERM receipt (before connections are closed)
- `service.stopped` — on clean exit (last log line before process.exit)

**Action on PASS:** Report "Lifecycle events (started, draining, stopped) present — PASS."

**Action on FAIL:** For each missing event, report which one and where to add it. Example: "FAIL: service.draining event not emitted — add `logger.info({ event: 'service.draining' }, 'SIGTERM received')` in the SIGTERM handler."

### Step 8 — Verify error handler sanitizes in production

**Condition:** `backend/middleware/error-handler.js` (or equivalent) exists. The handler logs errors with `trace_id` and returns sanitized responses. Stack traces are included only when `NODE_ENV !== 'production'`.

**Action on PASS:** Report "Error handler sanitizes production responses — PASS."

**Action on FAIL:** Report what's missing. Example: "FAIL: error handler includes stack traces in all environments — add a production check to strip stack from the response body."

### Step 9 — Aggregate and report

Collect all PASS/FAIL results from Steps 1-8. Report summary: "8/8 observability checks passing" or "6/8 checks passing (2 violations found)."

In component mode: return structured result `{skill: "ascent-observability-check", passed: N, total: M, violations: [...]}`.

In standalone mode: print the full report with guidance for each violation.

## Examples

### Example 1 — Full observability compliance

**Input state:** Backend with pino logger (ISO timestamps, service name), request-id middleware (W3C traceparent extraction), pino-http middleware (trace_id propagation), /healthz (no DB), /readyz (DB + schema check), lifecycle events in server.js, error handler with production sanitization.

**Skill output:**
```
ascent-observability-check: 8/8 checks passing
  PASS: Logger module present with required field configuration
  PASS: Request-id middleware with W3C TraceContext support
  PASS: HTTP logger middleware propagates trace_id
  PASS: /healthz endpoint present, no database dependency
  PASS: /readyz endpoint present with database connectivity check
  PASS: /healthz and /readyz correctly differentiated
  PASS: Lifecycle events (started, draining, stopped) present
  PASS: Error handler sanitizes production responses
```

### Example 2 — /healthz checks database (common mistake)

**Input state:** `routes/health.js` line 12: `const db = require('../storage/db.js')` inside the /healthz handler.

**Skill output:**
```
ascent-observability-check: 6/8 checks passing (2 violations)
  ...
  FAIL: /healthz endpoint present, no database dependency
    → routes/health.js:12 imports '../storage/db.js' in /healthz handler
    → Fix: remove the DB import from /healthz. Liveness checks must not depend on external services.
  FAIL: /healthz and /readyz correctly differentiated
    → Both endpoints check the database — they serve the same purpose. /healthz should be DB-free.
  ...
```

### Example 3 — Missing trace_id propagation

**Input state:** Logger exists but request-id middleware generates `req.id` without checking `traceparent`. HTTP logger doesn't include `trace_id` in log entries.

**Skill output:**
```
ascent-observability-check: 6/8 checks passing (2 violations)
  ...
  FAIL: Request-id middleware with W3C TraceContext support
    → middleware/request-id.js generates req.id but does not check traceparent header
    → Fix: extract trace-id from traceparent when present; generate UUID only when absent
  FAIL: HTTP logger middleware propagates trace_id
    → middleware/logger.js does not include trace_id in log entries
    → Fix: add customProps: (req) => ({ trace_id: req.traceId }) to the pino-http config
  ...
```

### Example 4 — No observability layer (edge case)

**Input state:** Backend has `server.js` and `routes/` but no `observability/`, no `middleware/`, no health endpoints.

**Skill output:**
```
ascent-observability-check: 0/8 checks passing (8 violations)
  FAIL: Logger module present — backend/observability/logger.js not found
  FAIL: Request-id middleware — backend/middleware/request-id.js not found
  FAIL: HTTP logger middleware — backend/middleware/logger.js not found
  FAIL: /healthz endpoint — not found in routes/
  FAIL: /readyz endpoint — not found in routes/
  FAIL: /healthz and /readyz differentiated — neither endpoint exists
  FAIL: Lifecycle events — server.js does not emit service.started/draining/stopped
  FAIL: Error handler — backend/middleware/error-handler.js not found
```

## Anti-patterns

### Anti-pattern 1 — Placeholder observability

A logger that emits the right field names but hardcodes empty values (`trace_id: ''`), or a /readyz endpoint that always returns 200 without checking the database. **Why it's tempting:** it passes structural checks while avoiding the work of real implementation. **What to do instead:** the check validates substantive implementation (Step 4 verifies /healthz doesn't import DB; Step 5 verifies /readyz does). Surface this: if an endpoint always returns 200, it's not a health check.

### Anti-pattern 2 — console.log as the logger

Using `console.log` for application logging instead of a structured logger. **Why it's tempting:** console.log is zero-config and prints to stdout. **What to do instead:** use pino (or equivalent) — it emits structured JSON with the required fields. `console.log("user did X")` produces ungreppable, uncorrelated text. Step 1 catches this by checking for the logger module.

### Anti-pattern 3 — Conflating /healthz and /readyz

One endpoint that checks everything (process alive AND database reachable). **Why it's tempting:** one endpoint seems simpler. **What to do instead:** two endpoints, deliberately different. /healthz = liveness (restart the container if it fails). /readyz = readiness (stop routing traffic if it fails). Conflating them produces flapping pods.

### Anti-pattern 4 — Logging request bodies

The HTTP logger middleware logs the full request body for debugging. **Why it's tempting:** helps debug what the client sent. **What to do instead:** log request metadata (method, URL, status, latency) but not the body. Bodies almost always contain PII or secrets. Log identifiers, not contents.

### Anti-pattern 5 — Tracing only successful requests

Trace propagation only runs on non-error paths. Error responses don't carry `trace_id`. **Why it's tempting:** error handlers are added later and skip the middleware. **What to do instead:** the error handler must include `trace_id` in its log entry (Step 8 verifies this). Debugging production failures requires tracing the error, not just the success.
