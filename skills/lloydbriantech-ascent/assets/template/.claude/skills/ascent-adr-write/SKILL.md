---
name: ascent-adr-write
description: >-
  Guides writing a new Architectural Decision Record in the canonical
  ASCENT format: Context, Decision, Alternatives considered, Consequences
  (Easier/Harder/Neutral), and Cost implications. Assigns the next ADR
  number, creates the file, and updates INDEX.md.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
---

# ascent-adr-write

Guides the creation of a new ADR for <<PROJECT_TITLE>> using the canonical five-section template. Handles numbering, file creation, and INDEX.md updates so the developer focuses on the decision content rather than the format ceremony. Writes are atomic — the ADR file and its INDEX.md row land together or not at all. Per the `adr-template` reference module, every section is required; an ADR missing a section is incomplete.

## When this skill engages

- When a developer or architect has made a decision that constrains future work
- When explicitly asked to "write an ADR for X"
- When a design discussion concludes with a decision worth recording
- When a new ADR must supersede an existing one (the supersession protocol)
- NOT for mechanical or easily-reversible decisions (those don't need ADRs)
- NOT for decisions already documented as framework invariants (those live in `ASCENT-INVARIANTS`)

## Inputs

- **Decision title** — what was decided (required; must be descriptive enough to derive a slug)
- **Context from the developer** — the problem being solved; may be conversational (required)
- **Alternatives already considered** (optional) — the developer may arrive with alternatives or the skill elicits them
- **Supersession target** (optional) — the ADR number being superseded, if any

## Outputs

- **A new `docs/architecture/decisions/ADR-NNN-<slug>.md`** with all five sections populated
- **Updated `docs/architecture/decisions/INDEX.md`** with the new row appended
- **If superseding:** the old ADR's Status field updated to `Superseded by ADR-NNN`

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Determine next ADR number

**Condition:** `docs/architecture/decisions/INDEX.md` exists.

**Action on PASS:** Read INDEX.md, extract the highest ADR number from the table rows, and compute the next number (zero-padded to 3 digits: 008, 042, 100). Report: "Next available ADR number: ADR-NNN."

**Action on FAIL:** No INDEX.md means no ADR directory structure. Report: "docs/architecture/decisions/INDEX.md not found — creating ADR directory structure." Create `docs/architecture/decisions/` and a seed INDEX.md with the five-column header: `| # | Title | Status | Date | Summary |` followed by the separator row `|---|---|---|---|---|`. Set next number to 001.

### Step 2 — Validate title and derive slug

**Condition:** The developer has provided a decision title.

**Action:** Derive a kebab-case slug from the title. Rules per the `SLUG-CONVENTIONS` reference module: lowercase, hyphens between words, no special characters, no trailing hyphens. The full filename is `ADR-NNN-<slug>.md`.

**Fallback:** If the title is too vague to produce a meaningful slug (e.g., "stuff"), ask: "What specific decision does this ADR record? A good ADR title names the choice, not the topic."

### Step 3 — Check for numbering collision

**Condition:** The computed filename `ADR-NNN-<slug>.md` does not already exist in `docs/architecture/decisions/`.

**Action on PASS:** Proceed to interview.

**Action on FAIL:** A file at the computed number already exists. Increment to the next available number and recheck. Report: "ADR-NNN already exists — assigning ADR-MMM instead."

### Step 4 — Interview: Context section

**Condition:** The developer provides context for the decision.

**Action:** Capture the problem statement — the forces at play (technical, business, organizational) that frame the decision. The Context section answers: "What is the issue we're seeing that is motivating this decision?"

If superseding an existing ADR, the Context section opens with: "This ADR supersedes ADR-NNN: <title>. See that ADR for the original rationale."

**Fallback:** If the developer provides only the decision without context, ask: "What problem does this decision solve? What forces led to this choice?"

### Step 5 — Interview: Decision section

**Action:** Capture the decision itself in active voice and full sentences. The Decision section answers: "What is the change we're proposing or have agreed to implement?"

### Step 6 — Interview: Alternatives considered

**Condition:** The developer provides at least 2 genuine alternatives.

**Action on PASS:** Capture each rejected alternative with a paragraph explaining the rejection rationale.

**Action on FAIL (fewer than 2):** Push back: "What else was on the table? An ADR with no alternatives means the decision wasn't deliberated. What did you consider before choosing this approach?" Repeat until at least 2 alternatives are documented.

The skill accepts 2 as the minimum but encourages 3-4. If the developer insists there were no alternatives, challenge: "Even 'do nothing' and 'defer to next phase' are alternatives worth documenting."

### Step 7 — Interview: Consequences

**Action:** Capture consequences structured as three sub-sections:

- **Easier:** what becomes simpler or cheaper as a result
- **Harder:** what becomes more difficult or constrained
- **Neutral:** trade-offs that shift work without net improvement

Each sub-section needs at least one concrete consequence. "Nothing gets harder" is almost never true — probe: "What flexibility does this decision give up?"

### Step 8 — Interview: Cost implications

**Action:** Capture costs across four dimensions:

- **Time** — implementation effort, maintenance burden
- **Complexity** — added complexity to the system or process
- **Future flexibility** — options closed or opened by this decision
- **Money** — direct costs (services, licenses) or indirect costs (operational overhead)

"Expensive" is not an answer. Each dimension gets a specific statement. If a dimension is genuinely not affected, state that explicitly: "Money: no direct cost impact."

### Step 9 — Present complete ADR for review

**Condition:** All five sections are populated from Steps 4-8.

**Action:** Present the complete ADR file content to the developer for review. Format:

```markdown
# ADR-NNN: <Title>

**Status:** Accepted
**Date:** YYYY-MM-DD (America/New_York)
**Decider:** <<BRAND>>

## Context
[from Step 4]

## Decision
[from Step 5]

## Alternatives considered
[from Step 6]

## Consequences
[from Step 7 — with Easier/Harder/Neutral sub-sections]

## Cost implications
[from Step 8 — with Time/Complexity/Future flexibility/Money]
```

**Gate:** The developer must explicitly approve before the skill writes. "Review this ADR. Confirm to write, or specify what to change."

### Step 10 — Write ADR file and update INDEX.md

**Condition:** Developer has approved the ADR content from Step 9.

**Action:** Two writes, atomic (both or neither):

1. **Write** the ADR file to `docs/architecture/decisions/ADR-NNN-<slug>.md`
2. **Append** a new row to `docs/architecture/decisions/INDEX.md` with columns: linked number, title, status (Accepted), date, one-line summary

If superseding: also **Edit** the old ADR's Status line from `Accepted` to `Superseded by ADR-NNN`. The old ADR's body is never edited — only the Status field changes.

**Valid paths:** This skill writes only to `docs/architecture/decisions/`. Any other path is a step failure.

Report: "ADR-NNN written. INDEX.md updated. Consider running [ascent-self-audit](../ascent-self-audit/SKILL.md) to validate the ADR conforms to §7."

## Examples

### Example 1 — Standard ADR creation

**Input:** "Write an ADR for choosing Redis as the session store."

**Skill action:** Reads INDEX.md (7 existing ADRs) → assigns ADR-008 → derives slug `redis-session-store` → interviews developer through all 5 sections → presents complete ADR → developer approves → writes `ADR-008-redis-session-store.md` + appends INDEX.md row.

**Output filename:** `docs/architecture/decisions/ADR-008-redis-session-store.md`

### Example 2 — Supersession

**Input:** "We're replacing SQLite with Postgres. This supersedes ADR-004."

**Skill action:** Assigns ADR-008 → Context section opens with "This ADR supersedes ADR-004: SQLite-WAL as default database." → after approval, writes ADR-008 + appends INDEX.md + edits ADR-004's status to `Superseded by ADR-008`.

### Example 3 — Alternatives push-back

**Input:** "Write an ADR for using pino as the logger."
**Developer provides:** Context and decision, but says "There were no alternatives."

**Skill push-back:** "What else was on the table? Even 'use Winston,' 'use Bunyan,' or 'do nothing and use console.log' are genuine alternatives. An ADR with no alternatives means the decision wasn't deliberated."

**Developer responds:** "We considered Winston (too heavy, kitchen-sink API) and Bunyan (unmaintained, last release 2019)."

**Skill proceeds:** captures both alternatives with rejection rationale.

## Anti-patterns

### Anti-pattern 1 — Empty Alternatives section

"We considered nothing else" passes through without challenge. **Why it's tempting:** the developer has already decided and alternatives feel like busywork. **What to do instead:** the skill's Step 6 gate requires minimum 2 alternatives. "Do nothing" and "defer" are always available as genuine alternatives.

### Anti-pattern 2 — Editing accepted ADRs

Rewriting an accepted ADR's reasoning after the fact. **Why it's tempting:** the reasoning evolved or was poorly written. **What to do instead:** supersede with a new ADR. The original reasoning is part of the permanent decision record. Typo fixes are fine; reasoning rewrites are supersession.

### Anti-pattern 3 — Renumbering on supersession

Renaming ADR-005 to ADR-005-old when ADR-042 supersedes it. **Why it's tempting:** clean numbering feels orderly. **What to do instead:** ADR-005 stays as ADR-005 forever. Its Status field changes; its number and filename never do. Renumbering breaks every reference across the project.

### Anti-pattern 4 — Skipping Cost implications

Leaving Cost implications as "N/A" or "none." **Why it's tempting:** not every decision has obvious dollar costs. **What to do instead:** cost is broader than money. Time (implementation + maintenance), Complexity (added moving parts), Future flexibility (options opened or closed), and Money (services, licenses) are four dimensions. At minimum, state the time and flexibility impact.
