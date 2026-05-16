# ADR-002: Backend layering — routes → controllers → services → storage

**Status:** Accepted
**Date:** <<SCAFFOLD_DATE>> (America/New_York)
**Decider:** <<BRAND>> · ASCENT v<<FRAMEWORK_VERSION>> baseline

## Context

<<PROJECT_TITLE>>'s backend runs inside a container per [ADR-001](ADR-001-container-first-development.md). Within that container, the Express server needs a code-organization pattern that prevents the gravitational pull toward god classes — services where SQL lives in the route handler, business logic leaks into the controller, and three storage abstractions fight each other.

Without explicit layering, every Node.js Express project follows a predictable decay path: a route file starts small, accumulates validation logic, then database queries, then business rules, until it's 500 lines of tangled concerns that no one wants to refactor because everything depends on everything.

## Decision

<<PROJECT_TITLE>> organizes its backend code into four strictly-layered directories:

```
routes/          → registers HTTP method + path; calls the controller
controllers/     → validates input, shapes response; calls services
services/        → business logic, orchestration; calls storage
storage/         → SQL queries; the only layer that writes data
```

The rules:

1. **Routes register only.** A route file maps a method+path to a controller function. No validation, no logic, no SQL.
2. **Controllers validate and shape.** They receive the request, validate input, call a service, and shape the response. They contain zero business logic and zero SQL.
3. **Services own business logic.** They generate IDs, apply business rules, orchestrate multiple storage calls. They know nothing about HTTP (no `req`, no `res`, no status codes).
4. **Storage is SQL only.** Parameterized queries. No business logic, no HTTP concepts. The only layer that writes to the database.

Cross-layer calls are forbidden. A route calling storage directly is a violation. Storage calling a service is a violation. The dependency arrow points strictly downward.

## Alternatives considered

**Flat file structure (one file per route with all logic inline).** Rejected because this is the structure that produces the 500-line god-class decay. Works for toy projects; breaks at production scale.

**Model-View-Controller (MVC).** Rejected because MVC conflates "model" (data shape) with "storage" (persistence) and "controller" (request handling) with "business logic." The three-folder MVC pattern doesn't prevent controllers from becoming god classes.

**Hexagonal / ports-and-adapters.** Rejected as over-engineered for the project's scope. Hexagonal architecture pays off for systems with many external integrations and complex domain logic. <<PROJECT_TITLE>>'s initial scope doesn't warrant the abstraction overhead of ports, adapters, and dependency inversion at every boundary.

**Single service module (thin controller, fat service).** Rejected because it moves the god-class problem from controllers to services. The four-layer split distributes responsibility more evenly and makes each layer independently testable.

## Consequences

**Easier:**

- Each layer is independently testable (mock the layer below)
- New developers know where code belongs by asking "what does this code do?" — validation goes in controllers, logic in services, SQL in storage
- Refactoring a service doesn't touch routes or storage — concerns are isolated
- Code review is focused — a PR touching `storage/` is about data; touching `controllers/` is about input handling

**Harder:**

- Simple CRUD requires four files (route + controller + service + storage) even when the logic is trivial — some ceremony for simple operations
- Developers new to the pattern may initially feel the layering is "too much" for a small feature — the discipline pays off at scale, not at hello-world
- Cross-layer communication requires explicit function calls — no shortcut where a controller directly queries the database "just this once"

**Neutral:**

- Testing strategy maps naturally: unit tests mock the layer below; integration tests use real storage; e2e tests use the full stack

## Cost implications

**Time:** Slightly more files per feature (4 instead of 1-2). Each file is smaller and focused. Net time is comparable; debugging time decreases because concerns are isolated.

**Complexity:** Low structural complexity (four directories, one rule: "call down, never up"). Higher than a flat structure but dramatically lower than the unstructured alternative at scale.

**Future flexibility:** The layering supports swapping storage backends (SQLite → Postgres) by changing only the storage layer. Controllers and services don't know the database engine.

**Money:** None.
