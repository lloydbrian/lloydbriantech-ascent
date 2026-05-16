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

Guides the creation of a new ADR for <<PROJECT_TITLE>> using the canonical five-section template. Handles numbering, file creation, and INDEX.md updates so the developer focuses on the decision content rather than the format ceremony.

## When this skill engages

- When a developer or architect has made a decision that constrains future work
- When explicitly asked to "write an ADR for X"
- When a design discussion concludes with a decision worth recording
- NOT for mechanical or easily-reversible decisions (those don't need ADRs)

## Inputs

- The decision title (what was decided)
- Context from the developer (the problem being solved; may be conversational)
- Optional: alternatives the developer already considered

## Outputs

- A new `docs/architecture/decisions/ADR-NNN-<slug>.md` file with all five sections populated
- Updated `docs/architecture/decisions/INDEX.md` with the new row
- If superseding: the old ADR's status field updated to `Superseded by ADR-NNN`

## Operational logic

The skill reads the current INDEX.md to determine the next ADR number, generates a kebab-case slug from the title, creates the file with the canonical template pre-filled (Status: Accepted, Date: today, Decider from .ascent-meta.json brand field), and guides the developer through Context, Decision, Alternatives (minimum 2, ideally 3-4), Consequences (structured as Easier/Harder/Neutral), and Cost implications (Time/Complexity/Future flexibility/Money). After creation, [ascent-self-audit](../ascent-self-audit/SKILL.md) can validate the ADR conforms. The full interview-style decision tree for eliciting alternatives and consequences lands in Phase 3.

## Examples

Examples land in Phase 3. Each example will show a decision prompt, the guided interaction, and the resulting ADR file.

## Anti-patterns

The primary failure mode is **writing ADRs with empty Alternatives sections** — "we considered nothing else" means the decision wasn't deliberated. The skill should push back when fewer than 2 alternatives are provided, asking "what else was on the table?" until genuine options surface.
