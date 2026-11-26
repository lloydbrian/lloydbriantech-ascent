---
name: ai-design-check
description: >-
  Use when asked "does the code match the AI design?", "are all our tools
  declared?", "which tools can the model call that cannot be undone?", "is the
  model named in one place?", "do we have an off switch?", "does every model
  call cap its tokens?", or when ai-review flags the design or build stage.
  Holds one AI application's declarations to its code: the baseline and target,
  the pilot, the model and its fallback, the autonomy, every tool with its
  approval and the code that limits it, the caps, the prompts, the off switch
  and fine-tuning (AI-V1–V2, AI-M1–M3, AI-A1–A5, AI-P1, AI-K1, AI-F1). Read-only;
  never runs a model.
version: 0.1.0
allowed-tools: Read, Grep, Glob
---

# ai-design-check

The deep design and build check behind [ai-review](../ai-review/SKILL.md). It shares that skill's rules, severity table and contract. A design record is a promise; this skill checks that the code keeps it.

Sources: [ai-rules.md](../../references/ai-rules.md), [design-record-template.md](../../references/design-record-template.md), [ai-design-guide.md](../../references/ai-design-guide.md) §2–§5.

The rules, each in [ai-rules.md](../../references/ai-rules.md): AI-V1, AI-V2, AI-M1, AI-M2, AI-M3, AI-A1, AI-A2, AI-A3, AI-A4, AI-A5, AI-P1, AI-K1, AI-F1.

## Rules

- All `ai-review` rules apply: read-only; `path:line` evidence; fresh evidence; severities from the table, scaled by the tier; contract values quoted; no secrets or personal data.
- **The code is the evidence, the record is the claim.** A tool the record declares and the code does not define, or the reverse, is AI-A2 whichever side is wrong; say which side to fix only with a reason.
- **A limit in a prompt is not a limit.** AI-A3 passes only on code that refuses the action: a check that raises, returns or asks a person.

## Steps

`PLUGIN_ROOT` is two directories above this skill's base directory: `PLUGIN_ROOT="<skill base directory>/../.."`.

### Step 1 — The script

Run it from the repository root for the application, with only the options whose contract key is set, and include its output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-ai-design.sh" --app '<name>' --root '<root>' --design '<design_record>' --tier-record '<tier record>' --prompts '<prompts_dir>' --golden '<golden_set>' --pilot '<pilot_result>' --selection '<model_selection>' --fine-tune-runbook '<fine_tune_runbook>' --env '<the environment asked about>' --app-root '<other name>=<other root>' .
```

The tier record is `<governance.ai_tier_dir>/<name>.md`. Repeat `--app-root` once for each other application; `--env prod` asks whether the application may launch to production (AI-V2). Each `FAIL` line is a finding at the severity it prints.

### Step 2 — Read what the script cannot

- **AI-A1, the rung.** The script sees tools and the loops of known frameworks and SDKs. It does not see a loop built by hand as a step graph or state machine (a tools step that routes back to the model call), or code in notebooks: read for them, and confirm a model-driven loop under `workflow` with its `path:line`. Read the loop: if it always calls the same steps in the same order, the job is a workflow; recommend `ai-design`.
- **AI-A2, tools defined another way.** A tool built from a list or a registry the script does not parse: read it, and clear or confirm the finding with the `path:line` that shows the tool.
- **AI-A3, the limit.** Open the `limit enforced in` file. Say what it checks (an amount, a count, an allow list, a person's approval) and whether every path to the tool passes through it.
- **AI-A4, caps set at runtime.** A token limit read from configuration clears the finding only with the `path:line` of the value.
- **AI-P1, inline prompts.** A long string passed as a system or user message in code is a prompt: name it, and recommend moving it into the prompts folder with a golden case.
- **AI-K1, the off switch.** Say what happens when the flag is off: an answer without AI, a clear message, or an error.

### Step 3 — Report

The `ai-review` Step 4 format, limited to these rules: the findings with rule ids, Other observations, and the script output verbatim. End with "Recommended next:" naming `ai-design` when AI-A1 or AI-A2 fails, and `ai-review` otherwise.
