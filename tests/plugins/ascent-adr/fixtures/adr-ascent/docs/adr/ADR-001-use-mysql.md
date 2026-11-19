# ADR-001: Use MySQL for persistent data

**Status:** Superseded by ADR-003
**Date:** 2026-01-10 (America/New_York)
**Decider:** platform lead

## Context

The service needs a relational store.

## Decision

We use MySQL for all persistent data.

## Alternatives considered

- Keep the current approach: rejected because it does not meet the load we expect.
- A managed service from another provider: rejected because the team has no experience with it.

## Consequences

- Easier: one way to do it.
- Harder: moving away later costs a migration.

## Cost implications

- Time: two weeks.
- Money: no direct cost.
