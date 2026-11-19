# ADR-002: CloudFormation for all infrastructure

**Status:** Accepted
**Date:** 2026-01-12 (America/New_York)
**Decider:** platform lead

## Context

Infrastructure was created by hand.

## Decision

All infrastructure is defined in CloudFormation under infra/cloudformation/.

## Alternatives considered

- Keep the current approach: rejected because it does not meet the load we expect.
- A managed service from another provider: rejected because the team has no experience with it.

## Consequences

- Easier: one way to do it.
- Harder: moving away later costs a migration.

## Cost implications

- Time: two weeks.
- Money: no direct cost.
