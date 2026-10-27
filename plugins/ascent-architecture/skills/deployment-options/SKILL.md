---
name: deployment-options
description: >-
  Use when deciding "how should we deploy this?", "what will it cost to run?",
  "serverless or containers?", "how much setup and maintenance?", or when
  architecture-review finds no IaC or no recorded deployment decision. Compares
  deployment options by setup effort, dated monthly cost estimate, operations
  burden and maturity fit, recommends one, drafts the ADR, and hands over a
  blueprint the operator deploys. Read-only.
version: 0.1.2
allowed-tools: Read, Grep, Glob
---

# deployment-options

Helps the builder choose a deployment architecture with eyes open: what it takes to set up, what it costs to run each month, what it takes to keep running, and how close it gets to the enterprise maturity target. It is a sibling of [architecture-review](../architecture-review/SKILL.md) and uses its severity table and contract.

Shared sources: [architecture-principles.md](../../references/architecture-principles.md), [cloud-component-mapping.md](../../references/cloud-component-mapping.md), the pricing files in `pricing/` and the blueprints in `blueprints/`. The plugin's read-only scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads); below, `PLUGIN_ROOT` means that directory: `PLUGIN_ROOT="<skill base directory>/../.."`.

If `engineering:architecture` is installed, use it to format the ADR in Step 5. This skill supplies the options, numbers and ASCENT conventions (decision 5).

## Rules

- **Every cost figure carries its source and date**: the pricing file's `as_of`, or the live page URL and the date you read it. No undated numbers, no numbers from memory.
- **Estimates, not quotes.** Say so next to every total.
- **Claude never deploys.** The blueprint's deploy steps go into the operator's runbook; with `ascent-delivery` enabled, its hook blocks deploy commands for Claude anyway.
- **No account ids, emails or credentials** in outputs. Runbooks declare them as shell variables at run time.
- **Propose, don't write.** Contract changes, runbooks and ADR drafts are shown to the operator, who commits them.
- **Everything in the report.** The report itself carries the usage profile, the script's `TOTAL`, `FLAT-RATE`, `NOTE` and `WARN` lines verbatim, and the full ADR draft text. A copy may also go to the session scratchpad, never into the repository; a file path alone is not showing it.
- **If Bash is unavailable or declined**, report the cost as "not estimated: script not run" and apply the template checks by reading; never invent script output.

## Options catalog

| Id | Option | Typical fit | Fixed monthly floor | Setup effort | Ops burden |
|---|---|---|---|---|---|
| O1 | Static site on S3 + CloudFront | Content with no server logic | under 1 USD (the Route 53 zone is 0.50 USD) | hours | very low: no servers |
| O2 | O1 + serverless API (API Gateway HTTP API + Lambda + DynamoDB) — **blueprint `static-site-serverless-aws`** | Sites with forms, scores, light CRUD; spiky or low traffic | under 1 USD at small scale (blueprint estimate) | half a day | low: runtime upgrades yearly |
| O3 | Serverless containers (ECS on Fargate + Application Load Balancer) | Long-running requests, custom runtimes, steady traffic | load balancer and at least one task run all month | one to two days | medium: images, patching base images, scaling rules |
| O4 | Single virtual machine (EC2 or Lightsail) | Legacy apps, fixed IP, very steady small load | the instance runs all month | a day | high: OS patching, backups, monitoring, no failover |
| O5 | Kubernetes (EKS) | Organizations that already run a platform team | cluster control plane plus nodes | days to weeks | very high unless a platform team owns it |

The pricing file covers O1 and O2 only (decision C). For O3–O5, look the prices up live and label them, or state "not estimated: outside the pricing file" — never fill in a number from memory.

**Variants.** When one component of a catalog option does not fit (for example relational data where O2 has DynamoDB), name the variant `O<n>′`, state the swap and why, price the swapped component live with its source and date (it is outside the pricing file), and in Step 6 say which C-checks become N/A for the adapted template. Swapping more than one component is a different option: describe it with [cloud-component-mapping.md](../../references/cloud-component-mapping.md) instead.

## Steps

### Step 1 — Requirements

From the contract (`architecture:`), the code and the docs, list the deciding requirements: request duration, protocols (HTTP, WebSocket), state and data model, traffic shape (steady, spiky, idle), peak load, latency and availability targets, data residency, team skills, and the budget. Mark each as stated or inferred. With no contract, detect targets and the budget with the list in architecture-review Step 0 (docs, AGENTS.md, CLAUDE.md, the delivery contract, and script defaults such as budget thresholds), so both skills give the same answer for the same repository.

### Step 2 — Shortlist

Eliminate options that break a requirement, with the reason (O2 is out for 20-minute jobs: Lambda's limit is 15 minutes). Keep two or three. If nothing in the catalog fits, say so and describe the nearest pattern with [cloud-component-mapping.md](../../references/cloud-component-mapping.md); do not force a blueprint.

### Step 3 — Cost estimate

1. **Usage profile.** Use the contract's `usage_profile` if it exists. Otherwise copy the blueprint's `usage-small.tsv` shape, fill in quantities from what the repository and docs say (visitors, API calls, data size), and mark every guessed row. Show the profile to the operator.
2. **Live check (when web access is available).** For each priced row the profile uses, read the source URL in the pricing file. If a price differs, use the live price, cite the URL and today's date, and tell the operator the pricing file needs a refresh (a plugin change with a version bump).
3. **Run the estimate:**

```bash
bash "$PLUGIN_ROOT/scripts/estimate-cost.sh" \
  "$PLUGIN_ROOT/pricing/aws-us-east-1.tsv" <usage.tsv> \
  --plans "$PLUGIN_ROOT/pricing/aws-cloudfront-flat-rate.tsv"
```

  Add `--no-free-tier` when the account's always-free allowances are already used by other workloads. Add `plan_needs_<feature> 1` rows to the profile for CloudFront features the design uses (`access_logs`, `custom_response_headers`), so the flat-rate comparison only picks a plan that supports them. Report the `TOTAL`, the `FLAT-RATE` and `NOTE` lines and any `WARN` verbatim. A `WARN` about stale pricing means the live check in step 2 is required before the number is used for a decision. Exit code 2 means the profile has a key the pricing file does not price: fix the profile, never drop the line.
4. **Show the drivers**: the three largest lines, and what doubling traffic does to the total.

### Step 4 — Setup and operations effort

For each shortlisted option, state: one-time setup (accounts, certificates, DNS, IaC, CI), recurring work (patching, runtime upgrades, certificate renewals, backup tests, cost reviews), and on-call exposure. Compare against the maturity target in section 5 of [architecture-principles.md](../../references/architecture-principles.md): which items the option meets out of the box, and which need work or a waiver.

### Step 5 — Recommendation and ADR draft

Recommend one option with the deciding reasons, and draft an ADR (Context, Decision, Alternatives considered, Consequences, Cost implications) for the operator to commit in `adr_dir`. The Cost implications section carries the Step 3 total with its `as_of` date and the Step 4 effort. List every enterprise item the choice skips as a proposed waiver.

### Step 6 — Blueprint hand-off

If the recommendation matches a blueprint, point to it ([static-site-serverless-aws](../../blueprints/static-site-serverless-aws/README.md)) and:

1. Run the mechanical checks on the blueprint, or on the project's adapted copy, and include the output:

```bash
bash "$PLUGIN_ROOT/scripts/check-cfn-static-site.sh" <template.yaml>
```

2. Propose the operator's runbook steps from the blueprint README's deploy section (with `ascent-delivery`, in its Step 6 format), with values declared as shell variables. The runbook does the dry run (change set) before any change.
3. Propose the deploy commands for `deploy_prod` (or `deploy_beta`) in the delivery contract, so the operator-boundary hook knows them. The operator adds and commits them.

## Report

The first line is always the `deployment-options: recommend` line.

```
deployment-options: recommend <Oid> — <one-line reason>
Requirements (Step 1): <stated / inferred list>
Shortlist (Step 2): <ids, and eliminated ids with reasons>
Cost (Step 3): <usage profile in full, guessed rows marked; script TOTAL, FLAT-RATE, NOTE and WARN lines verbatim;
                option: total USD/month, as_of or live source+date; drivers>
Effort (Step 4): <option: setup | recurring | on-call | maturity gaps>
ADR draft (Step 5): <path proposed, full text>
Blueprint (Step 6): <id, check output, runbook location>
```

## What this skill does not do

- Deploy, create accounts, or call cloud APIs. The operator runs the runbook.
- Give a cost figure without a dated source, or present an estimate as a quote.
- Choose for the operator when two options are close: it lays out the trade-off and recommends; the operator decides and the ADR records it.
