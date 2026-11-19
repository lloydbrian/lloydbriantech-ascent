---
name: adr-check
description: >-
  Use when asked "do our ADRs conform?", "check our decision records", "is
  our ADR index current?", "did anyone edit an accepted ADR?", "are our
  supersessions linked?", "review our architecture decisions", or before a
  release or a phase gate. Finds the ADR folder in any repository (ASCENT,
  Nygard and adr-tools, or MADR format), checks DEC-S1–S8 (sections, numbers,
  index, status, supersession both ways, dates, accepted bodies unchanged
  since acceptance, from git history) and the declared constraints (DEC-C1–C3,
  with decision-drift), and rates the decision record strong, moderate or
  weak with file:line evidence. Read-only.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# adr-check

The entry point of `ascent-adr`. It answers one question: can someone who joins this project find each decision that constrains it, trust that it is complete and current, and see what replaced it?

Shared sources:
- [decision-rules.md](../../references/decision-rules.md): the formats, DEC-S1–S8, DEC-C1–C3 and their limits
- [contract-template.yml](../../references/contract-template.yml): the `decisions:` section

## Rules

- **Read-only.** Never edit an ADR, the index or the contract. A fix is proposed as text; `adr-write` writes ADRs, and the operator commits.
- **Evidence for every finding:** `file:line`, the rule id, and a failure scenario (who is misled, and how).
- **Rate only with the severity table below.** A concern that matches no row goes under **Other observations (unrated)**: for example, a decision that looks wrong, or code that seems to contradict an ADR with no constraint declared.
- **Never judge whether a decision is right.** The checks prove decisions are recorded and kept. Say so in the report.
- **No secrets or personal data** in the report: an ADR's Decider is quoted as written, nothing more.
- **Scripts.** The scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`. Quote every contract value you pass to a script.

## Severity

<!-- dec-severity:start -->
| Finding | Severity |
|---|---|
| No decision record: no ADR folder, or one holding no ADR (DEC-S1) | Medium |
| An ADR missing a section its format requires (DEC-S2) | Medium |
| An ADR with no status, or a status that is not proposed, accepted, rejected, deprecated or superseded (DEC-S5) | Medium |
| A superseded ADR whose replacement is missing or does not name it, or an ADR that supersedes one still marked active (DEC-S6) | Medium |
| An accepted ADR whose body changed after it was accepted, with no acknowledgement (DEC-S8) | Medium |
| Code that matches a forbid constraint of an accepted ADR (DEC-C1) | Medium |
| A path a require constraint of an accepted ADR names is missing (DEC-C2) | Medium |
| Two ADRs with one number, a Markdown file in the folder not named as an ADR, or a title whose number differs from its file (DEC-S3) | Low |
| An ADR missing from the index, an index link to no file, or an index status that differs from the ADR (DEC-S4) | Low |
| An ADR with no date, or a date that is not real or is after today (DEC-S7) | Low |
| A constraint that names an ADR that is missing or not accepted (DEC-C3) | Low |
| A decisions value missing from the contract ("unmeasured") | Low |
<!-- dec-severity:end -->

**Rating:** strong: no Medium. moderate: one to three Medium. weak: four or more Medium, or DEC-S1 (no decision record at all).

## Steps

### Step 0 — Load the contract

Read `.ascent/contract.yml` (or `.claude/contract.yml`): `decisions.dir`, `index`, `style`, `maturity_target`, `acknowledged_changes` and `constraints`. If the section is missing, propose it from what the repository has (detect, don't ask): the ADR folder the script finds, the format most ADRs use, and no constraints. Mark every guessed value `# guess` and use the proposal for this run, saying it is unconfirmed.

### Step 1 — Map the decision record

Find the ADR folder and the index, count the ADRs by status, and note the format. List the five most recent decisions by date, so the report shows what the record covers. Name every path you used.

### Step 2 — Run the record checks

```bash
bash "$PLUGIN_ROOT/scripts/check-adrs.sh" --dir '<decisions.dir>' --style '<decisions.style>' --maturity '<maturity_target>' [--index '<decisions.index>'] [--acknowledge 'ADR-N=<commit>']... .
```

Pass `--acknowledge` once for each entry of `acknowledged_changes`. Leave out an option whose value the contract does not set. Exit 2 is bad input: fix the arguments, never rate it.

For each DEC-S8 failure, read `git log -- <file>` and the change it names, and say in one sentence what changed. Never propose an acknowledgement on your own: a person decides that a change is kept, and the report says what they would be accepting.

### Step 3 — Run the constraint checks

If `decisions.constraints` has entries, run `decision-drift` Step 3. With no constraints, DEC-C1–C3 are N/A: say that the code is not checked against any decision, and that `decision-drift` can propose constraints.

### Step 4 — Read what the scripts cannot

Read the five most recent accepted ADRs. Report under **Other observations (unrated)**: a decision with no real alternative in it, consequences that name nothing harder, and code you saw while mapping that seems to contradict an ADR with no constraint declared. These are leads for a person, never rated.

### Step 5 — Report

```
## Decision record — <strong | moderate | weak>
Folder: <dir> · Index: <file or none> · Format: <style> · ADRs: N (accepted A, proposed P, superseded S, other O)

| Rule | Severity | Evidence | Failure scenario | Fix |
|---|---|---|---|---|

Acknowledged changes: <each, from the NOTE lines>
N/A: <rule — why>
Other observations (unrated)
Recommended next: <adr-write to supersede or complete an ADR; decision-drift to declare constraints>
```

The checks prove that decisions are recorded and kept, not that they are right: end the report with that sentence.
