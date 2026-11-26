---
name: ai-evidence-check
description: >-
  Use when asked "are our evals current?", "do the eval results meet the
  target?", "does the golden set cover attacks?", "did we eval the prompt we
  ship?", "is the retrieval good enough?", "who owns our retrieval sources?",
  or when ai-review flags the evaluate or improve stage. Holds one AI
  application's result files to its targets: the golden set's four slices and
  version, the eval results' age, pass rate, attack slice and version, the
  retrieval results and sources, and the review date and notes (AI-G1, AI-E1–E5,
  AI-R1–R2, AI-L1–L2). Read-only; never runs a model, an eval or a network call.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git log:*)
---

# ai-evidence-check

The deep evaluate and improve check behind [ai-review](../ai-review/SKILL.md). It shares that skill's rules, severity table and contract. An eval that ran last quarter on last quarter's prompt proves nothing about today's: this skill checks that the evidence is about what ships.

Sources: [ai-rules.md](../../references/ai-rules.md), [evidence-formats.md](../../references/evidence-formats.md) (the golden set convention, Promptfoo results, `ascent-evidence-v1`, the sources and review tables), [ai-design-guide.md](../../references/ai-design-guide.md) §6–§9.

The rules, each in [ai-rules.md](../../references/ai-rules.md): AI-G1, AI-E1, AI-E2, AI-E3, AI-E4, AI-E5, AI-R1, AI-R2, AI-L1, AI-L2.

## Rules

- All `ai-review` rules apply: read-only; `path:line` evidence; fresh evidence; severities from the table, scaled by the tier; contract values quoted; no secrets or personal data.
- **Never run an eval.** A run calls a model and costs money. When fresh results would settle a question, write the command for the operator's runbook and read the result file they commit.
- **Self-reported is said.** An `ascent-evidence-v1` file is what the project wrote about a tool's run, not the tool's own output: report it as self-reported (AI-E5), every time.
- **Never print a case.** Golden cases and outputs may hold personal data or attack text: cite the file and the case id.

## Steps

`PLUGIN_ROOT` is two directories above this skill's base directory: `PLUGIN_ROOT="<skill base directory>/../.."`.

### Step 1 — The script

Run it from the repository root for the application, with only the options whose contract key is set, and include its output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-ai-evidence.sh" --app '<name>' --golden '<golden_set>' --results '<eval_results>' --format '<eval_format>' --pass-rate '<eval_pass_rate>' --attack-pass-rate '<eval_attack_pass_rate>' --max-age '<eval_max_age_days>' --prompts '<prompts_dir>' --retrieval '<retrieval_results>' --retrieval-target '<metric>=<value>' --sources '<retrieval_sources>' --review-by '<review_by>' --review-notes '<review_notes>' --tier-record '<tier record>' .
```

`retrieval_targets` holds `name=value` pairs separated by spaces: pass each as its own `--retrieval-target`. The tier record is `<governance.ai_tier_dir>/<name>.md`. In a shallow clone, git dates are wrong: rerun with `--no-git` and say that the age against the last prompt change was not checked. Each `FAIL` line is a finding at the severity it prints.

### Step 2 — Read what the script cannot

- **Is the golden set worth passing?** Read a sample of each slice. Typical cases in the proportion the work has; edge cases that are really edge; attack cases that try injection, data leaks and tool misuse; a regression case for every failure the review notes mention. Thin slices are observations.
- **Graders.** Read the assertions: an exact-match or a model-graded rubric that would pass a wrong answer is an observation, with the case id.
- **AI-E4 after a golden-set change.** A version bump with no new results is AI-E2's job; say which of the two to fix first.
- **AI-L2.** Read the review notes' last row: does each new failure it lists have a regression case?

### Step 3 — Report

The `ai-review` Step 4 format, limited to these rules: the findings with rule ids, Other observations, and the script output verbatim. End with "Recommended next:" naming `ai-review`, and `ascent-security` for the red team (SEC-R), which this skill never reads.
