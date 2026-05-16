# Architectural Decision Records — Index

Baseline decisions for <<PROJECT_TITLE>>, scaffolded from ASCENT v<<FRAMEWORK_VERSION>> on <<SCAFFOLD_DATE>>.

These 7 ADRs represent the framework's opinionated defaults. Each is a deliberate decision with genuine alternatives that were considered and rejected. The rationale is project-specific — not "the framework said so" but "this is why this decision serves this project."

---

| # | Title | Status | Date | Summary |
|---|---|---|---|---|
| [001](ADR-001-container-first-development.md) | Container-first development | Accepted | <<SCAFFOLD_DATE>> | Dev environment is the container; `make dev-up` from a bare host |
| [002](ADR-002-backend-layering.md) | Backend layering: routes → controllers → services → storage | Accepted | <<SCAFFOLD_DATE>> | Four layers with strict downward dependency; only storage writes |
| [003](ADR-003-make-as-operator-vocabulary.md) | Make as the operator vocabulary | Accepted | <<SCAFFOLD_DATE>> | One make target per operation; same name in dev, CI, and runbooks |
| [004](ADR-004-sqlite-wal-default-database.md) | SQLite-WAL as default database | Accepted | <<SCAFFOLD_DATE>> | Zero-config, file-based, production-capable; supersede when outgrown |
| [005](ADR-005-structured-json-logging.md) | Structured JSON logging | Accepted | <<SCAFFOLD_DATE>> | pino emitting {level, ts, trace_id, msg, ctx} per observability contract |
| [006](ADR-006-dual-licensing.md) | Dual MIT/Apache-2.0 licensing | Accepted | <<SCAFFOLD_DATE>> | MIT OR Apache-2.0 at the user's option; Rust ecosystem convention |
| [007](ADR-007-phase-gated-delivery.md) | Phase-gated delivery | Accepted | <<SCAFFOLD_DATE>> | Numbered phases, explicit exit criteria, literal go-signal protocol |

---

## How to add a new ADR

1. Pick the next available number (e.g., ADR-008)
2. Create `ADR-NNN-<kebab-slug>.md` using the canonical template
3. Add a row to this index table in numeric order
4. Submit as part of the PR that implements the decision

## Supersession — the designed override path

To override a baseline ADR, write a new ADR that explicitly supersedes it:

- The new ADR's Context section starts with: "This ADR supersedes ADR-NNN."
- The superseded ADR's status changes to `Superseded by ADR-XXX`
- The superseded ADR's body is **not edited** — the original rationale is preserved as history

Example: a project outgrowing SQLite writes `ADR-008-supersede-sqlite-for-postgres.md`. ADR-004's status changes to `Superseded by ADR-008`. ADR-004's body remains immutable — future readers can trace the decision history.

Supersession is not failure. It's the system working as designed — decisions evolve when context changes.
