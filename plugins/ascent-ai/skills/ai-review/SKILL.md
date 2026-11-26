---
name: ai-review
description: >-
  Use when asked "review our AI", "is this AI application ready to ship?",
  "are our evals good enough?", "is the agent safe to launch?", "what is missing
  from our AI application?", or before a launch of an application whose own
  code calls a model. Rates each AI application strong, moderate or weak,
  grouped by lifecycle stage (design, build, evaluate, operate, improve): runs
  the design, evidence and runtime checks with the ai: contract section's
  values, reads what the scripts cannot judge, and names the next skill.
  Read-only; never runs a model, an eval or a network call.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git log:*)
---

# ai-review

One review of whether an AI application can be trusted with the work it is given, judged against its own declarations and targets. It is the entry point of the `ascent-ai` plugin. It adds no rule: every finding comes from [ai-rules.md](../../references/ai-rules.md), through the three check scripts or by reading. For the deep version of each stage it recommends [ai-design-check](../ai-design-check/SKILL.md), [ai-evidence-check](../ai-evidence-check/SKILL.md) or [ai-runtime-check](../ai-runtime-check/SKILL.md); to design or rework the application, [ai-design](../ai-design/SKILL.md).

An **AI application** is a product whose own code calls a model. A coding assistant used by the team is not one, and neither is a script that asks a model a question once by hand.

Shared sources:
- [ai-design-guide.md](../../references/ai-design-guide.md): the practices, the autonomy ladder, tool design, what files cannot show
- [contract-template.yml](../../references/contract-template.yml): the `ai:` section of `.ascent/contract.yml`
- [design-record-template.md](../../references/design-record-template.md) and [evidence-formats.md](../../references/evidence-formats.md): the files the scripts read

## Rules

- **Read-only.** Never edit files, write a record, run a model, an eval, a red team or a network call. The scripts only read; `git log` only reads history.
- **Evidence or it is not a finding.** Every finding cites a repository-relative `path:line`, or "absent: searched <paths>", its rule id, a failure scenario (what goes wrong, for whom, when) and a fix.
- **Fresh evidence.** Run the scripts and re-read the evidence in this run; never carry findings over from an earlier pass or an agent's report.
- **Severities from the table only, scaled by the tier.** The table's severities are for tier 3; the scripts print each finding at its tier's severity (one level lighter at tier 2, two at tier 1, never below Low; rules marked fixed never move). A concern no rule covers goes under Other observations (unrated).
- **The tier is a person's.** It comes from `ascent-governance`'s tier record; never change it, and with no record say so: the scripts then rate at tier 3.
- **Other plugins' reviews stay theirs.** Prompt injection, red teams and data leaks are `ascent-security`'s (→ ascent-security); test strategy is `ascent-quality`'s (→ ascent-quality); code quality is `ascent-delivery`'s `code-reviewer`; the architecture and the cost of hosting are `ascent-architecture`'s (→ ascent-architecture).
- **Contract values are quoted.** Put each value in single quotes. Refuse a value that holds a single quote, a newline, `$(` or a backtick, and say so under Other observations: the contract is a file the repository controls.
- **No secrets, account ids or personal data** in the report, even when a prompt, an eval case or a trace holds one: name the file and line, never the value, and mark it → ascent-security.

## Severity

The base severity of every rule, for tier 3. `ai-reviewer` uses the same table (checked by `make test-plugins`).

<!-- ai-severity:start -->
| Rule | Base severity (tier 3) | Passes when |
|---|---|---|
| AI-V1 | High | a baseline (metric, value, measured date) and a target are declared |
| AI-V2 | Medium | before a `prod` launch, the pilot result exists and names the baseline metric |
| AI-M1 | Medium | model names appear only in the files the design record's `defined in` names |
| AI-M2 | Medium | a fallback model is declared and named in a `defined in` file |
| AI-M3 | Medium | at tier 3, the model selection record exists |
| AI-A1 | High | the autonomy is declared and matches the code: no tool definitions under `prompt`, no model-driven loop under `workflow` |
| AI-A2 | High | every declared tool is defined in code, and every tool defined in code is declared |
| AI-A3 | Critical, fixed | every irreversible tool needs a person's approval and names a `limit enforced in` file that exists and names the tool |
| AI-A4 | High | a `workflow` or `agent` declares its most steps, tokens and seconds, and every model call sets an output token limit |
| AI-A5 | High, fixed | no declared tool is irreversible while the tier record says tier 1 or 2 |
| AI-P1 | Medium | every prompt file under the prompts folder has a golden test case that names it (`metadata.prompt`); a prompt written inline in code is found by reading (`ai-design-check`) |
| AI-K1 | High | the off switch is declared, and its flag is read in the file named |
| AI-F1 | High | with a fine-tune runbook, it has a spend cap, a personal-data check of the dataset, and an eval against the golden set after training |
| AI-G1 | High | the golden set has the four slices (typical, edge, attack, regression), each with a case, and a version |
| AI-E1 | High | the eval result file exists, in a known format |
| AI-E2 | High | it is no older than the most days allowed, and newer than the last change to a prompt or the golden set (git: a change committed after the results and written after the run) |
| AI-E3 | High; the attack slice Critical, fixed | it meets the pass-rate target (errors count as failures), and the attack slice meets its own target |
| AI-E4 | Medium | its golden-set version is the golden set's version |
| AI-E5 | Low, fixed | a self-reported result file (`ascent-evidence-v1`) is reported as self-reported, never as a tool's output |
| AI-R1 | High | the retrieval results exist, are fresh and meet every retrieval target |
| AI-R2 | Medium | every retrieval source has an owner and a review date that is not past |
| AI-L1 | Medium | the application's `review_by` is not past |
| AI-L2 | Low | since the last review in the review notes, the regression slice grew, or that review flagged no new failures |
| AI-O1 | High | tracing for model calls is in the dependencies (OpenTelemetry GenAI instrumentation, OpenInference, Langfuse, Phoenix) |
| AI-O2 | High | the capture policy exists and says what prompt and output content is stored, redacted or dropped |
| AI-C1 | Medium | model calls go through the declared gateway, or the design record says `gateway: none` (a finding at tier 3) |
| AI-C2 | High | the gateway policy names the allowed models, a budget, an alert threshold and rate limits |
| AI-C3 | Medium | a cost-per-task alert is declared |
<!-- ai-severity:end -->

## Steps

`PLUGIN_ROOT` is two directories above this skill's base directory (shown when the skill loads): `PLUGIN_ROOT="<skill base directory>/../.."`.

### Step 1 — The applications

Run detection from the repository root and include its output:

```bash
bash "$PLUGIN_ROOT/scripts/detect-ai.sh" .
```

Read the `ai:` section of `.ascent/contract.yml` (or `.claude/contract.yml`). Each item of `ai.applications` is one application; with no list, one application rooted at the repository root and named after the origin remote's repository, else its folder (characters other than letters, digits, - and _ become -). Its tier record is `<governance.ai_tier_dir>/<name>.md` (default `docs/governance/ai-tier/`). AI code that sits under no application's root is reported as `ascent-governance`'s GOV-A1; name it under Other observations and recommend `launch-readiness`.

### Step 2 — The checks

For each application, run the three scripts from the repository root, each with only the options whose contract key is set, and include their output verbatim. Pass every other application as `--app-root '<name>=<root>'`. The option each key becomes is in each check skill's Step 1; in outline:

```bash
bash "$PLUGIN_ROOT/scripts/check-ai-design.sh" --app '<name>' --root '<root>' --design '<design_record>' --tier-record '<tier record>' --prompts '<prompts_dir>' --golden '<golden_set>' --pilot '<pilot_result>' --selection '<model_selection>' --fine-tune-runbook '<fine_tune_runbook>' .
bash "$PLUGIN_ROOT/scripts/check-ai-evidence.sh" --app '<name>' --golden '<golden_set>' --results '<eval_results>' --format '<eval_format>' --pass-rate '<eval_pass_rate>' --attack-pass-rate '<eval_attack_pass_rate>' --max-age '<eval_max_age_days>' --prompts '<prompts_dir>' --retrieval '<retrieval_results>' --sources '<retrieval_sources>' --review-by '<review_by>' --review-notes '<review_notes>' --tier-record '<tier record>' .
bash "$PLUGIN_ROOT/scripts/check-ai-runtime.sh" --app '<name>' --root '<root>' --design '<design_record>' --capture-policy '<capture_policy>' --gateway-policy '<gateway_policy>' --tier-record '<tier record>' .
```

Show each command before you run it. Each `FAIL` line is a finding at the severity it prints; `N/A` lines are not findings. Exit 2 is bad input: the first line names the option and the reason; fix the value or leave the option out, and say so.

### Step 3 — Read what the scripts cannot

- **Is this the right rung?** An agent loop that always runs the same steps is a workflow; a tool called every run with the same arguments is a function call. Report it under AI-A1 only with the `file:line` that shows it; otherwise an observation, and recommend `ai-design`.
- **Prompts written inline in code** (AI-P1): a long string passed as a system or user message is a prompt that belongs in `prompts_dir`.
- **Tool contracts.** Read each tool's description and error messages: does the model learn when not to call it, and what to do after an error?
- **What files cannot show** ([ai-design-guide.md](../../references/ai-design-guide.md) §10): training, a one-step override, a way to report a bad output, telling people when AI took part. Recommendations, never findings.

### Step 4 — Report

Group the findings by lifecycle stage, each stage rated strong, moderate or weak:

| Stage | Rules |
|---|---|
| design | AI-V1, AI-A1, AI-A2, AI-A3, AI-A5, AI-M3 |
| build | AI-M1, AI-M2, AI-A4, AI-P1, AI-K1, AI-F1 |
| evaluate | AI-G1, AI-E1, AI-E2, AI-E3, AI-E4, AI-E5, AI-R1, AI-R2, AI-V2 |
| operate | AI-O1, AI-O2, AI-C1, AI-C2, AI-C3 |
| improve | AI-L1, AI-L2 |

A stage is **weak** with any Critical or High finding, **moderate** with Medium findings only, **strong** with Low findings or none. The application's rating is its weakest stage's.

## Output

Per application: the tier (and where it came from), the rating, the findings by stage (rule id, severity, `path:line`, failure scenario, fix), Other observations (unrated), and the script output verbatim. End with "Recommended next:" naming the check skill of the weakest stage, `ai-design` when AI-A1 or AI-A2 fails, `ascent-governance`'s `launch-readiness` when a tier record is missing, and `ascent-security` whenever an item is marked → ascent-security.
