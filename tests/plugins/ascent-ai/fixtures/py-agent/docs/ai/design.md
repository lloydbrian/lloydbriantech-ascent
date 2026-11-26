# AI design record: support-assistant

What the team built, in the tables `ascent-ai` checks against the code (references/design-record-template.md). Paths are relative to the repository root.

<!-- ai-design:application:start -->
| Field | Value |
|---|---|
| name | support-assistant |
| autonomy | agent |
| baseline metric | median minutes to first reply |
| baseline value | 14 |
| measured on | 2026-10-01 |
| target value | 9 |
<!-- ai-design:application:end -->

<!-- ai-design:model:start -->
| Field | Value |
|---|---|
| primary | gpt-4o-mini |
| fallback | gpt-4o |
| defined in | agent/config.py |
| gateway | litellm |
| trace store | opentelemetry |
| cost per task alert | 0.05 USD a ticket |
<!-- ai-design:model:end -->

<!-- ai-design:tools:start -->
| Name | Reversible | Approval required | Limit enforced in |
|---|---|---|---|
| tag_ticket | yes | no | |
| issue_refund | no | yes | agent/refund.py |
<!-- ai-design:tools:end -->

<!-- ai-design:limits:start -->
| Field | Value |
|---|---|
| max steps | 8 |
| max tokens | 4000 |
| max seconds | 60 |
<!-- ai-design:limits:end -->

<!-- ai-design:off-switch:start -->
| Field | Value |
|---|---|
| flag | SUPPORT_AI_ENABLED |
| read in | agent/main.py |
<!-- ai-design:off-switch:end -->
