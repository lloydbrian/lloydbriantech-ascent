# observability-contract

> What every scaffolded ASCENT service emits. [ARCHITECTURE.md Layer 2](../../../docs/framework/ARCHITECTURE.md#layer-2--parent-skill) lists this module as part of the skill's references tree.

Specific field and format defaults are below; a future ADR may refine these — the values here are the working standard until then.

## Logs

Every service emits structured JSON logs. Required fields:

| Field | Type | Example |
|---|---|---|
| `level` | string | `info`, `warn`, `error`, `debug` |
| `ts` | string (RFC3339) | `2026-05-15T08:42:11.123-04:00` |
| `trace_id` | string (W3C TraceContext) | `4bf92f3577b34da6a3ce929d0e0e4736` |
| `msg` | string | Human-readable event |
| `ctx` | object | Structured contextual data |

Optional but commonly present:

| Field | Type | Notes |
|---|---|---|
| `service` | string | Auto-populated from `PROJECT_SLUG` per [SLUG-CONVENTIONS.md](SLUG-CONVENTIONS.md) |
| `version` | string | Image tag or git SHA |
| `user_id` | string | Only if request is authenticated; never log PII raw |
| `err` | object | `{type, message, stack}` for error events; never raw exception |
| `event` | string | Lifecycle markers (`service.started`, `service.draining`) |

Anti-patterns:

- Plain-text log lines (`console.log("user did X")`) — not greppable, not structured, useless at scale
- Logging the request body — almost always contains PII or secrets
- `JSON.stringify` of complex objects without depth limit — log explosion

## Metrics

Prometheus-format metrics scraped from `/metrics`. The baseline catalog every service emits:

| Metric | Type | Labels | Purpose |
|---|---|---|---|
| `http_requests_total` | counter | `method`, `route`, `status` | Request volume |
| `http_request_duration_seconds` | histogram | `method`, `route` | Latency p50/p95/p99 |
| `http_errors_total` | counter | `method`, `route`, `error_class` | Error rate |
| `external_service_calls_total` | counter | `service`, `outcome` | External egress count |
| `queue_depth` | gauge | `queue_name` | Async work backlog (if applicable) |
| `process_uptime_seconds` | counter | (none) | Self-reported uptime |

Route labels are normalized — `/users/:id` not `/users/42`. Cardinality discipline is non-negotiable: a metric label with unbounded cardinality (e.g., `user_id`) is a memory leak in waiting.

## Traces

Distributed traces use W3C TraceContext. Required propagation:

- **Incoming requests:** extract `traceparent` and `tracestate` from headers
- **Outgoing requests** (HTTP, queue, RPC): inject the same headers into outbound calls
- **Spans:** one per route handler, one per external service call, one per significant unit of work

Span attributes share names with log `ctx` fields where overlap exists. Trace IDs propagate into log entries via the `trace_id` field, making a trace and its log entries cross-linkable.

## Health endpoints

Two endpoints, both unauthenticated, both fast (<10ms):

- `GET /healthz` — liveness. Returns 200 if the process is running. **Never** checks downstream dependencies.
- `GET /readyz` — readiness. Returns 200 if the service can accept traffic (DB connected, downstream healthy, warmup complete). Returns 503 otherwise.

`/healthz` is for the orchestrator's restart logic. `/readyz` is for the load balancer's traffic-routing logic. Conflating them produces flapping pods: a slow DB query trips readiness, the orchestrator restarts the pod, the new pod fails readiness too, the service oscillates.

Both endpoints emit a log entry on each call only at `debug` level — they're polled frequently and would otherwise drown out real events.

## Lifecycle events

The application emits explicit events at boundaries:

- `service.started` — after warmup, before first request
- `service.draining` — SIGTERM received, draining in-flight work
- `service.stopped` — process exit, last log line

These events carry the same fields as regular logs with `event` set explicitly. Operators search for them when investigating restart causes; the `service.draining` event in particular tells the operator a SIGTERM arrived rather than a crash.

## Log levels

| Level | Use for |
|---|---|
| `error` | Actual error conditions the application can't handle |
| `warn` | Recoverable issues (retry succeeded after backoff, rate limit hit) |
| `info` | Normal-operation events worth keeping for audit (request completed, lifecycle transitions) |
| `debug` | Diagnostic detail useful when investigating; off by default in production |

`info`-level for everything makes the level meaningless. Reserve each level for its purpose.

## Anti-patterns

- **Logging then re-raising.** Either log-and-handle or raise; never both, which double-counts errors in dashboards.
- **Metric labels with unbounded cardinality.** `user_id` as a metric label produces one time series per user — Prometheus explodes. Use logs for per-user diagnostics, metrics for aggregate.
- **Tracing only successful paths.** If error paths don't trace, debugging production failures becomes guesswork. Trace every span; record the error attribute on failure.
- **Health endpoints behind auth.** Orchestrators can't authenticate; the endpoint becomes useless.
- **Conflating `/healthz` and `/readyz`.** See the Health endpoints section.

## Implementation hooks

Each scaffolded service ships with:

- A structured-logger wrapper (level-aware, env-configurable)
- A metrics middleware on the HTTP layer
- A trace-propagation middleware
- `/healthz` and `/readyz` handlers as part of the route table
- Lifecycle-event emitters in the server startup/shutdown paths

These wrappers and middleware live in `backend/observability/` per [feature-lifecycle.md](feature-lifecycle.md) Stage 3 (developer implementation). The architect picks the specific logger/metrics/tracing libraries at Stage 2 (design) — this contract specifies what they emit, not which library produces them.

## The future ADR

The fields and metric catalog above are the working defaults. A future ADR will formalize them as the framework's binding observability contract once Phase 6 (starter repo generation) lands and real-world projects exercise the patterns. Until then, these defaults are the canonical source; deviations should be deliberate and recorded.
