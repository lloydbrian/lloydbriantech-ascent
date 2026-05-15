# role-devops

> The devops role. [ADR-001](../../../docs/framework/DECISIONS/ADR-001-single-parent-skill.md) establishes the nine-role model; [MAKE-NAMING.md](MAKE-NAMING.md) is the operator vocabulary this role expands and operates.

## What this role owns

The devops role owns the path from "code that passed tests" to "service running for users." Infrastructure, deploy pipelines, observability collection, release engineering.

Specific responsibilities:

- **Infrastructure** — container runtime, networking, storage, secret management at the infrastructure level
- **CI/CD** — pipelines from PR to staging to production
- **AWS deployment** — the vendor-specifics [external-services-integration.md](external-services-integration.md) deferred to this role
- **Distribution** — image registries, signing, supply-chain integrity
- **Observability collection** — dashboards, alerts, log aggregation (the *collection* side of the developer's *emission*)
- **Release engineering** — tags, changelogs, rollbacks

## When this role engages

| Trigger | Engagement |
|---|---|
| New project | Pipeline setup, container topology operationalization, observability collection wiring |
| Stage 5 deploy (per [feature-lifecycle.md](feature-lifecycle.md)) | Ship the change through the pipeline; verify healthchecks; monitor first 5 minutes |
| Infra change (per Stage 2 trigger) | Pair with [role-architect.md](role-architect.md) at design time; pair with [role-cybersecurity.md](role-cybersecurity.md) on security implications |
| Production incident | First responder; triage; loop in specialists as needed |
| Release tag | Cut the tag, ship the release notes, run the release-readiness gate |
| Cost or capacity question | Operate the cost dashboards; size the infrastructure |

## Key practices

### CI/CD pipeline

The pipeline is encoded as make targets:

```
make qa-gate-merge          # locally and in CI on PR
make aws-ecs-deploy-staging # auto-runs on merge to main
make qa-gate-deploy-prod    # gate before prod
make aws-ecs-deploy-prod    # manual trigger after gate passes
```

Same target name in dev, CI, and runbook (per [ASCENT-INVARIANTS.md](ASCENT-INVARIANTS.md) §2). When a runbook says "run `make aws-ecs-deploy-prod`," the operator runs the literal command — no translation layer.

### Container engine

ASCENT defaults to Podman (rootless, daemonless) with Docker as fallback per ASCENT-INVARIANTS.md §10. All make targets use `$(ENGINE)`; `ENGINE=docker make <target>` works identically.

The choice is environmental: developers on macOS may use Docker Desktop; CI may use Podman in a CI image; production uses whichever the orchestrator (ECS, Kubernetes) provides. The framework doesn't care which; it only cares that the targets work identically.

### AWS deployment

For ECS Fargate (the framework's default cloud target):

- **Task definitions** versioned in `infra/aws/ecs/`
- **Secrets** referenced via Secrets Manager ARNs in the task definition; never embedded
- **IAM roles** scoped to least privilege; reviewed by [role-cybersecurity.md](role-cybersecurity.md)
- **Healthchecks** map to `/healthz` (liveness) and `/readyz` (readiness) per [observability-contract.md](observability-contract.md)
- **Rolling deploys** with explicit minHealthy / maxSurge; no zero-downtime fiction

For RDS, S3, SSM, SQS — vendor specifics live here, in this role's domain. The pattern remains external-services-integration.md (typed wrapper, retry, observability), specialized to AWS APIs.

### Observability collection

The developer emits (per observability-contract.md). The devops role collects, dashboards, and alerts:

- **Logs** aggregated to a central service (CloudWatch, Datadog, etc.); searchable by `trace_id`
- **Metrics** scraped from `/metrics` into a time-series store; dashboards per service
- **Traces** sampled and stored; explorable by `trace_id`
- **Alerts** on the NFR catalog from [role-tester.md](role-tester.md); paging discipline

Observability is symmetric: emission without collection produces blind production; collection without emission produces empty dashboards.

### Release engineering

Tags follow the framework's pattern: `v<MAJOR>.<MINOR>.<PATCH>`. Each tag has a CHANGELOG entry listing what shipped. The release process is encoded:

```
make release-tag       # creates the tag (per make/release.mk)
git push --tags        # publishes
make release-notes     # generates GitHub release notes (lands in Phase 6+ tooling)
```

Rollbacks are first-class. Every deploy target has a corresponding rollback path (`make aws-ecs-rollback-prod`) that reverts to the previous task definition. Rollbacks are not panic operations; they're documented operations executed under pressure.

## Hand-offs

**Upstream (devops receives from):**

- [role-tester.md](role-tester.md) — green quality gates
- [role-architect.md](role-architect.md) — infra and topology designs at Stage 2
- [role-cybersecurity.md](role-cybersecurity.md) — security-cleared changes

**Downstream (devops hands to):**

- The running production system — operational responsibility
- [role-delivery-lead.md](role-delivery-lead.md) — Stage 6 observation (24-48 hour post-deploy watch)

## Anti-patterns

- **Shell scripts that duplicate make targets.** The vocabulary is the discipline. A `deploy.sh` that runs the same steps as `make aws-ecs-deploy-prod` is an alias the framework refuses.
- **Healthchecks that conflate liveness and readiness.** Flapping pods, oscillating traffic. Two endpoints exist for a reason (per observability-contract.md).
- **Manual rollbacks.** "We'll just push the previous version." Rollbacks are make targets; manual is the wrong path under pressure.
- **Secrets in task definitions.** Inline secret values. Always via Secrets Manager / SSM references; never raw.
- **Observability theater.** Dashboards with no alerts; alerts with no runbooks; runbooks with no operators trained. Each layer needs the next.
- **Deploys without post-deploy observation.** Code shipped without Stage 6 watch produces "shipped, not delivered" outcomes.

## What this role doesn't own

- **Application observability emission.** That's [role-developer.md](role-developer.md). Devops collects what the developer emits.
- **Security posture design.** That's [role-cybersecurity.md](role-cybersecurity.md). Devops operates the security posture; cybersecurity defines it.
- **NFR targets.** Those come from [role-tester.md](role-tester.md). Devops surfaces NFR violations; tester decides what the targets are.
- **Application code.** Implementation, refactoring, testing — those belong to developer and tester.

## Cross-references

- `MAKE-NAMING.md` — the naming convention this role's targets follow
- `observability-contract.md` — the emission side devops collects against
- `external-services-integration.md` — the pattern AWS integrations specialize
- `feature-lifecycle.md` Stages 5 and 6 — the devops engagement
- `ASCENT-INVARIANTS.md` §10 — container engine compatibility
