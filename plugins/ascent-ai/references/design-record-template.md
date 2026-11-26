# AI design record: <application>

What the team built, for one AI application, in five marked tables that `check-ai-design.sh` and `check-ai-runtime.sh` hold to the code. `ai-design` drafts it, and writes it only after the operator approves; people then edit it like any document. Its path is the application's `design_record` in the contract (`<root>/docs/ai/design.md` by default). Every path in it is relative to the repository root. Each table has one row per field, in any order; a field's name may be written with spaces or underscores.

## Application

`autonomy` is the least that does the job: `prompt` (one model call, no tools), `workflow` (steps known in advance: a chain, a router, parallel calls) or `agent` (the model picks its own next step, only when the steps cannot be known in advance). The baseline is how the work is measured today, before the AI; the target is what it must reach to be worth keeping (AI-V1).

<!-- ai-design:application:start -->
| Field | Value |
|---|---|
| name | <application> |
| autonomy | <prompt, workflow or agent> |
| baseline metric | <what is measured today, in words> |
| baseline value | <the value today> |
| measured on | <YYYY-MM-DD> |
| target value | <the value the AI must reach> |
<!-- ai-design:application:end -->

## Model

`defined in` lists the only files that may name a model (AI-M1), separated by commas. `gateway` is `litellm`, `portkey` or `none` (AI-C1). `cost per task alert` is the cost of one task that raises an alert (AI-C3).

<!-- ai-design:model:start -->
| Field | Value |
|---|---|
| primary | <model id> |
| fallback | <model id> |
| defined in | <file, file> |
| gateway | <litellm, portkey or none> |
| trace store | <where model calls are traced> |
| cost per task alert | <amount and unit> |
<!-- ai-design:model:end -->

## Tools

One row per tool the model can call; none for a `prompt`. A tool that cannot be undone, costs money or acts outside the system is `reversible: no` (a tool that only reads, even outside, is `yes`): it needs `approval required: yes` and a `limit enforced in` file whose code names the tool and enforces its limit (AI-A3).

<!-- ai-design:tools:start -->
| Name | Reversible | Approval required | Limit enforced in |
|---|---|---|---|
| <tool name> | <yes or no> | <yes or no> | <file> |
<!-- ai-design:tools:end -->

## Limits

The most a `workflow` or an `agent` may do on one task (AI-A4).

<!-- ai-design:limits:start -->
| Field | Value |
|---|---|
| max steps | <number> |
| max tokens | <number> |
| max seconds | <number> |
<!-- ai-design:limits:end -->

## Off switch

A flag that turns the AI off without a deploy, and the file that reads it (AI-K1).

<!-- ai-design:off-switch:start -->
| Field | Value |
|---|---|
| flag | <flag name> |
| read in | <file> |
<!-- ai-design:off-switch:end -->
