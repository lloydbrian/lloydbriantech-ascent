# ADR-004: SQLite-WAL as default database

**Status:** Accepted
**Date:** <<SCAFFOLD_DATE>> (America/New_York)
**Decider:** <<BRAND>> · ASCENT v<<FRAMEWORK_VERSION>> baseline

## Context

<<PROJECT_TITLE>> needs a database from Day 1 to demonstrate the storage layer (per [ADR-002](ADR-002-backend-layering.md)). The choice of database engine affects developer experience (setup complexity), operational cost (infrastructure to maintain), and future flexibility (migration path when the project outgrows the default).

The project stores its data at `data/<<PROJECT_SLUG>>.sqlite` inside the backend container, persisted via a named Docker volume (`<<VOLUME_DATA>>`). This means the database travels with the development environment — no external server process, no connection string to configure, no credentials to manage at this stage.

## Decision

<<PROJECT_TITLE>> uses SQLite in WAL (Write-Ahead Logging) mode as its default database. The database file lives at `data/<<PROJECT_SLUG>>.sqlite` with the following PRAGMA configuration:

```sql
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
PRAGMA foreign_keys = ON;
```

Migrations are tracked in a `_migrations` table and applied automatically on server boot from `.sql` files in `storage/migrations/` sorted by filename.

This is the **most likely ADR to be superseded**. Projects that need Postgres, MySQL, or another database engine write `ADR-008-supersede-sqlite-for-postgres` (or similar) explaining the trigger and the migration plan. The storage layer's interface (`listAll`, `insertOne`, etc.) is database-agnostic; switching engines affects only `storage/db.js` and the migration files.

## Alternatives considered

**PostgreSQL.** The industry-standard relational database. Rejected as the Day 1 default because it requires a separate server process (container), connection credentials, schema initialization outside the application, and operational knowledge (vacuuming, connection pooling, backup scheduling) before the first feature ships. Postgres is the right choice when the project needs concurrent multi-process writers, advanced indexing (GIN, GiST), or multi-machine replication. The supersession path is designed for this.

**MySQL / MariaDB.** Another server-based relational database. Rejected for the same reasons as Postgres — server process, credentials, operational overhead — plus the additional consideration that MySQL's ecosystem is less standardized than Postgres's for Node.js tooling.

**MongoDB.** A document database. Rejected because <<PROJECT_TITLE>>'s data model (items with structured fields) is relational. MongoDB excels for schema-flexible document stores; using it for structured relational data fights the tool's design.

**In-memory only (no persistence).** Store data in a JavaScript Map; lose everything on restart. Rejected because persistence is a requirement for demonstrating the storage layer meaningfully. An in-memory store would make the development environment feel broken every time the container restarts.

## Consequences

**Easier:**

- Zero configuration — `make dev-up` produces a working database with no external dependencies
- No credentials needed — the database is a file; no username/password/connection-string ceremony
- Schema migrations run automatically on boot — no separate migration step
- Backup is `cp data/<<PROJECT_SLUG>>.sqlite backup.sqlite` — trivial
- Testing uses in-memory SQLite (`:memory:`) for speed and isolation
- WAL mode allows concurrent readers during writes — adequate for single-service workloads

**Harder:**

- **Single-writer concurrency.** SQLite allows only one writer at a time (WAL mode helps with readers, but writers serialize). Projects with concurrent write-heavy workloads (multiple backend replicas) will hit `SQLITE_BUSY` errors even with `busy_timeout`. This is the primary trigger for superseding to Postgres.
- **No multi-machine deployment.** SQLite is a file on one filesystem. Two backend containers on different machines cannot share the same SQLite file. Multi-replica deployments require a client-server database.
- **Limited advanced indexing.** No full-text search (without extensions), no JSON path indexes, no GIN/GiST equivalents. Projects needing these features supersede to Postgres.
- **No built-in replication.** No read replicas, no streaming replication, no point-in-time recovery beyond manual file copies. Production-scale data safety requires a server database with proper backup tooling.
- **Ecosystem assumptions.** Some ORMs and migration tools assume a client-server database. `better-sqlite3` is synchronous (which simplifies code) but doesn't support the async patterns that `pg` or `mysql2` use.

**Neutral:**

- The storage layer's interface is database-agnostic — superseding to Postgres changes `storage/db.js` and migration files, not the service or controller layers
- The `better-sqlite3` library is production-proven for single-service applications (many successful projects run SQLite in production at the tens-of-thousands-of-users scale)

## Cost implications

**Time:** Zero setup time on Day 1 (no database server to install, configure, or start). Positive time savings during early development. Migration time when superseding to Postgres (~1-2 days for a typical project).

**Complexity:** Minimal. One file, one PRAGMA block, one migration runner. The alternative (Postgres from Day 1) adds a database container, credentials management, connection pooling, and schema initialization — complexity that doesn't earn its keep until the project actually needs multi-writer concurrency.

**Future flexibility:** High. The supersession path is designed and documented. The storage layer's interface doesn't change; only the implementation does. Projects can start fast with SQLite and migrate to Postgres when they hit the concurrency or multi-machine boundary — and not before.

**Money:** None. SQLite is public-domain. No license fees, no server costs.
