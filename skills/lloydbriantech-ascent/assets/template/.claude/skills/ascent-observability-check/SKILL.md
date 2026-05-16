---
name: ascent-observability-check
description: >-
  Verifies that <<PROJECT_TITLE>>'s backend services emit observability
  data per the observability contract: structured JSON logs with the
  required fields, /healthz and /readyz endpoints, lifecycle events
  (service.started, service.draining, service.stopped), and trace-id
  propagation via W3C TraceContext.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-observability-check

Validates that <<PROJECT_TITLE>>'s services emit observability data per the observability contract. Checks log field presence, healthcheck endpoints, lifecycle events, and trace propagation — the baseline that makes production debugging possible without special tools.

## When this skill engages

- Before deploying to staging or production — "is this service observable?"
- After adding a new service or endpoint — "does it emit correctly?"
- As a component of [ascent-self-audit](../ascent-self-audit/SKILL.md)'s comprehensive check
- When debugging reveals missing trace correlation or log fields

## Inputs

- The backend source directory (defaults to `backend/`)
- Optional: specific service or endpoint to focus on

## Outputs

- A checklist report: each contract requirement marked PASS or FAIL
- For each FAIL: the specific gap, the file that should contain it, and what to add
- Categories: logs (field presence), health (endpoint existence), lifecycle (event emission), traces (propagation)

## Operational logic

The skill reads the backend source to validate: (1) the logger module emits the required fields (level, ts, trace_id, msg per the observability contract), (2) routes/health.js exists with /healthz (no DB check) and /readyz (DB + schema check), (3) server.js emits service.started, service.draining, and service.stopped lifecycle events, (4) middleware/request-id.js extracts or generates trace-id and propagates via headers. Each check is a file-read + pattern-match against expected code structures. The full pattern-matching heuristics for each check land in Phase 3.

## Examples

Examples land in Phase 3. Each example will show a service missing one contract element, the check's output, and the corrective code.

## Anti-patterns

The primary failure mode is **passing the check with placeholder implementations** — a logger that emits the right field names but hardcodes empty values, or a /readyz endpoint that always returns 200 without actually checking the database. The check should validate that the implementations are substantive, not just structurally present.
