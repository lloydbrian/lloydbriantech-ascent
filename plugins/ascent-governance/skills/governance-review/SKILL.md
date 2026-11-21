---
name: governance-review
description: >-
  Use when asked "what is our governance status?", "which reviews are due?",
  "which waivers are about to expire?", "what would block a launch today?",
  "is our launch evidence current?", "set up launch floors for this project",
  or on a schedule between launches. Looks at every environment on the
  project's ladder without asking the launch question: runs the scripted
  checks of each floor, reads the review log and the waivers, checks the
  signed launch record of each environment that needs one (GOV-S1–S2,
  GOV-L1–L5, GOV-W1–W4, GOV-R1–R4), and reports what is due, what is
  expiring and what is broken, with the date each one becomes a problem.
  Read-only: it writes nothing and runs no review.
version: 0.2.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# governance-review

The standing view of `ascent-governance`: every environment, as a project's CI sees it. It answers what needs attention before the next launch, not whether to launch now (that is `launch-readiness`).

Shared sources:
- [governance-rules.md](../../references/governance-rules.md): the ladder, the floors, the review log, the launch record and the rules
- [contract-template.yml](../../references/contract-template.yml): the `governance:` section
- [registry.md](../../references/registry.md): which plugin owns each check and review

## Rules

- **Read-only.** Never write the review log, a launch record or the contract here, and never run a review: say which is due and which skill runs it.
- **The script gives each verdict.** Report what `check-audit.sh` prints for each environment; never soften or upgrade it.
- **Without the launch question.** A review that is due is a condition here, as in CI, and a NO-GO only in `launch-readiness`. Say that difference once, where a review is due.
- **Evidence, not goodness.** The verdicts say the evidence exists and is current.
- **Rate only with the severity table in launch-readiness.** A concern that matches no row goes under **Other observations (unrated)**.
- **No secrets or personal data** in the report.
- **Scripts.** The scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`. Quote every value you pass to a script.

## Steps

### Step 0 — Load the contract

Read `.ascent/contract.yml` (or `.claude/contract.yml`): `governance.environments`, `floors`, `approvers`, `review_log`, `launch_dir`, `maturity_target`. With no `governance` section, say that default floors apply and which maturity they follow, and propose the section once from the contract template, with every guessed value marked `# guess`. The proposal is text for the operator; never write it.

### Step 1 — Run every environment

For each environment on the ladder, lowest first:

```bash
bash "$PLUGIN_ROOT/scripts/check-audit.sh" --env '<environment>' .
```

Exit 0 is GO or GO WITH CONDITIONS, exit 1 is NO-GO, exit 2 is bad input: fix the arguments, never rate it. A higher environment repeats the lines of the ones below it; report each line once, at the lowest environment where it appears.

### Step 2 — Read what will become a problem

From the review log (`governance.review_log`) and the floors, work out for each review the date its newest record passes its maximum age. From the waiver lines, take each `review_by`. List both in date order: these are the dates the answer changes with no change to the code.

### Step 3 — Read the records the lines cite

For a GOV-L3, GOV-L4 or GOV-L5 line, read the launch record it names and say in one sentence what is wrong with it. For a GOV-R3 or GOV-R4 line, read the row or `git log -p -- <review log>` around the commit it names. For a GOV-S1 line, read the contract line it cites.

### Step 4 — Report

Use the format below. End with the sentence "These verdicts say the evidence exists and is current, not that the system is good."

## Output

```
## Governance — <project>
| Environment | Verdict | Blocks | Conditions | Unmeasured |
|---|---|---|---|---|

| Rule | Severity | Environment | Evidence | Fix |
|---|---|---|---|---|
Coming up: <date — the review or waiver that becomes due then; in date order>
Signed launches: <environment — record, signer, date, commit; or "none needed" | "none signed">
N/A: <rule — why>
Other observations (unrated)
Recommended next: <launch-readiness for an environment about to launch; the review skill for each review that is due, then review-record; ascent-adr:adr-write for a waiver with no accepted ADR>
```

Also name any plugin in `references/plugin-signals.md` whose signal this repository shows and whose skills are not available in this session, with its reason. The file is [plugin-signals.md](../../references/plugin-signals.md).
