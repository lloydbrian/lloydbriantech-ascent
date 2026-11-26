---
name: ai-design
description: >-
  Use when asked "should this be an agent?", "design the AI for this", "how
  much autonomy should this have?", "which model should we use?", "what tools
  should the model get?", or before building or reworking an application whose
  own code calls a model. Recommends the least autonomy that does the job (a
  single prompt, a fixed workflow or an agent), the tools with what each can
  undo and who approves it, the limits, the model and its fallback, the eval
  plan and the off switch, from the work and its baseline or from the code that
  exists. Drafts the AI design record, the ai: contract section and an ADR, and
  writes them only after the operator approves.
version: 0.1.0
allowed-tools: Read, Grep, Glob
---

# ai-design

Helps a team decide what an AI application should be before they build it, or what an existing one should have been. It finds no findings; [ai-review](../ai-review/SKILL.md) rates what was built. Its source is [ai-design-guide.md](../../references/ai-design-guide.md); its outputs follow [design-record-template.md](../../references/design-record-template.md) and [contract-template.yml](../../references/contract-template.yml).

The plugin's read-only scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads); below, `PLUGIN_ROOT` means that directory: `PLUGIN_ROOT="<skill base directory>/../.."`.

## Rules

- **Propose, don't write.** The design record, the `ai:` section and the ADR are tracked files. Show each draft in full. Write them only after the operator approves, and only the files approved. Never commit.
- **The least autonomy that does the job.** Recommend the lowest rung that fits, and say why each lower rung does or does not fit. An agent only when the steps cannot be known in advance.
- **Never run a model, an eval or a network call.** Model choice comes from the operator's constraints and published documentation they point to; an eval or a bake-off runs from a runbook the operator runs.
- **The tier is a person's.** Say which tier the reasons point to (ascent-governance's tier record), and leave the decision and the signature to a person.
- **No credentials, account ids or personal data** in any draft.

## Steps

### Step 1 — Which situation

Run detection from the repository root and include its output:

```bash
bash "$PLUGIN_ROOT/scripts/detect-ai.sh" .
```

The skill pre-approves only reading; running the script asks the operator first, and it only reads.

No `ai` line: a new use case (Step 2). An `ai` line: an existing application; read the code first (Step 3). Several applications: work on the one the operator names.

### Step 2 — A new use case: the work, one question at a time

Ask, one question at a time, waiting for each answer: what the work is and who does it today; how it is measured now, and the value on a date (the baseline); how many cases a day; whether a result can be checked, and by whom; which actions cannot be undone, cost money or leave the system; what data the AI would see. Then go to Step 4.

### Step 3 — An existing application: read the code first

Read the code first: the model calls, the tool definitions, the loops, the limits, the prompts and where the model is named. Look for loops built by hand too: a step graph or state machine where a step that runs tools routes back to the model call is an agent loop, whatever it is called. Notebooks (`.ipynb`) count; the scripts do not read them, so read their code cells. Draft the declarations from what is there, citing `file:line`: the design record describes the application **as built**, and what it should become goes in the recommendation and the ADR. Then say where the code uses more autonomy than the job needs: an agent loop that always runs the same steps (a workflow), a tool the model calls every time with the same arguments (a function call in code), a decision a rule in code could make.

The code cannot say what the work is worth. Then ask the Step 2 questions it does not answer, one at a time: how the work is measured now and the value on a date (the baseline), how many cases a day, and whether a result can be checked, and by whom. Never fill the baseline from the code.

### Step 4 — The recommendation

Give the ladder, lowest first, and say why each lower rung does or does not fit:

1. **a single prompt**: one call, no tools;
2. **a fixed workflow**: a chain, a router or parallel steps, the order in code;
3. **an agent**: the model picks its next step; an agent only when the steps cannot be known in advance, and every irreversible action has a limit in code and a person's approval.

Then propose, each with a reason: the tools (name, reversible or not, approval required, the file that will enforce its limit); the limits (steps, tokens, seconds, an output token limit on every call); the model, where it is named in code, and its fallback; the eval plan (the golden set's four slices, the pass-rate and attack targets, the most days old); the off switch; the gateway; what traces store, redact and drop; and the tier the reasons point to.

### Step 5 — Drafts, written after approval

Show three drafts in full: the AI design record (the five marked tables of the template), the `ai:` section item for this application, and an ADR in the project's ADR format (if `engineering:architecture` is installed, use it to format the ADR). The ADR records the recommendation, the rungs not chosen and why, and, as recommendations, what files cannot show: training the people who check the output, a one-step override, a way for users to report a bad output, telling people when AI took part in a decision about them. Write them only after the operator approves.

## Output

The situation and the detection output; the recommendation with the ladder; the drafts; what was written, if anything. End with "Recommended next:" naming `ai-review` once the application is built, and `ascent-governance`'s `launch-readiness` for the tier record.
