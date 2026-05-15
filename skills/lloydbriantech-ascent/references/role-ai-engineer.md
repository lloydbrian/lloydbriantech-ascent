# role-ai-engineer

> The AI engineer role. [ADR-001](../../../docs/framework/DECISIONS/ADR-001-single-parent-skill.md) establishes the nine-role model; [external-services-integration.md](external-services-integration.md) is the pattern this role specializes for AI providers.

## What this role owns

The AI engineer owns the AI provider integration end-to-end: prompts, model abstraction, eval discipline, agentic patterns, and safety guardrails. external-services-integration.md is the *floor* every integration meets; this module is the *ceiling* for AI-specific concerns.

Specific responsibilities:

- **Prompt engineering** — the prompts themselves, their structure, their evolution
- **Eval harnesses** — automated validation of prompt behavior under representative inputs
- **Model abstraction** — the AI provider client wrapper, isolating vendor specifics
- **Agentic patterns** — multi-step reasoning, tool use, conversation state
- **Safety guardrails** — refusal-handling, prompt injection defenses, output validation
- **Cost posture for AI calls** — token budgets, caching, model-tier selection

## When this role engages

| Trigger | Engagement |
|---|---|
| New project includes AI | Initial prompt design, model abstraction, eval scaffolding at Stage 2 |
| Prompt or model change (per [feature-lifecycle.md](feature-lifecycle.md) Stage 2 trigger) | Design the prompt change; pair with [role-developer.md](role-developer.md) on the wrapper |
| New agentic capability | Design the task module's prompt + tools + safety story |
| Eval regression | Investigate which input class regressed; either fix prompt or accept the trade-off |
| AI provider migration | Author the model-abstraction changes; ensure evals pass on the new provider |
| Cost spike | Profile; reduce tokens, switch tier, or restructure the call pattern |

## Key practices

### Prompt engineering

Prompts are code. They live in version control. They evolve through PRs. They have tests (evals).

Structure: a prompt has a clear role declaration ("You are X"), explicit instructions, structured examples when needed, and an output-format constraint. Vague prompts produce vague outputs.

Examples in prompts use the same shape as expected real input. A prompt that says "respond in JSON" without an example invites format drift; a prompt with one example of the exact JSON shape stays on rails.

### Eval harnesses

Every prompt change ships with an eval scenario validating the change. Evals are not "the prompt worked once" — they're representative input sets with expected output assertions. The `role-tester.md` pairs in for eval rigor (acceptance criteria → eval traceability).

Eval scenarios live in `tests/evals/` per the architect's skeleton. The `ascent-ai-evals` skill (conditional, lands in AI-using scaffolded projects) automates the run.

### Model abstraction

The AI provider lives behind a typed client wrapper per external-services-integration.md. The wrapper exposes operations the application uses (`generate`, `embed`, `tool_call`), not the vendor's full API. Switching providers is a wrapper-internal change.

For projects under `lloydbriantech-ascent`'s stated AI provider (Anthropic), the wrapper uses `@anthropic-ai/sdk` — but only inside the wrapper. Application code talks to the wrapper's typed interface. This is the **explicit exception** to the rule that role modules don't name preferred tooling: CLAUDE.md names Anthropic as the framework's stated provider, so wrappers under this framework default to it.

Prompt caching, tool use, vision input — Anthropic-specific features — are wrapper internals. The wrapper exposes them through stable interfaces.

### Agentic patterns

When the project ships an agent, the AI engineer owns the orchestration shape:

- **Tool definitions** — what the agent can do, with typed schemas
- **Decision loops** — when to call a tool, when to respond, when to stop
- **State management** — conversation history, scratchpads, context windows
- **Termination** — explicit success / failure / human-handoff signals

Agent task modules live per `role-developer.md`'s convention; the AI engineer specifies prompts and tool schemas, the developer implements the orchestration code.

### Safety guardrails

Every AI integration has explicit safety properties:

- **Prompt injection defenses** — separation of trusted instructions and untrusted input; output validation against expected shape
- **Refusal handling** — when the model declines, the application has a fallback
- **PII handling** — what data flows to the model; what's redacted
- **Output validation** — structured outputs validated against schemas before downstream use

Safety isn't an audit phase; it's a design property. The cybersecurity role engages when auth, data egress, or compliance is touched (per `role-cybersecurity.md`).

### Cost posture

Every paid AI call logs token counts and a per-call cost estimate (per external-services-integration.md's cost-posture rule). The AI engineer tunes:

- **Model tier** — use the cheapest model that meets the eval bar
- **Prompt caching** — cache the long context; pay tokens only on the variable suffix
- **Output token budgets** — explicit `max_tokens` to bound generation
- **Call patterns** — avoid redundant calls; reuse outputs where possible

The `ascent-cost-posture` skill aggregates the daily AI spend; the AI engineer reads the dashboard weekly.

## Hand-offs

**Upstream (AI engineer receives from):**

- [role-architect.md](role-architect.md) when an AI-touching feature is designed
- [role-developer.md](role-developer.md) when wrapper or orchestration code surfaces design questions

**Downstream (AI engineer hands to):**

- `role-developer.md` — prompts, schemas, wrapper interface
- [role-tester.md](role-tester.md) — eval scenarios become part of the test discipline
- [role-cybersecurity.md](role-cybersecurity.md) — safety properties to verify

## Anti-patterns

- **Prompt drift without evals.** Editing prompts without running evals; regressions land silently.
- **SDK in application code.** `import { Anthropic } from '@anthropic-ai/sdk'` outside the wrapper. Layering violation.
- **Unbounded `max_tokens`.** Default-unlimited generation produces cost spikes on adversarial inputs.
- **No fallback on model unavailability.** AI provider 5xx becomes user-facing crash. Degrade gracefully per external-services-integration.md.
- **PII flowing to prompts unredacted.** "The model doesn't store it" doesn't help when the vendor's logs do. Redact at the application boundary.
- **Prompt injection ignored.** User input concatenated into instruction position. Use the vendor's structured-input features and validate output shape.

## What this role doesn't own

- **The wrapper's network mechanics.** Retry, timeout, secret loading — those are [role-developer.md](role-developer.md)'s implementation of external-services-integration.md's pattern. The AI engineer specifies *what the wrapper does*; the developer implements *how*.
- **Production AI infrastructure.** Self-hosted models, GPU provisioning — that's [role-devops.md](role-devops.md). For projects using external AI providers (the framework's default), this concern doesn't surface.
- **Training data and fine-tuning.** When applicable, those are co-owned with `role-data-engineer.md`; the AI engineer specifies dataset shape, data-engineer owns the data layer.

## Cross-references

- `external-services-integration.md` — the pattern AI integration specializes
- `feature-lifecycle.md` Stage 2 — when AI-touching changes engage this role
- The `ascent-ai-evals` skill — automated eval runs in AI-using scaffolded projects
- The `ascent-cost-posture` skill — AI spend visibility
