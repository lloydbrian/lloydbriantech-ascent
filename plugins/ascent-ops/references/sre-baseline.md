# SRE baseline

What every service needs before it can be operated by someone who did not build it. `ops-review` Step 2 checks each item against the `ops:` section of the project contract.

## Health endpoints

| Endpoint (default) | Contract key | Answers | Must not |
|---|---|---|---|
| `/-/health` | `ops.health_path` | liveness: the process runs and answers | check the database or any other dependency; a restart cannot fix a dependency |
| `/-/ready` | `ops.ready_path` | readiness: dependencies reachable, migrations applied, warm-up done; 503 otherwise | be skipped by the load balancer or orchestrator |
| `/-/started` | `ops.started_path` (optional) | startup: warm-up finished; the orchestrator holds the liveness probe until it passes | be required when the start is fast |

- The `/-/` prefix is reserved for operational endpoints, so they cannot collide with application routes and one proxy rule can keep them off the public edge.
- The `z`-suffixed names are not ASCENT defaults. A project that keeps `/healthz` and `/readyz` sets them in the contract; with no override they are a Low finding ("non-default paths with no contract override").
- Every probe uses the contract paths: the Dockerfile `HEALTHCHECK`, the Compose `healthcheck`, the ECS container `healthCheck`, the load balancer target group and the Kubernetes probes. A probe on another path is the same Medium finding as a missing endpoint.
- Both endpoints are unauthenticated, fast (under 10 ms) and logged at debug level only.

## Service levels and alerts

- An SLO names a measurable target and a window (`availability 99.5% over 30 days`, `p95 latency under 300 ms`). No SLOs in the contract makes the health lens unmeasured.
- Every alert names the runbook that answers it (`ops.alerts[].runbook`), and that runbook exists. An alert without a runbook is noise at 3 a.m.
- Alert on symptoms users feel (error rate, latency, readiness), not on every cause.

## Versions

Everything that runs is pinned (`ops.version_pinning`):
- images to a tag or digest, never `:latest`, no tag or a tag that names no version (`:alpine`, `:stable`); a Compose service with `build:` names its own build output
- packages and tools to exact versions, never `@latest`
- Terraform providers with an exact version, or `~>` under `version_pinning: minor`; modules with a version or `?ref=`
- GitHub Actions to a release tag or a commit, never a branch (under `exact`, a full release or a commit, not `@v4`)
- no `curl … | sh` installers without a pinned version and a checksum

`check-ops-scripts.sh` (Z8) enforces the `minor` floor: it accepts `~>` and `@v4`. Under `exact` (the default), read the provider constraints and action refs it passed and report ranges and major-version tags as Z8.

## Change and recovery

- **Deploy** from a runbook (see [runbook-standard.md](runbook-standard.md)) with pre-flight and post-flight checks.
- **Rollback** is a documented, rehearsed operation: a make target or script that restores the previous release. No rollback path for production is a High finding.
- **Backup and restore**: what is backed up, how often, how long it is kept, and the date of the last restore test.
- **Drift**: a scheduled drift check (S9), so a change made by hand is found within a week.
