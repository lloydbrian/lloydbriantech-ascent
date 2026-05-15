# external-services-integration

> Pattern guidance for integrating external services (Anthropic, OpenAI, AWS, Stripe, Twilio, etc.). [PRINCIPLES.md §5](../../../docs/framework/PRINCIPLES.md#5-env-discipline) is authoritative for the secrets aspect.

This module defines the **pattern every external service integration follows**. Specific vendors are not covered here — vendor-specific guidance (prompt caching for Anthropic, presigned URLs for S3, webhook signing for Stripe) lives in the relevant role module. AI providers: `role-ai-engineer.md` (lands in Chunk 5 of Phase 1). AWS services: `role-devops.md`. Auth providers and rotation: `role-cybersecurity.md`.

## The pattern

Every external service integration ships with:

1. **A single client wrapper** — one module per service that owns all network egress to that service
2. **Retry with exponential backoff and jitter** — `1s, 2s, 4s, 8s` capped at `30s`, randomized ±20%
3. **Secrets via environment** — never embedded, never logged; per [ENV-DISCIPLINE.md](ENV-DISCIPLINE.md)
4. **Observability hooks** — every call traced, every error counted, every latency histogrammed
5. **A fallback path** — what the application does when the service is unavailable; never crash
6. **Cost-posture awareness** — every paid service tracked with a per-call cost estimate logged

## The client wrapper

One module, one service. Convention: `backend/services/<vendor>/client.<ext>` where `<vendor>` is a kebab-case slug (e.g., `anthropic`, `aws-s3`, `stripe`).

Inside the wrapper:

- A typed interface for the operations the application uses
- The vendor's SDK or HTTP client as the dependency
- The retry policy and timeout configuration
- Secrets-from-env loading at construction time
- Observability hooks wrapping every operation

Outside the wrapper:

- The application talks to the typed interface, never to the SDK directly
- Tests stub the typed interface, never the SDK
- Replacing the vendor (or adding a second) is a wrapper-internal change

The wrapper is the boundary. Code that imports `Anthropic` from `@anthropic-ai/sdk` outside `backend/services/anthropic/` is a layering violation.

## Retry policy

| Error class | Action |
|---|---|
| 5xx transient | Retry with exponential backoff |
| 429 rate limit | Honor `Retry-After` header if present; otherwise backoff |
| 4xx client error (not 429) | Do not retry; surface as application error |
| Network timeout | Retry once if request is idempotent; surface otherwise |
| Auth failure (401/403) | Do not retry; surface immediately as configuration error |

Retries are bounded — typically 3 attempts. Beyond that, the service is treated as unavailable and the fallback path engages.

**Idempotency matters.** Retrying a non-idempotent `POST` (a charge, a notification, an order) can produce duplicate side effects. The wrapper either:
- Refuses to retry non-idempotent operations
- Uses the vendor's idempotency key feature (Stripe `Idempotency-Key`, etc.) and lets the vendor de-dupe

## Secrets

Per ENV-DISCIPLINE.md, every external-service secret comes from environment variables, never from a `.env` baked into production images. The convention is `<PROJECT_SLUG_UPPER>_<VENDOR>_<PURPOSE>`:

```
LAWN_CARE_APP_ANTHROPIC_API_KEY=
LAWN_CARE_APP_STRIPE_SECRET_KEY=
LAWN_CARE_APP_STRIPE_WEBHOOK_SECRET=
LAWN_CARE_APP_AWS_REGION=
```

Empty in `.env.example`. Populated at runtime from the environment. Never logged. Never returned in API responses. Rotated per the cybersecurity role's secret-rotation cadence.

## Observability hooks

Every external call gets:

- **A log entry** on start: `event: external_service_call.start`, vendor, operation, request_id
- **A log entry** on completion: `event: external_service_call.complete`, outcome, latency_ms
- **A metric increment** on `external_service_calls_total{service, outcome}`
- **A trace span** named `<vendor>.<operation>` with attributes for vendor, operation, attempt number, outcome
- **An error log** on failure with the exception class — never the raw exception message, which may contain secrets or sensitive data

The integration is observable end-to-end; debugging in production needs no special tools. The trace span lets an operator follow a user request from inbound HTTP through every external call and back.

## Fallback paths

When an external service is unavailable, the application's behavior depends on the operation's criticality:

| Criticality | Fallback |
|---|---|
| Critical (auth, payments) | Reject the user's request with a clear error; alert oncall |
| Important (AI completion) | Degrade gracefully — return a cached response if available, otherwise an informative error |
| Optional (analytics, telemetry) | Skip silently; queue for later if possible; never block the user |

The fallback path is defined at the architect-design stage (Stage 2 per [feature-lifecycle.md](feature-lifecycle.md)), not retrofitted after the first outage. "What does the app do when Stripe is down?" is a design question, not an oncall question.

## Cost posture

Every paid external call logs a per-call cost estimate:

```json
{
  "event": "external_service_call.complete",
  "vendor": "anthropic",
  "operation": "messages.create",
  "tokens_in": 1200,
  "tokens_out": 340,
  "cost_estimate_usd": 0.0042
}
```

Aggregated cost is visible in dashboards. Budget alerts fire before bills land. The `ascent-cost-posture` skill (lands in scaffolded projects) reports the daily cost surface across all paid integrations.

## Anti-patterns

- **SDK directly in route handlers.** Wrap it. The handler should never `import { Anthropic } from '@anthropic-ai/sdk'`.
- **Silent retries that loop forever.** Retries must be bounded — three attempts is plenty.
- **Failure modes the architect didn't design.** If the answer to "what does the app do when Stripe is down?" is "I'm not sure," that's a Stage 2 design gap.
- **Retrying non-idempotent operations.** Retrying `POST /charge` produces double charges. Either refuse to retry or use idempotency keys.
- **Logging the request body.** Almost always contains PII or secrets. Log identifiers, not contents.
- **Hardcoded retry limits scattered across the codebase.** Centralize the retry policy in the wrapper; don't scatter `for attempt in range(3)` loops through application code.

## What this doc doesn't cover

Vendor-specific patterns — prompt caching for Anthropic, presigned URLs for S3, webhook signing for Stripe, idempotency-key formats — belong to the relevant role module:

- AI providers (Anthropic, OpenAI, etc.) → `role-ai-engineer.md` (Chunk 5)
- AWS services → `role-devops.md` (Chunk 5)
- Auth providers, secret rotation cadence → `role-cybersecurity.md` (Chunk 5)

This module's pattern is the floor every integration meets. Role modules add the vendor-specific ceiling.
