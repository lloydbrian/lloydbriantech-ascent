---
name: ascent-layering-check
description: >-
  Verifies that <<PROJECT_TITLE>>'s backend follows strict layering:
  routes → controllers → services → storage. Detects cross-layer
  violations (routes importing storage, controllers containing SQL,
  services using req/res) by analyzing import patterns and code structure.
  Can run standalone or as a component of ascent-self-audit's umbrella.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-layering-check

Validates that <<PROJECT_TITLE>>'s backend code follows the strict `routes → controllers → services → storage` layering from ADR-002. Catches violations that erode the architecture: a route that queries the database directly, a controller that contains business logic, a service that references HTTP concepts. Runs standalone or as a component of [ascent-self-audit](../ascent-self-audit/SKILL.md)'s umbrella audit.

## When this skill engages

- Before a commit that touches `backend/` code — "did I break the layering?"
- As a component of ascent-self-audit's comprehensive check (delegated invocation)
- During code review to validate architectural discipline
- When refactoring moves code between layers
- After adding a new endpoint, service, or storage module
- When onboarding a developer to explain the layering rules with live validation

## Inputs

- **Backend source directory** — defaults to `backend/`; can be overridden if the project uses a different path
- **File filter** (optional) — specific files or directories to focus on; when absent, checks the entire backend tree
- **Invocation mode** — standalone (full output with guidance) or component (structured PASS/FAIL for umbrella aggregation)

## Outputs

- **Layering report** — each rule checked with PASS or FAIL status
- **Per-violation detail** — the specific import path, the file and line number, and the corrective action
- **Summary line** — "N/M layering checks passing" where M is the total number of checks executed
- **Exit code** — 0 if all checks pass, 1 if any check fails (enables script composition)

## Operational logic

The skill executes these checks in order. Each check produces PASS or FAIL with a specific message. Step numbers are local to this skill.

### Step 1 — Verify backend directory exists

**Condition:** `backend/` directory exists and contains at least one `.js` or `.ts` file.

**Action on PASS:** Proceed to Step 2.

**Action on FAIL:** Report "backend/ directory not found or empty — cannot verify layering." Exit with summary "0/0 checks (no backend to verify)."

**Fallback:** If the project uses a non-standard backend path, check `.ascent-meta.json` for a `backend_path` override before failing.

### Step 2 — Verify four-layer directory structure

**Condition:** All four directories exist: `backend/routes/`, `backend/controllers/`, `backend/services/`, `backend/storage/`.

**Action on PASS:** Report "Layer directories present: routes/, controllers/, services/, storage/."

**Action on FAIL:** Report which directories are missing. Example: "FAIL: backend/services/ directory missing — the services layer is required for business logic separation."

**Fallback:** Tolerate additional directories (e.g., `backend/middleware/`, `backend/observability/`) — these are outside the four-layer model and don't violate it.

### Step 3 — Check routes import only controllers

**Condition:** Every `import` or `require` statement in `backend/routes/*.js` references only modules from `../controllers/` (or `../middleware/`, which is permitted). No imports from `../services/`, `../storage/`, or database libraries.

**Action on PASS:** Report "Routes import only controllers — PASS."

**Action on FAIL:** For each violation, report the file, line number, and the import target. Example: "FAIL: routes/items.js:3 imports from '../storage/db.js' — routes must not import storage directly. Move the data access to a service, then call the service from the controller."

**Fallback:** Skip files that aren't JavaScript/TypeScript (e.g., README.md in routes/).

### Step 4 — Check controllers import only services

**Condition:** Every import in `backend/controllers/*.js` references only modules from `../services/` (or `../middleware/`). No imports from `../storage/`, `../routes/`, or database libraries. No `req.body` manipulation beyond validation — controllers validate and shape, they don't compute.

**Action on PASS:** Report "Controllers import only services — PASS."

**Action on FAIL:** Report each violation with file, line, and import target. Example: "FAIL: controllers/items.js:5 imports from '../storage/items.js' — controllers must not access storage directly. The storage call belongs in the service layer."

### Step 5 — Check services import only storage

**Condition:** Every import in `backend/services/*.js` references only modules from `../storage/` (or standard library / external packages). No imports from `../routes/`, `../controllers/`, `express`, or any HTTP-related module. No references to `req`, `res`, `next`, or HTTP status codes.

**Action on PASS:** Report "Services import only storage and have no HTTP concepts — PASS."

**Action on FAIL:** Report each violation. Example: "FAIL: services/items.js:2 imports 'express' — services must not know about HTTP. If you need request context, pass it as a plain object from the controller."

### Step 6 — Check storage contains no business logic

**Condition:** Files in `backend/storage/*.js` contain only database operations (SQL queries via `.prepare()`, `.exec()`, `.run()`, `.get()`, `.all()`). No imports from `../services/`, `../controllers/`, or `../routes/`. No conditional business logic (if/else that isn't error handling).

**Action on PASS:** Report "Storage contains only data access — PASS."

**Action on FAIL:** Report each violation. Example: "FAIL: storage/items.js:15 contains business logic (conditional price calculation) — move this to services/items.js. Storage should only execute queries."

### Step 7 — Check no SQL outside storage

**Condition:** No file outside `backend/storage/` contains SQL-related calls (`.prepare()`, `.exec()`, `.run()`, `.get()`, `.all()` on a database object, or raw SQL strings).

**Action on PASS:** Report "SQL operations confined to storage layer — PASS."

**Action on FAIL:** Report each violation. Example: "FAIL: controllers/items.js:20 calls db.prepare() — SQL must only appear in storage/ modules. Create a storage function and call it from the service layer."

### Step 8 — Aggregate and report

Collect all PASS/FAIL results from Steps 2-7. Report summary: "6/6 layering checks passing" or "4/6 layering checks passing (2 violations found)."

In component mode (invoked by ascent-self-audit): return structured result `{skill: "ascent-layering-check", passed: N, total: M, violations: [...]}`.

In standalone mode: print the full report with guidance for each violation.

## Examples

### Example 1 — Clean layering (all checks pass)

**Input state:** A backend with `routes/items.js` importing from `../controllers/items.js`, controllers importing from `../services/items.js`, services importing from `../storage/items.js`, storage using `better-sqlite3` queries.

**Skill output:**
```
ascent-layering-check: 6/6 checks passing
  PASS: Layer directories present
  PASS: Routes import only controllers
  PASS: Controllers import only services
  PASS: Services import only storage (no HTTP concepts)
  PASS: Storage contains only data access
  PASS: SQL operations confined to storage layer
```

### Example 2 — Route imports storage directly

**Input state:** `routes/items.js` line 3: `import { getDb } from '../storage/db.js'`

**Skill output:**
```
ascent-layering-check: 5/6 checks passing (1 violation)
  PASS: Layer directories present
  FAIL: Routes import only controllers
    → routes/items.js:3 imports '../storage/db.js'
    → Fix: move the database call to services/items.js, call from controllers/items.js
  PASS: Controllers import only services
  PASS: Services import only storage (no HTTP concepts)
  PASS: Storage contains only data access
  PASS: SQL operations confined to storage layer
```

### Example 3 — Service uses req/res (HTTP concept leak)

**Input state:** `services/items.js` line 8: `import { Request } from 'express'`

**Skill output:**
```
ascent-layering-check: 5/6 checks passing (1 violation)
  ...
  FAIL: Services import only storage (no HTTP concepts)
    → services/items.js:8 imports 'express'
    → Fix: services must not reference HTTP. Pass needed context as plain objects from controllers.
  ...
```

### Example 4 — Empty backend (edge case)

**Input state:** `backend/` directory exists but contains no `.js` files.

**Skill output:**
```
ascent-layering-check: 0/0 checks (no backend to verify)
  backend/ directory exists but contains no source files.
```

### Example 5 — Missing services directory

**Input state:** Backend has `routes/`, `controllers/`, `storage/` but no `services/` directory.

**Skill output:**
```
ascent-layering-check: 0/6 checks passing (1 structural violation)
  FAIL: Layer directories present
    → backend/services/ directory missing — the services layer is required for business logic separation
  (remaining checks skipped — directory structure must be valid first)
```

## Anti-patterns

### Anti-pattern 1 — "Just this once" exceptions

A developer adds a database query in a controller "because it's simpler for this one case." The layering erodes silently. **Why it's tempting:** the four-file ceremony feels heavy for a simple CRUD operation. **What to do instead:** accept the ceremony. If the layering genuinely doesn't serve the use case, write an ADR superseding the rule for that specific module — don't suppress the check.

### Anti-pattern 2 — Business logic in storage

A storage module that filters results, calculates derived fields, or applies access-control rules. **Why it's tempting:** the SQL query can do the filtering, so why not put the logic there? **What to do instead:** keep storage as pure data access. Filtering and computation belong in services. The boundary is: "does this line exist because of a business rule or because of a database operation?"

### Anti-pattern 3 — HTTP concepts in services

A service function that accepts `req` as a parameter or returns an HTTP status code. **Why it's tempting:** passing `req` avoids extracting the fields the service needs. **What to do instead:** extract the needed fields in the controller, pass them as plain arguments to the service. The service should work identically whether called from an HTTP handler, a CLI script, or a test.

### Anti-pattern 4 — Skipping the check on "minor" changes

Not running layering-check because "I only changed one line." Layering violations are often one-line changes that accumulate. **What to do instead:** run per-commit, either via pre-commit hook or as part of `make qa`. The check is fast (static file analysis) and the cost of skipping is architectural drift.

### Anti-pattern 5 — Suppressing violations with wrapper modules

Creating a `backend/utils/db-helper.js` that wraps storage functions, then importing it from controllers to bypass the "controllers can't import storage" rule. **Why it's tempting:** the helper isn't technically in `storage/`. **What to do instead:** the check should catch this (Step 7 validates SQL confinement regardless of directory). If the pattern is genuinely needed, it's a services-layer function, not a utility.
