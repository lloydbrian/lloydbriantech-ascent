---
name: ascent-layering-check
description: >-
  Verifies that <<PROJECT_TITLE>>'s backend follows strict layering:
  routes → controllers → services → storage. Detects cross-layer
  violations (routes importing storage, controllers containing SQL,
  services using req/res) by analyzing import patterns and code structure.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-layering-check

Validates that <<PROJECT_TITLE>>'s backend code follows the strict `routes → controllers → services → storage` layering from ADR-002. Catches violations that erode the architecture: a route that queries the database directly, a controller that contains business logic, a service that references HTTP concepts.

## When this skill engages

- Before a commit that touches backend/ code — "did I break the layering?"
- As a component of [ascent-self-audit](../ascent-self-audit/SKILL.md)'s comprehensive check
- During code review to validate architectural discipline
- When refactoring moves code between layers

## Inputs

- The backend source directory (defaults to `backend/`)
- Optional: specific files or directories to focus on

## Outputs

- A layering report: each rule marked PASS or FAIL
- For each FAIL: the specific violation (import path, code pattern), the file/line, and the corrective action
- Rules checked: routes import only controllers, controllers import only services, services import only storage, storage imports no application modules

## Operational logic

The skill reads import/require statements across the four layer directories and validates the dependency direction. The dependency arrow points strictly downward: routes → controllers → services → storage. A route file importing from `../storage/` is a violation. A service file importing `express` or referencing `req`/`res` is a violation. A storage file importing from `../services/` is a violation. The check also validates that only the storage layer contains SQL (prepared statements, `.prepare()`, `.exec()` calls). The full import-graph analysis and edge-case handling (shared utilities, test files, config) lands in Phase 3.

## Examples

Examples land in Phase 3. Each example will show a specific cross-layer violation, the check's output, and the corrective refactoring.

## Anti-patterns

The primary failure mode is **allowing "just this once" exceptions without ADRs** — a developer adds a database query in a controller "because it's simpler for this one case" and the layering erodes silently. The check should fail loudly on ANY cross-layer import, regardless of the developer's intent. If the exception is genuinely needed, the fix is an ADR superseding the layering rule for that specific case — not a suppressed check.
