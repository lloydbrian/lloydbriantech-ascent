---
name: ascent-cost-posture
description: >-
  Cloud cost discipline check for <<PROJECT_TITLE>>. Provider-agnostic
  analysis of resource declarations, data retention documentation, and
  infrastructure-as-code presence. Checks discipline patterns, not
  provider-specific pricing.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-cost-posture

Checks cloud cost discipline through provider-agnostic patterns. The framework's baseline is container-first (§1), not AWS-first — cost-posture checks whether resource constraints are declared in code, data retention is documented, and infrastructure-as-code is present, regardless of the target cloud provider. A project deploying to AWS gets the same checks as one deploying to GCP or self-hosted.

This skill checks discipline patterns, not provider-specific resource pricing. "Have you declared your resource constraints?" is the question, not "how much does your ECS task cost?"

This is a conditional skill — it ships only when the architect interview indicates cloud deployment. Projects that run exclusively on localhost or on-premises may not need cost-posture checks.

## When this skill engages

- Before deploying to a cloud environment for the first time
- When a developer asks "are we tracking costs?" or "what's our cost exposure?"
- As a periodic check before budget reviews
- After adding new infrastructure (new services, new data stores, new regions)

## Inputs

- **`docker-compose.yml`, `docker-compose.prod.yml`** — container resource declarations
- **`docs/` directory** — data retention documentation
- **Project root** — infrastructure-as-code directory detection (`terraform/`, `pulumi/`, `cdk/`, `serverless.yml`)
- **`.env.example`** — cost-relevant environment variables (region, instance type, retention period)

## Outputs

- **Per-check report** — each of the 4 checks marked PASS, CONCERN, or SKIP
- **Summary line** — "cost-posture: N/4 checks passing"

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Resource declarations

**Condition:** Scan `docker-compose.yml` and `docker-compose.prod.yml` for container resource limits: `mem_limit`, `cpus`, `deploy.resources.limits`, or equivalent constraint declarations.

**Action on PASS:** Report "Resource declarations — PASS. [N] services with resource limits declared."

**Action on CONCERN:** Report "Resource declarations — CONCERN. [N] services without resource limits. Undeclared limits mean unbounded cost in cloud environments."

**Fallback:** If no compose files exist, report "Resource declarations — SKIP (no compose files)."

### Step 2 — Data retention documentation

**Condition:** Scan `docs/` for files mentioning retention, backup, or lifecycle policies. Check `.env.example` for retention-related variables (e.g., `*_RETENTION_DAYS`, `*_BACKUP_*`).

**Action on PASS:** Report "Data retention — PASS. Retention documentation or configuration found."

**Action on CONCERN:** Report "Data retention — CONCERN. No retention policies documented. Unbounded data growth is a cost risk."

### Step 3 — Infrastructure-as-code presence

**Condition:** Check for IaC directories or files: `terraform/`, `pulumi/`, `cdk/`, `cloudformation/`, `serverless.yml`, `*.tf` files.

**Action on PASS:** Report "Infrastructure-as-code — PASS. [tool] detected at [path]."

**Action on CONCERN:** Report "Infrastructure-as-code — CONCERN. No IaC found. Manual infrastructure is harder to audit for cost."

**Fallback:** For projects not yet deploying to cloud (e.g., local-only development), report "Infrastructure-as-code — SKIP (no cloud deployment detected)."

### Step 4 — Aggregate and report

**Action:** Collect results from Steps 1-3. Report summary:

```
cost-posture: N/M checks passing (M = number of non-skipped checks)
```

## Examples

### Example 1 — Resource limits declared

```
cost-posture: 3/3 checks passing
  Resource declarations   PASS (3 services with limits)
  Data retention          PASS (retention docs found)
  Infrastructure-as-code  PASS (terraform/ detected)
```

### Example 2 — No resource limits

```
cost-posture: 2/3 checks passing (1 concern)
  Resource declarations   CONCERN — 3 services without resource limits
  Data retention          PASS
  Infrastructure-as-code  PASS
```

## Anti-patterns

### Anti-pattern 1 — Treating cost-posture as a billing tool

cost-posture checks whether cost-relevant constraints are declared, not what the actual bill is. **What to do instead:** use cloud provider billing dashboards for actual cost tracking. cost-posture ensures the project has the discipline to make cost predictable — declared limits, documented retention, codified infrastructure.
