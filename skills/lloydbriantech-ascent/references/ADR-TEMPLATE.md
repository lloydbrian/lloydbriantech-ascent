# ADR-TEMPLATE

> The canonical ADR format. [PRINCIPLES.md §7](../../../docs/framework/PRINCIPLES.md#7-adr-discipline) and [docs/framework/DECISIONS/INDEX.md](../../../docs/framework/DECISIONS/INDEX.md) are authoritative.

## When to write an ADR

Write an ADR when the decision:

- Constrains future work (e.g., "every service emits JSON logs")
- Has alternatives that were genuinely considered (e.g., "we chose Postgres over MySQL because...")
- Will be questioned later by someone who wasn't present (e.g., "why did we pick this strange port number?")
- Affects more than one component (e.g., "the auth middleware lives in a shared package")

Do **not** write an ADR when the decision is:

- Mechanical (the framework has no opinion on which side of the screen the menu lives)
- Reversible by a single PR (writing an ADR for "use 2-space indentation" is overkill)
- Already documented as a framework invariant ([ASCENT-INVARIANTS.md](ASCENT-INVARIANTS.md) covers those)

When in doubt, write the ADR. They're cheap to produce and the regret asymmetry is real — missing an ADR you needed costs more than writing one you didn't.

## The canonical template

````markdown
# ADR-NNN: <Title>

**Status:** Proposed | Accepted | Superseded by ADR-XXX
**Date:** YYYY-MM-DD (America/New_York)
**Decider:** <name or role>

## Context

What is the issue we're seeing that is motivating this decision? Describe the
forces at play — technical, business, organizational — that frame the problem.

## Decision

What is the change we're proposing or have agreed to implement? State the
decision in active voice and full sentences.

## Alternatives considered

What other options were on the table? Why were they rejected? Each rejected
alternative gets one paragraph explaining the rejection.

## Consequences

What becomes easier or more difficult as a result? What trade-offs are accepted?

Use sub-sections **Easier:** / **Harder:** / **Neutral:** to keep the analysis
structured.

## Cost implications

What does this decision cost — in time, money, complexity, or future flexibility?
Be specific about the kind of cost; "expensive" is not an answer.
````

Every section is required. An ADR missing a section is incomplete.

## Numbering

- ADRs use three-digit zero-padded numbers: `ADR-001`, `ADR-042`, `ADR-100`
- Numbers are assigned at creation and **never renumbered** — even when an ADR is superseded, its number persists
- A new ADR that supersedes an existing one cites the old number in its Context section
- The old ADR's status changes to `Superseded by ADR-NNN` (where NNN is the new ADR's number)

## File path conventions

**Project-level ADRs:**

```
docs/architecture/decisions/ADR-001-<slug>.md
docs/architecture/decisions/INDEX.md
```

**Framework-level ADRs (this repository only):**

```
docs/framework/DECISIONS/ADR-001-<slug>.md
docs/framework/DECISIONS/INDEX.md
```

The framework uses an uppercase `DECISIONS/` directory to visually distinguish framework-level from project-level decisions in side-by-side directory listings. Scaffolded projects use lowercase `decisions/` per the dominant industry convention.

## `INDEX.md`

Every directory of ADRs has an `INDEX.md` listing them in numeric order with one-line summaries. The INDEX is updated as part of the same PR that adds the new ADR — never as an afterthought.

Format — each row has five columns: the linked ADR number, the title, the status, the date, and a one-line summary. The number cell uses standard markdown link syntax with the ADR file name (`ADR-NNN-<slug>.md`) as the target, relative to the INDEX. A typical row (rendered, not as source):

| # | Title | Status | Date | Summary |
|---|---|---|---|---|
| 001 | Single parent skill with internal role routing | Accepted | 2026-05-14 | Collapse six proposed parent skills into one to avoid trigger collision |

The framework's own INDEX at `docs/framework/DECISIONS/INDEX.md` is the canonical worked example.

## Worked example

The framework's own [ADR-001](../../../docs/framework/DECISIONS/ADR-001-single-parent-skill.md) is a worked example of every rule above:

- Title: `ADR-001: Single parent skill with internal role routing`
- Status: `Accepted`
- Date: `2026-05-14 (America/New_York)`
- Five sections: Context, Decision, Alternatives considered, Consequences, Cost implications
- Cost implications section discusses Time / Complexity / Future flexibility / Money explicitly

The framework's seven foundational ADRs all follow this shape.

## Supersession

When a new ADR replaces an old one:

1. New ADR's Context section starts with: "This ADR supersedes ADR-NNN: \<title\>. See that ADR for the original rationale."
2. Old ADR's Status changes from `Accepted` to `Superseded by ADR-XXX` (where XXX is the new ADR's number)
3. Old ADR's body is **not edited** — the rationale at the time it was accepted is preserved as history
4. INDEX.md updates both rows' status

The old ADR is never deleted. The decision history is part of the project's permanent record.

## Anti-patterns

- **One-paragraph ADRs.** "We chose X." That's a sentence, not an ADR. If there's nothing to write under Alternatives or Consequences, the decision didn't need an ADR.
- **ADRs as TODO lists.** "We'll decide later" is not a decision. Either decide and write the ADR, or don't write one yet.
- **Renumbering when an ADR is superseded.** ADR-005 superseded by ADR-042 stays as ADR-005 forever. Renumbering breaks every reference.
- **Editing accepted ADRs.** Once accepted, the body is immutable. Corrections to typos are fine; rewriting reasoning is supersession.
- **Skipping `Cost implications`.** This section is the ASCENT extension to the standard Michael Nygard template. It exists because every decision has a cost; making it explicit prevents the "I didn't realize this was so expensive" surprise.
