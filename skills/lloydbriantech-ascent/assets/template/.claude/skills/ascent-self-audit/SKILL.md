---
name: ascent-self-audit
description: >-
  Verifies that <<PROJECT_TITLE>> conforms to all 14 ASCENT invariants.
  The umbrella audit — composes ascent-layering-check, ascent-env-audit,
  and ascent-observability-check as component checks, then validates
  remaining invariants (containerization, make vocabulary, phase gates,
  label scoping, engine compatibility, graceful shutdown, dev-status,
  persona docs, ADR discipline, stub naming, context-aware execution).
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-self-audit

Comprehensive audit of <<PROJECT_TITLE>> against the 14 ASCENT framework invariants. This is the umbrella skill — it composes the three focused component checks ([ascent-layering-check](../ascent-layering-check/SKILL.md), [ascent-env-audit](../ascent-env-audit/SKILL.md), [ascent-observability-check](../ascent-observability-check/SKILL.md)) and validates the remaining invariants directly.

## When this skill engages

- Before a commit or PR, to verify the project is still ASCENT-compliant
- When a developer suspects a convention has drifted
- As a periodic health check (recommended: weekly or per-phase)
- When onboarding confirms the project's adherence after changes

## Inputs

- The project's root directory (reads files, checks structure, validates patterns)
- No user input required — the audit is autonomous

## Outputs

- A structured report: each of the 14 invariants marked PASS or FAIL
- For each FAIL: the specific violation, the file/line, and the fix action
- Summary line: "N/14 invariants passing"

## Operational logic

The audit runs in three phases. First, it delegates to the three component skills — `ascent-layering-check` validates the backend pipeline, `ascent-env-audit` validates environment discipline, and `ascent-observability-check` validates emission patterns. Second, it validates the remaining 11 invariants by reading project structure: containerization (Dockerfile exists, compose labels present), make vocabulary (Makefile + make/ tree present, targets follow naming convention), phase gates (.ascent-meta.json phase field matches CHANGELOG), label scoping (compose files label every resource), engine compatibility ($(ENGINE) variable used), graceful shutdown (SIGTERM handler in server.js), dev-status (make/dev-status.mk exists with the expected targets), persona docs (README has persona section or links audience-mapping), ADR discipline (INDEX.md lists all ADR files), stub naming (stubs print [STUB]), and context-aware execution (INSIDE_CONTAINER marker exported). The full decision tree for each invariant lands in Phase 3.

## Examples

Examples land in Phase 3. Each example will show a specific violation, the audit's output, and the corrective action.

## Anti-patterns

The primary failure mode is **running self-audit only at release time**. By then, violations have accumulated and the fix-list is overwhelming. The cure: run per-commit (via pre-commit hook or CI) so violations are caught when they're one-line fixes, not architectural debt.
