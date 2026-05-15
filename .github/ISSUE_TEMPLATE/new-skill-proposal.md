---
name: New skill proposal
about: Propose a new project-embedded skill (ascent-<name>) or parent-skill role
title: '[new-skill] '
labels: ['enhancement', 'new-skill']
assignees: ['lloydbrian']
---

## Type of skill

- [ ] New project-embedded skill (`ascent-<name>`)
- [ ] New role in the parent skill
- [ ] New optional/conditional skill (scaffolded based on architect interview)

## Proposed name

Following the [naming convention](../../docs/framework/DECISIONS/ADR-005-skill-naming.md):

**Proposed name:** `ascent-_________` or `<role-name>`

## Problem this solves

What gap in the current framework does this fill? Reference [`docs/framework/PRINCIPLES.md`](../../docs/framework/PRINCIPLES.md) if relevant.

Be specific. "Better security" is not a problem; "no skill audits whether security headers are still applied after each deploy" is.

## Real-world use case

A concrete scenario where this would be invoked. Bonus points for naming a real project where the gap was felt.

## Intent category (project-embedded skills only)

- [ ] context — session bootstrap, daily-driver state synthesis
- [ ] diagnostic — read-only inspection of project state
- [ ] sweep — continuous hygiene scan
- [ ] gate — pass/fail check that blocks progress until resolved
- [ ] posture — ongoing security/cost/observability state

## Proposed cadence

When should this skill be invoked? (session-start · pre-commit · pre-phase-gate · pre-release · weekly · monthly · on-demand)

## Scope boundaries

What does this skill NOT do? What overlap is there with existing skills, and where is the clean line drawn?

## Alternatives considered

- [ ] Folding into an existing skill instead (which one, and why doesn't that fit?)
- [ ] Handling as a `make` target rather than a skill (why is a skill warranted?)
- [ ] Treating as out-of-scope for ASCENT entirely (why does it belong in the framework?)

## Would require ADR

Per [`CONTRIBUTING.md`](../../CONTRIBUTING.md), some additions require an ADR.

- [ ] Yes, this requires an ADR (new role, new mode, new naming pattern, change to a documented invariant)
- [ ] No, this fits within existing conventions

## Implementation sketch

If you have a sense of how the skill would work, sketch it. Otherwise skip — the maintainer will design it during triage.

---

*Before submitting, please confirm:*

- [ ] I've read [`docs/framework/PRINCIPLES.md`](../../docs/framework/PRINCIPLES.md) and confirmed this proposal aligns with the framework's character
- [ ] I've searched existing skills for overlap
- [ ] I've articulated the gap in one or two specific sentences
