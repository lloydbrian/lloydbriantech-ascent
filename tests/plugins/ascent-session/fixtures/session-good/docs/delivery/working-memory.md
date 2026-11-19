# Working memory — Catalog service

Accumulating decisions that persist across sessions. This file is git-tracked and append-only. Each entry records a decision, adopted pattern, or rejected pattern with a date.

---

## Decisions

- 2026-10-02: Prices are stored in cents as integers; never floats.
- 2026-10-09: The catalog API is read-only for anonymous users.
- 2026-11-12: Search uses Postgres full-text search until it needs more (see ADR-004).

## Patterns adopted

- 2026-10-05: Every handler validates its input with the shared schema module.

## Patterns rejected

- 2026-10-20: A cache in front of the catalog: rejected, the queries are fast enough.
