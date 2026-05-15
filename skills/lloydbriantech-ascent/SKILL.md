---
name: lloydbriantech-ascent
description: >-
  ASCENT engineering framework. Use to scaffold new projects, enhance existing
  ASCENT projects, migrate non-ASCENT projects to ASCENT standards, or answer
  questions about ASCENT's conventions, principles, or nine engineering roles
  (delivery-lead, architect, ui-ux-designer, developer, data-engineer,
  ai-engineer, tester, devops, cybersecurity).
version: 0.2.0
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# lloydbriantech-ascent

The parent skill of the ASCENT engineering framework. It scaffolds new projects, enhances existing ASCENT projects, and migrates non-ASCENT projects to ASCENT standards. One skill routes user intent across nine engineering roles at runtime — see [ADR-001](../../docs/framework/DECISIONS/ADR-001-single-parent-skill.md) for why one skill instead of nine.

## When this skill engages

This skill should engage when any of the following hold:

- The user asks to scaffold or create a new project with ASCENT
- The user is in an ASCENT project (a `.ascent-meta.json` is present) and asks about conventions, principles, ADRs, or framework operations
- The user invokes a specific role explicitly (e.g. "as the architect role, draft an ADR for X")
- The user asks to bring an existing non-ASCENT project up to ASCENT standards (migrate mode)
- The user asks "what role handles X?" or otherwise references framework discipline

For requests that don't match these patterns, this skill should not engage.

## Operating modes

ASCENT defines four modes per [ADR-003](../../docs/framework/DECISIONS/ADR-003-ascent-meta-marker.md). The skill detects the active mode at the start of every invocation by examining the target directory.

| Mode | Engaged when | Behavior |
|---|---|---|
| `scaffold` | No `.ascent-meta.json` present | Greenfield creation — interview + full project tree |
| `enhance` | `.ascent-meta.json` present with a real slug | Additive surgical changes only (per [ADR-002](../../docs/framework/DECISIONS/ADR-002-modify-not-overwrite.md)) |
| `migrate` | User passes `--migrate` flag | Bring an existing non-ASCENT project up to ASCENT standards |
| `bootstrap` | Slug is `ascent-starter` and meta is a placeholder | Slug substitution after `gh repo create --template` |

The canonical mode-detection schema is in [ADR-003](../../docs/framework/DECISIONS/ADR-003-ascent-meta-marker.md). The phase-protocol contract that governs how modes interact with phase gates is in [references/PHASE-PROTOCOL.md](references/PHASE-PROTOCOL.md).

## The nine roles

The skill routes intent across nine non-overlapping roles. Each owns a slice of the project lifecycle.

| Role | Owns |
|---|---|
| delivery-lead | Phase plans, requirements decomposition, risk register, dependencies, gate criteria, status synthesis |
| architect | Skeleton, ADRs, container topology, framework docs, Make framework, observability contract |
| ui-ux-designer | Design system, theming, page layouts, visual specs, interaction patterns, accessibility-as-design |
| developer | Backend implementation, frontend implementation, agent task modules, integration patterns |
| data-engineer | Schema design, indexing, query optimization, migration safety, data quality |
| ai-engineer | Prompt engineering, eval harnesses, model abstraction, agentic patterns, safety guardrails |
| tester | All test disciplines, quality gates, NFR catalog, traceability, validation |
| devops | Infra, CI/CD, AWS, distribution, observability collection, release engineering |
| cybersecurity | Security baseline, threat modeling, secrets, hardening, compliance |

Per-role detail lives in `references/role-<name>.md` modules.

## Reference modules

The skill loads reference modules on demand based on the engaged role(s) and the task at hand. The full module set:

**Roles (9):**

- [references/role-delivery-lead.md](references/role-delivery-lead.md)
- [references/role-architect.md](references/role-architect.md)
- [references/role-ui-ux-designer.md](references/role-ui-ux-designer.md)
- [references/role-developer.md](references/role-developer.md)
- [references/role-data-engineer.md](references/role-data-engineer.md)
- [references/role-ai-engineer.md](references/role-ai-engineer.md)
- [references/role-tester.md](references/role-tester.md)
- [references/role-devops.md](references/role-devops.md)
- [references/role-cybersecurity.md](references/role-cybersecurity.md)

**Protocols and conventions (6):**

- [references/ASCENT-INVARIANTS.md](references/ASCENT-INVARIANTS.md)
- [references/MAKE-NAMING.md](references/MAKE-NAMING.md)
- [references/SLUG-CONVENTIONS.md](references/SLUG-CONVENTIONS.md)
- [references/PHASE-PROTOCOL.md](references/PHASE-PROTOCOL.md)
- [references/ENV-DISCIPLINE.md](references/ENV-DISCIPLINE.md)
- [references/ADR-TEMPLATE.md](references/ADR-TEMPLATE.md)

**Practices and style (6):**

- [references/feature-lifecycle.md](references/feature-lifecycle.md)
- [references/observability-contract.md](references/observability-contract.md)
- [references/writing-style.md](references/writing-style.md)
- [references/doc-architecture.md](references/doc-architecture.md)
- [references/audience-mapping.md](references/audience-mapping.md)
- [references/external-services-integration.md](references/external-services-integration.md)

Once each module exists, the inline-code references above are converted to markdown links via surgical edits in the corresponding chunk's PR.

## Routing logic

`[STUB — full routing decision tree lands in Chunk 6 of Phase 1]`

Per [ADR-001](../../docs/framework/DECISIONS/ADR-001-single-parent-skill.md), the skill routes user intent through three stages: mode detection (read `.ascent-meta.json` per [ADR-003](../../docs/framework/DECISIONS/ADR-003-ascent-meta-marker.md)), role inference (match intent shape against role descriptors), and reference-module loading (load only what the engaged role(s) require). Each stage is deterministic — given the same input directory and prompt, the same role(s) and modules load. Chunk 6 fills in the decision tree itself, the role-inference rules, and the multi-role loading patterns once all reference modules exist.

## Examples

`[STUB — at least 10 representative prompts with expected role selections land in Chunk 6 of Phase 1]`
