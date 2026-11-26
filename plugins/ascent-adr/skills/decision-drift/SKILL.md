---
name: decision-drift
description: >-
  Use when asked "does the code still follow our ADRs?", "did we drift from
  our architecture decisions?", "make this decision checkable", "which ADRs
  does this change break?", "add a constraint for ADR-N", or when adr-check
  finds no constraints declared. Proposes constraints from accepted ADRs (a
  pattern the code must not contain, or a path that must exist), and after a
  person confirms them checks the code against them (DEC-C1–C3) with
  file:line evidence. Read-only: it never edits the contract or the code;
  constraints are added by the operator.
version: 0.1.2
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# decision-drift

Turns what an accepted ADR decided into something the code can be checked against, and checks it. A decision such as "PostgreSQL is the only database" becomes "no file under `src/` imports a MongoDB client"; "all infrastructure is in CloudFormation" becomes "`infra/cloudformation/` exists".

Shared sources:
- [decision-rules.md](../../references/decision-rules.md): DEC-C1–C3 and what a constraint is
- [contract-template.yml](../../references/contract-template.yml): `decisions.constraints`
- The severity table in the `adr-check` skill (`dec-severity`), which rates every DEC-C finding

## Rules

- **Read-only.** Never edit the contract, an ADR or the code. Proposed constraints are shown as YAML for the operator to add.
- **A person confirms each constraint.** Propose; never treat a proposal as declared. A constraint that is wrong makes every later check wrong.
- **Only accepted ADRs.** Never propose a constraint for a proposed, rejected, deprecated or superseded ADR.
- **Narrow patterns.** A forbid names the thing the ADR ruled out precisely (an import, a package, a call), with `under` set to where the rule applies, so tests, fixtures and docs that mention it are not findings. Try each pattern with Grep before proposing it, and show what it matches today.
- **Rate only with the severity table** in `adr-check`. What no constraint can express goes under **Other observations (unrated)**.
- **Scripts.** The scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`. Quote every pattern and path you pass.

## Steps

### Step 0 — Load the contract

Read `.ascent/contract.yml` (or `.claude/contract.yml`): `decisions.dir`, `maturity_target` and `constraints`. Find the ADR folder as `adr-check` Step 1 does.

### Step 1 — Read the accepted decisions

For each accepted ADR (all of them, or the ones the user names), read its Decision section and note any choice the code can show: a technology chosen or ruled out, a layer that must not call another, a file or folder that must exist, a service that must not be used. Skip decisions about process, people or cost: no constraint can check them.

### Step 2 — Propose constraints

For each checkable choice, propose one entry and show what it matches today:

```yaml
  - adr: ADR-<n>
    forbid: '<extended regular expression>'
    under: [<paths>]
    why: <one line from the ADR>
```

or `require: <path>`. Use Grep to run each forbid now; if it already matches code, that is a finding to confirm with the operator before the constraint is added, not a reason to loosen the pattern. Ask the operator to confirm, change or drop each proposal, and to add the confirmed ones to `decisions.constraints`.

### Step 3 — Check the code

```bash
bash "$PLUGIN_ROOT/scripts/check-decision-drift.sh" --dir '<decisions.dir>' --maturity '<maturity_target>' \
  --forbid 'ADR-<n>' '<pattern>' [--under '<path>,<path>'] ... --require 'ADR-<n>' '<path>' ... .
```

One `--forbid` (with its `--under`) or `--require` per constraint, in the contract's order. Exit 2 is bad input, such as an invalid pattern: fix it, never rate it. For each DEC-C1 match, open the file and say whether the match is real use or a mention (a comment, a string in a test); a mention means the constraint needs a narrower `under`, which the operator decides.

### Step 4 — Report

```
## Decision drift
Constraints: N (forbid F, require R) from A accepted ADRs

| Rule | Severity | Evidence | Failure scenario | Fix |
|---|---|---|---|---|

Proposed constraints (not yet declared): <YAML>
Other observations (unrated)
```

End with the limit: only the declared constraints are checked, not every way the code can drift from a decision.
