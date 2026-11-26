# AI design record: ticket-router

<!-- ai-design:application:start -->
| Field | Value |
|---|---|
| name | ticket-router |
| autonomy | workflow |
| baseline metric | tickets misrouted per 100 |
| baseline value | 12 |
| measured on | 2026-09-15 |
| target value | 5 |
<!-- ai-design:application:end -->

<!-- ai-design:model:start -->
| Field | Value |
|---|---|
| primary | claude-haiku-5-5 |
| fallback | claude-sonnet-5-5 |
| defined in | src/config.ts |
| gateway | none |
| trace store | phoenix |
| cost per task alert | 0.01 USD a ticket |
<!-- ai-design:model:end -->

<!-- ai-design:tools:start -->
| Name | Reversible | Approval required | Limit enforced in |
|---|---|---|---|
<!-- ai-design:tools:end -->

<!-- ai-design:limits:start -->
| Field | Value |
|---|---|
| max steps | 2 |
| max tokens | 650 |
| max seconds | 20 |
<!-- ai-design:limits:end -->

<!-- ai-design:off-switch:start -->
| Field | Value |
|---|---|
| flag | ROUTER_AI_ENABLED |
| read in | src/index.ts |
<!-- ai-design:off-switch:end -->
