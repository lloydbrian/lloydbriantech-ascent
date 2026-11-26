---
name: ai-runtime-check
description: >-
  Use when asked "can we see what the model was asked and answered?", "what do
  our traces keep?", "do our model calls go through the gateway?", "is there a
  budget on model spend?", "will we hear about a runaway agent?", or when
  ai-review flags the operate stage. Holds one AI application's running
  safeguards to what it declares: tracing of model calls in the dependencies,
  a capture policy that says what is stored, redacted and dropped, model
  clients that go through the declared gateway, a gateway policy with allowed
  models, a budget, an alert and rate limits, and a cost-per-task alert
  (AI-O1–O2, AI-C1–C3). Read-only; never runs a model or a network call.
version: 0.1.0
allowed-tools: Read, Grep, Glob
---

# ai-runtime-check

The deep operate check behind [ai-review](../ai-review/SKILL.md). It shares that skill's rules, severity table and contract. When a model misbehaves in production, someone needs to see what it was asked, stop the spend and know before the bill does: this skill checks that the files say they can.

Sources: [ai-rules.md](../../references/ai-rules.md), [evidence-formats.md](../../references/evidence-formats.md) (the capture policy), [ai-design-guide.md](../../references/ai-design-guide.md) §8.

The rules, each in [ai-rules.md](../../references/ai-rules.md): AI-O1, AI-O2, AI-C1, AI-C2, AI-C3.

## Rules

- All `ai-review` rules apply: read-only; `path:line` evidence; fresh evidence; severities from the table, scaled by the tier; contract values quoted; no secrets or personal data.
- **Never call the gateway or a trace store.** What is configured is read from files; what is live is the operator's to show.
- **Keys and pins are `ascent-security`'s.** A provider key in code or configuration, or a gateway image or package that is not pinned, goes under Other observations marked → ascent-security, never as a finding here.

## Steps

`PLUGIN_ROOT` is two directories above this skill's base directory: `PLUGIN_ROOT="<skill base directory>/../.."`.

### Step 1 — The script

Run it from the repository root for the application, with only the options whose contract key is set, and include its output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-ai-runtime.sh" --app '<name>' --root '<root>' --design '<design_record>' --capture-policy '<capture_policy>' --gateway-policy '<gateway_policy>' --tier-record '<tier record>' --app-root '<other name>=<other root>' .
```

The tier record is `<governance.ai_tier_dir>/<name>.md`; repeat `--app-root` once for each other application. Each `FAIL` line is a finding at the severity it prints.

### Step 2 — Read what the script cannot

- **AI-O1, tracing wired.** A tracing package in the dependencies is not tracing turned on: find where it is initialised and cite the `path:line`, or say it was not found.
- **AI-O2, the policy kept.** Read the tracing setup against the capture policy: does a redaction the policy promises happen in code?
- **AI-C1, the base URL.** A client whose base URL comes from an environment variable goes through the gateway only when that variable names it in every environment: say what the configuration shows.
- **AI-C2, the numbers.** Read the budget, the alert and the rate limits, and say whether a loop at the most steps the design record allows could spend the budget before the alert. A LiteLLM `max_budget` is enforced only with a database configured (otherwise it fails open), and `alerting_threshold` is a hung-request timeout, not a spend alert: say which the file shows.

### Step 3 — Report

The `ai-review` Step 4 format, limited to these rules: the findings with rule ids, Other observations, and the script output verbatim. End with "Recommended next:" naming `ai-review`, and `ascent-security` whenever an item is marked → ascent-security.
