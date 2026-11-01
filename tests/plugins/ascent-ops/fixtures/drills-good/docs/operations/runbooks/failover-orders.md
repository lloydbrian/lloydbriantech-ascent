# Runbook: failover drill for orders

Purpose: failover drill for orders, in a non-production environment.

## Pre-flight

1. Check the current state.

   **Expect:** healthy.
   **Stop if:** anything is unhealthy.

## Steps

1. Run the drill.

   **Expect:** the service answers readiness.
   **Stop if:** it does not within the target.

## Post-flight

Write the drill record.

## Rollback

Undo the drill. **Expect:** the previous state. **Stop if:** it does not return.
