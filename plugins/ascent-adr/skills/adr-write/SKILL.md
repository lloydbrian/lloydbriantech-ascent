---
name: adr-write
description: >-
  Use when asked to "write an ADR", "record this decision", "document why we
  chose X", "supersede ADR-N", "deprecate this decision", or when a change
  makes a choice future contributors will wonder about. Finds the
  repository's ADR folder and format (ASCENT, Nygard and adr-tools, or MADR),
  takes the next number, interviews for the context, the decision, at least
  two real alternatives, the consequences and the costs, shows the complete
  ADR and writes it only after approval, with its index row; when
  superseding, changes only the old ADR's status line. Never edits an
  accepted ADR's body and never commits.
version: 0.1.2
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# adr-write

Records one decision as an ADR in the repository's own folder and format, so the next person to wonder "why is it like this?" finds the answer, the options that were turned down and what it costs.

Shared sources:
- [decision-rules.md](../../references/decision-rules.md): the formats, statuses, supersession both ways, and why an accepted body never changes
- [contract-template.yml](../../references/contract-template.yml): `decisions.dir`, `index`, `style`

## Rules

- **Write only after approval, and only these files:** the new ADR, one new row in the index, and, when superseding or deprecating, the status line of the old ADR. Any other path is a failure of this skill. Never commit.
- **Never edit an accepted ADR's body.** A changed decision is a new ADR that supersedes the old one. Fixing a typo in an accepted ADR is still a change; propose it to the operator, who decides whether to acknowledge it (`decisions.acknowledged_changes`).
- **Real alternatives.** At least two, each with why it was turned down. "Do nothing" and "defer" count when they were real options. An ADR with no alternative records an instruction, not a decision: push back once, then write what the person gives.
- **The person decides.** Write the person's decision in their words, made complete; never invent a rationale, a cost or a consequence. Mark anything you inferred as a question in the preview.
- **No secrets or personal data:** name services and settings, never credentials or account ids. The decider is a name the person gives, or a role.

## Steps

### Step 0 — Find the folder, the format and the next number

Read `decisions.dir`, `index` and `style` from `.ascent/contract.yml` (or `.claude/contract.yml`); without them, find the folder as `adr-check` Step 1 does. Take the format the existing ADRs use (`style: auto`), or ASCENT's when the folder is new. The next number is one more than the highest in the folder, zero-padded as the existing files are; check that no file has it. With no folder at all, propose `docs/adr/` and an `INDEX.md`, and create them only with the ADR.

### Step 1 — The title

A title names the choice, not the topic: "Use PostgreSQL for all persistent data", not "Database". Derive the file name: the number, then the title in lower-case kebab-case.

### Step 2 — Interview

Ask for each section, one at a time, and accept short answers:
1. **Context:** what problem, and what forces (technical, business, people) frame it. When superseding, the Context begins with the supersession sentence of the format: ASCENT `This ADR supersedes ADR-M: <title>.`; adr-tools `Supersedes [M. Title]` with a link to the old file under Status.
2. **Decision:** what was decided, in the active voice.
3. **Alternatives considered:** at least two, each with why it lost (MADR: Considered Options, with pros and cons).
4. **Consequences:** what becomes easier, what becomes harder, and what only shifts. "Nothing gets harder" is almost never true: ask what flexibility is given up.
5. **Cost implications** (ASCENT format): time, complexity, future flexibility and money, each stated; "no direct cost" is a statement.

### Step 3 — Show the complete ADR

Show the whole file in the folder's format, with status `Accepted` (or `Proposed` when the person says the decision is still open) and today's date, the index row, and, when superseding, the old ADR's new status line (`Superseded by ADR-N`). Ask: "Confirm to write, or say what to change."

### Step 4 — Write

After confirmation only: write the ADR, add its index row in the index's own column order, and change the old ADR's status line when superseding. Nothing else.

### Step 5 — Offer a constraint

If the decision is one the code can show (a technology chosen or ruled out, a required folder), offer to propose a constraint with `decision-drift` Step 2.

### Step 6 — Check

```bash
bash "$PLUGIN_ROOT/scripts/check-adrs.sh" --dir '<decisions.dir>' .
```

`PLUGIN_ROOT` is two directories above this skill's base directory (shown when the skill loads). Report any DEC finding the new ADR causes and fix it in the same session; findings on older ADRs are listed for `adr-check`, never fixed here.
