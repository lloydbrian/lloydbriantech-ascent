---
name: ascent-doc-stub
description: >-
  Generates persona-targeted documentation skeletons for <<PROJECT_TITLE>>.
  Each generated doc has a named audience, a clear navigation path from
  the persona's entry point, and section headings that match the audience's
  needs — not blank files or generic templates.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
---

# ascent-doc-stub

Generates documentation skeletons that are persona-targeted from creation. Every doc this skill produces has a named primary audience (Architect, Developer, Operator, Contributor, or Learner), section headings appropriate to that audience, and a placement that respects the 3-click depth limit from the persona's entry point.

## When this skill engages

- When a developer needs to create a new doc and wants it properly structured from the start
- When explicitly asked to "create docs for X"
- When a feature intake identifies documentation deliverables
- NOT for ADRs (use ascent-adr-write) or CHANGELOG entries (those have their own format)

## Inputs

- The doc's topic (what it documents)
- The primary audience (Architect, Developer, Operator, Contributor, or Learner)
- Optional: the placement path (where in docs/ the file should live)

## Outputs

- A new markdown file at the specified path with audience-appropriate section headings
- A provenance line identifying the primary persona
- Section headings that ask the questions the audience would ask (not generic "Overview" / "Details")

## Operational logic

The skill reads the project's doc-architecture conventions (persona entry points, depth limits, voice guidelines) and generates a skeleton whose headings match the target persona's needs. An Architect doc gets sections about constraints, alternatives, and trade-offs; a Developer doc gets sections about implementation, testing, and integration; an Operator doc gets sections about commands, failure modes, and escalation. The generated doc includes a `<!-- Audience: <persona> -->` comment for future audits. The full persona-to-section-template mapping lands in Phase 3.

## Examples

Examples land in Phase 3. Each example will show a topic + persona input and the resulting doc skeleton with audience-appropriate headings.

## Anti-patterns

The primary failure mode is **generating docs without naming the audience** — producing a "universal" doc that serves no persona well. Every doc this skill creates must have ONE named primary audience. If the developer says "it's for everyone," push back: "who reads this first, and what question are they answering?"
