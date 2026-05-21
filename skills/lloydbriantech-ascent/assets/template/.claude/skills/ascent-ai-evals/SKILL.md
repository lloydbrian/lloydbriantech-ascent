---
name: ascent-ai-evals
description: >-
  Validates AI eval scenario structure and prompt-test coverage for
  <<PROJECT_TITLE>>. Checks tests/evals/ for scenario conformance.
  No-ops gracefully when no eval suite is present.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
---

# ascent-ai-evals

Validates the structural conformance of the project's AI eval suite. When `tests/evals/` exists, the skill checks that eval scenarios have required structural sections and that prompts used in application code have corresponding eval coverage. When `tests/evals/` is absent, the skill exits zero — not every project uses AI features.

This skill is conditional — the Phase 4 scaffolder will gate its inclusion based on project type. Until then, it ships in all scaffolded projects and exits gracefully when its subsystem is absent.

## When this skill engages

- After adding or modifying AI prompts or eval scenarios
- When a developer asks "are my evals covering the prompts?"
- As a periodic check on eval coverage (recommended: per-prompt-change)
- NOT for running evals — this skill validates structure, not correctness

## Inputs

- **`tests/evals/*.md`** (or `*.yml`, `*.json`) — eval scenario files
- **`backend/` and `frontend/` source files** — scanned for prompt patterns

## Outputs

- **Per-check report** — each check marked PASS, CONCERN, or SKIP
- **Summary line** — "ai-evals: N/3 checks passing" or "ai-evals: no eval suite present (no-op)"

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Detect eval suite

**Condition:** `tests/evals/` directory exists with at least one file.

**Action on PASS:** Proceed to structural checks. Report: "Eval suite detected: [N] scenario files."

**Action on FAIL (no directory):** Report "ai-evals: no eval suite present — expected for non-AI projects or projects pre-Phase 5." Exit zero.

### Step 2 — Scenario structure validation

**Condition:** Each eval file in `tests/evals/` contains required structural sections. For markdown-format evals, required sections are: `## Prompt`, `## Expected`, `## Context` (or equivalent headers).

**Action on PASS:** Report "Scenario structure — PASS. [N] scenarios, all well-formed."

**Action on CONCERN:** List each malformed scenario. "Scenario structure — CONCERN. tests/evals/greeting.md missing `## Expected` section."

### Step 3 — Prompt-test coverage

**Condition:** Detect prompts in the project by scanning for a `backend/prompts/` or `prompts/` directory. Each file in that directory is treated as a prompt definition. For each detected prompt file, check whether a corresponding eval scenario exists in `tests/evals/` with the same filename.

Detection mechanism: list all files in `backend/prompts/` (or `prompts/` at project root). For each file `<name>.md`, check for `tests/evals/<name>.md`. A prompt without a matching eval file is uncovered.

**Action on PASS:** Report "Prompt coverage — PASS. [N] prompts, all with eval scenarios."

**Action on CONCERN:** List uncovered prompts. "Prompt coverage — CONCERN. backend/prompts/classify.md has no eval in tests/evals/classify.md."

**Fallback:** If no `prompts/` directory exists, report "Prompt coverage — SKIP (no prompts/ directory)."

### Step 4 — Aggregate and report

**Action:** Collect results. Report summary.

## Examples

### Example 1 — Eval suite with gaps

```
ai-evals: 2/3 checks passing (1 concern)
  Eval suite detected    PASS (4 scenarios)
  Scenario structure     PASS (4/4 well-formed)
  Prompt coverage        CONCERN — backend/prompts/classify.md has no eval
```

### Example 2 — No eval suite

```
ai-evals: no eval suite present — expected for non-AI projects or projects pre-Phase 5.
```

## Anti-patterns

### Anti-pattern 1 — Creating eval stubs without running them

Adding `tests/evals/greeting.md` with placeholder content to pass the structure check. **Why it's tempting:** "I'll fill it in later." **What to do instead:** eval scenarios are only valuable when they contain real expected outputs. A stub eval is worse than no eval — it gives false coverage confidence.
