# ascent-ai

AI applications that earn their place, for any repository whose own code calls a model: an assistant, a triage or drafting service, a retrieval-backed Q&A, an agent that acts through tools. It helps a team choose the least autonomy that does the job, and then checks, with evidence, that what they built matches what they declared:
- the design: a value baseline and a target, models named in one place with a fallback, autonomy, tools and limits that match the code, irreversible tools behind a person's approval, prompts covered by evals, an off switch
- the evidence: a golden set with typical, edge, attack and regression slices, eval and retrieval results that are fresh and meet their targets, the attack slice held to its own target
- the running safeguards: tracing, a capture policy, a gateway with a budget and rate limits, a cost-per-task alert

Every severity follows the application's AI risk tier (`ascent-governance`'s record): a small internal tool is held to a lighter standard than an agent that issues refunds, and a few rules never change. A repository can hold several AI applications; each has its own record, results and findings.

It checks evidence only. It never runs a model, an eval, a red team or a network call: those run from a runbook the operator runs, which writes the result files the checks read ([ADR-031](../../docs/framework/DECISIONS/ADR-031-ascent-ai-and-the-ai-lifecycle.md)).

```
/plugin marketplace add lloydbrian/lloydbriantech-ascent
/plugin install ascent-ai@lloydbriantech-ascent
```

Ask "should this be an agent?" or "design the AI for this" (`ai-design`), or "review our AI" (`ai-review`).

## What's inside

| Part | Kind | What it does |
|---|---|---|
| `ai-design` | skill | recommends a single prompt, a fixed workflow or an agent, the tools, limits, model and eval plan; drafts the design record, the `ai:` contract section and an ADR, written only after approval |
| `ai-review` | skill, entry point | rates each AI application strong, moderate or weak, by lifecycle stage, from the three checkers plus reading |
| `ai-design-check` | skill | the declarations against the code (AI-V, AI-M, AI-A, AI-P, AI-K, AI-F) |
| `ai-evidence-check` | skill | the result files against the targets (AI-G, AI-E, AI-R, AI-L) |
| `ai-runtime-check` | skill | the running safeguards (AI-O, AI-C) |
| `ai-reviewer` | agent | read-only provider for the delivery loop's AI behavior lens |
| `detect-ai.sh` | script | finds the AI code, the vector stores and gateways, and which application each piece belongs to |
| `check-ai-design.sh`, `check-ai-evidence.sh`, `check-ai-runtime.sh` | scripts | the checks, one application at a time, at no token cost in a project's own CI |
| `references/` | references | the rule table, the contract template, the design record template, the evidence formats, the design guide |

## What counts as an AI application

A model SDK in a manifest or an import (Python `openai`, `anthropic`, `langgraph`, `langchain`, `llama-index`, `litellm`, `google-genai`, `boto3` with `bedrock-runtime`; TypeScript `openai`, `@anthropic-ai/sdk`, `@anthropic-ai/claude-agent-sdk`, `@langchain/*`, the Vercel AI SDK `ai`), a `prompts/` folder that holds more than code, a `tests/evals/` folder, or an `ai:` section in the contract. A manifest, test code, prompts or evals outside every application's root belong to the one application below them (a src layout), and to none when several share them. A vector store with no model is retrieval, not an AI application, until the contract declares one. Claude Code skills, plugins and subagents are not AI applications here.

## The rules

[references/ai-rules.md](references/ai-rules.md) lists every rule (AI-V1–V2, AI-M1–M3, AI-A1–A5, AI-P1, AI-K1, AI-F1, AI-G1, AI-E1–E5, AI-R1–R2, AI-L1–L2, AI-O1–O2, AI-C1–C3), its base severity at tier 3 and whether it is fixed.

## What it leaves to other plugins

AI safety by design and red-team results: `ascent-security`. Provider keys and pinned packages: `ascent-security`. The tier: `ascent-governance`. Rollout and rollback, and a runbook's structure: `ascent-ops`. Ordinary tests: `ascent-quality`. Hosting cost: `ascent-architecture`. Code quality: the delivery loop's Code review lens.
