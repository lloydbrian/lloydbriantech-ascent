---
name: architecture-review
description: >-
  Use when asked "review the architecture", "is this production-ready?", "what
  are the architecture risks?", or before a first production deploy or a major
  change. Maps the system, runs light surface checks for quality attributes,
  design principles, deployment and cost against the project contract, rates
  findings by severity, and recommends deeper skills only where a surface
  check flags a concern. Read-only.
version: 0.1.0
allowed-tools: Read, Grep, Glob
---

# architecture-review

One review of the whole system, judged against the project's own targets. It is the entry point of the `ascent-architecture` plugin: it runs lightweight surface checks itself, and recommends [quality-attributes](../quality-attributes/SKILL.md), [design-principles-check](../design-principles-check/SKILL.md) or [deployment-options](../deployment-options/SKILL.md) only for the areas where a surface check found something (the hybrid pattern). It never invokes them; they read the same sources.

Shared sources: [architecture-principles.md](../../references/architecture-principles.md) (principles P1–P12, Well-Architected pillars, maturity targets) and [contract-template.yml](../../references/contract-template.yml) (the `architecture:` section of `.ascent/contract.yml`). The pricing files are in `pricing/` and the blueprints in `blueprints/`, both under `PLUGIN_ROOT` (see Rules).

If `engineering:system-design` or `engineering:architecture` is installed, use them for generic design advice and ADR formatting. This skill keeps the ASCENT parts: the contract, the severity table, the maturity target and the report format (decision 5, extend don't duplicate).

## Rules

- **Read-only.** Never edit files, run deploys or call cloud APIs. Scripts named here only read files.
- **Evidence or it is not a finding.** Every finding cites a repository-relative `path/to/file:line` (never a bare file name or a directory), or "absent: searched <paths>", and a concrete failure scenario.
- **Fresh evidence.** Re-read the evidence for every finding in this run. Never carry findings over from an earlier pass, an agent's report or another session.
- **Rate only with the severity table.** A concern that matches no row goes under **Other observations (unrated)** in the report and does not count toward the rating. Never invent a severity.
- **Cite principles by their id** in [architecture-principles.md](../../references/architecture-principles.md): P1–P12 for system principles, the section 4 row name (for example "API design: idempotent writes") for software design. Cite one only when its text matches the finding.
- **Judge against the contract**, not against an ideal. A gap covered by a waiver ADR is Info, not a finding.
- **No secrets, account ids or personal data** in the report, even when a finding is about one. Cite the location.
- **Security depth belongs to `ascent-security`.** Flag what the architecture exposes (public origins, missing TLS, secrets in client code); leave credential scanning to that plugin. Security-only concerns that match no row (authorization roles, network binding, CI permissions, request size limits, identifiers in docs) go under Other observations marked `→ ascent-security`. Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`.
- **Scripts and data.** The plugin's read-only scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`. The pricing files are `$PLUGIN_ROOT/pricing/aws-us-east-1.tsv` and `$PLUGIN_ROOT/pricing/aws-cloudfront-flat-rate.tsv`; the blueprint's sample usage profile is `$PLUGIN_ROOT/blueprints/static-site-serverless-aws/usage-small.tsv`.

## Severity

Every finding carries one of these severities. The `architecture-reviewer` agent and the mechanical check script use the same table.

<!-- arch-severity:start -->
| Finding | Severity |
|---|---|
| Origin storage or database reachable from the internet without the CDN or API in front | High |
| Stateful data with no backup or point-in-time recovery, or deleted with its stack | High |
| Production resources with no infrastructure as code, at the enterprise target | High |
| Credentials or secrets in templates or client code (refer to `ascent-security`) | High |
| Public entry point with no throttling, rate limit or concurrency cap | Medium |
| No cost guardrail: no budget alert, or no dated cost estimate | Medium |
| Plain HTTP allowed, or a TLS policy older than TLSv1.2_2019 | Medium |
| No security headers policy on a public site | Medium |
| No recovery target (RTO, RPO) or no alarm routed to a person, at the enterprise target | Medium |
| Layering or coupling violation that blocks a quality target (business rules in handlers or UI, shared database) | Medium |
| Multi-step write with no transaction and no idempotency, so a failure leaves partial state (section 4, API design) | Medium |
| Log groups without retention, or no access logs at the CDN | Low |
| A quality target missing from the contract ("unmeasured") | Low |
| Any other item the maturity target requires, missing with no waiver (Step 5) | Low |
| A gap covered by a waiver ADR | Info |
<!-- arch-severity:end -->

**Rating:** **strong** — no High and no Medium; **moderate** — no High, one or more Medium; **weak** — one or more High.

## Steps

### Step 0 — Load or propose the contract

Read `.ascent/contract.yml`, or `.claude/contract.yml` where ASCENT-named files are not allowed, and use its `architecture:` section.

If it is missing, **detect, don't ask.** Propose the section from what the repository declares:

- IaC: `**/*.yaml|yml` with `AWSTemplateFormatVersion` or `Resources:` (CloudFormation), `cdk.json`, `*.tf`, `*.bicep`.
- Cloud and region: provider blocks, `--region` in scripts and CI, `aws s3 sync … s3://`, `az`, `gcloud`.
- Blueprint: S3 + CloudFront (+ API Gateway/Lambda) matches `static-site-serverless-aws`.
- Targets: SLOs or budgets in docs, AGENTS.md, CLAUDE.md or the delivery contract.

Use only the keys and values of [contract-template.yml](../../references/contract-template.yml): `maturity_target` is one of enterprise, standard or prototype (never a new value; a project that looks lighter gets `standard` or `prototype` marked `# guess`), `monthly_budget_usd` sits under `quality_targets`, and each waiver is an `id`, `skips` and `review_by`. Mark detected values with their source (`# detected: <path:line>`).

Show the proposal once, with every guessed value marked `# guess`, and ask the operator to confirm it. Write nothing; the operator commits the file. Until it is confirmed, review against the enterprise defaults and say so in the report.

### Step 1 — Map the system

Build a component inventory from the repository, not from memory:

| Component | Kind | Where defined | Data it holds | Entry points |
|---|---|---|---|---|

Include static hosting, APIs, functions, databases, queues, third-party services (search for SDK imports and outbound hostnames), DNS and CI/CD. Draw a short Mermaid flowchart of request and data paths. Mark anything deployed by hand (in docs or scripts but not in IaC).

### Step 2 — Quality attributes, surface check

For each attribute, one line: target from the contract, evidence found, and status **met**, **at risk** or **unmeasured**. An attribute whose target is missing from the contract is unmeasured, never met, however good the evidence looks; it is at risk instead when the evidence shows a gap. Say what you saw. Report these six attributes, in this order, and no others:

- **Availability and reliability:** single points of failure, health checks, retries and timeouts, RTO/RPO stated.
- **Performance and scalability:** CDN in front of static content, caching headers, scale-to-zero or autoscaling, peak load target.
- **Security:** private origins, TLS, headers, least-privilege roles, and secrets in client code: search the served HTML and JavaScript and the templates for credential-like assignments (`PIN`, `password`, `token`, `secret`, `api_key`). A hit is High per the severity table whether or not the page is published yet; give the publish status in the Scenario, never the value (depth: `ascent-security`).
- **Cost:** budget alarm, dated estimate, throttling, log retention.
- **Operability and observability:** alarms routed to a person, structured logs, build stamp, runbooks.
- **Maintainability:** layering, tests, IaC, ADRs for one-way decisions.

Two or more **at risk** or **unmeasured** attributes: recommend [quality-attributes](../quality-attributes/SKILL.md) for a scored review.

### Step 3 — Design principles, surface check

Sample the main code paths (entry points, one handler or route per area, data access). Check the software principles in section 4 of [architecture-principles.md](../../references/architecture-principles.md): separation of concerns, coupling, configuration in the environment, stateless processes, idempotent writes, error handling. Any Medium finding here: recommend [design-principles-check](../design-principles-check/SKILL.md).

### Step 4 — Deployment and cost, surface check

- Is every production resource in IaC? Which templates?
- For a CloudFormation YAML template on the static-site pattern, run the mechanical checks and include their output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-cfn-static-site.sh" <template.yaml>
```

  Each `FAIL` line is a finding with the severity it prints. `N/A` lines are not findings. The checks map to the severity table like this (the plugin's tests keep this table, the script header and the script output identical):

  | Check | Severity | Table row |
  |---|---|---|
  | C1 | High | Origin storage reachable without the CDN |
  | C2 | High | Origin storage reachable without the CDN |
  | C3 | Medium | Plain HTTP allowed |
  | C4 | Medium | TLS policy older than TLSv1.2_2019 |
  | C5 | High | Origin storage reachable without the CDN |
  | C6 | Medium | No security headers policy |
  | C7 | High | Stateful data deleted with its stack |
  | C8 | High | Stateful data with no point-in-time recovery |
  | C9 | Low | Log groups without retention |
  | C10 | Medium | Public entry point with no throttling |
  | C11 | Medium | No cost guardrail |
  | C12 | Low | No access logs at the CDN |

  If Bash is unavailable or the operator declines it, apply C1–C12 by reading the template and say "checks applied by reading; script not run". With no template but setup scripts that create the same resources, apply C1–C12 by reading those scripts and say "checks applied by reading <path>; live configuration not verified".
- If the contract names a `usage_profile`, run the estimate (deployment-options Step 3 has the command) and compare the total with `monthly_budget_usd`.
- With no usage profile, say "no usage profile" and, when the system resembles the blueprint, offer an illustrative estimate from the blueprint's sample profile:

```bash
bash "$PLUGIN_ROOT/scripts/estimate-cost.sh" \
  "$PLUGIN_ROOT/pricing/aws-us-east-1.tsv" \
  "$PLUGIN_ROOT/blueprints/static-site-serverless-aws/usage-small.tsv" \
  --plans "$PLUGIN_ROOT/pricing/aws-cloudfront-flat-rate.tsv"
```

  Label it "illustrative: blueprint sample profile, pricing as_of <date>". It is not this project's cost; deployment-options builds the project's own profile.
- No IaC, no estimate, or a deployment choice that no ADR records: recommend [deployment-options](../deployment-options/SKILL.md).

### Step 5 — Maturity gaps

Compare what you found with the project's `maturity_target` row by row (section 5 of [architecture-principles.md](../../references/architecture-principles.md)). Each missing item is a finding at the severity the table above gives it, unless a waiver ADR in `architecture.waivers` covers it. Then it is listed as **Info: waived by ADR-NNN**, and the ADR is checked to exist in `adr_dir`. A waiver pointing at a missing ADR is a Low finding.

### Step 6 — Report

The counts and the rating cover rated findings only. Every rated finding gets the full `A<n>` block, Low ones included: no condensed lists.

```
architecture-review: <strong | moderate | weak> — <H> High, <M> Medium, <L> Low, <I> Info
Contract: <path, or "none — enterprise defaults (proposal shown in Step 0)">
Maturity target: <target>   Blueprint: <id or none>

Components (Step 1): <inventory table + Mermaid>
Quality attributes (Step 2): <one line per attribute: target | evidence | status>

Findings, most severe first:
A<n>  <severity>  <file>:<line or "absent">
      Attribute/principle: <e.g. Reliability, P11>
      Scenario: <what goes wrong, for whom>
      Fix: <smallest change that closes it>

Other observations (unrated):
O<n>  <file>:<line>  <concern>  [→ ascent-security]

Mechanical checks (Step 4): <script output, verbatim, or "not applicable: <why>">
Cost (Step 4): <total, as_of date, budget, or "no usage profile" (+ illustrative estimate if offered)>
Recommended next: <only the deeper skills whose surface checks flagged something, with the reason; ascent-security when any item is marked → ascent-security>
```

## What this skill does not do

- Change code, templates or cloud resources. Fixes go through the delivery loop (`ascent-delivery`) and the operator's runbook.
- Scan for credentials or vulnerable dependencies: use `ascent-security`.
- Quote a cost without a dated source: every number names its pricing file `as_of` or the live page and date it came from.
