# ADR-003: Use PostgreSQL for persistent data

**Status:** Accepted
**Date:** 2026-03-02 (America/New_York)
**Decider:** platform lead

## Context

This ADR supersedes ADR-001: Use MySQL for persistent data. JSON queries became central.

## Decision

We use PostgreSQL for all persistent data; no other database client is used.

## Alternatives considered

- Keep the current approach: rejected because it does not meet the load we expect.
- A managed service from another provider: rejected because the team has no experience with it.

## Consequences

- Easier: one way to do it.
- Harder: moving away later costs a migration.

## Cost implications

- Time: two weeks.
- Money: no direct cost.
