---
name: ops-review
description: >-
  Use when asked "is this operable?", "review operations", "are we ready to
  run this in production?", "check our runbooks and IaC", "is our
  configuration secure?", or before a first production deploy. Rates
  operability against the project contract: maps environments, IaC,
  configuration stores, scripts, runbooks, manuals and health endpoints,
  checks six lenses, runs the IaC, script and manual checks, and reports
  strong, moderate or weak with file:line evidence. Read-only.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git log:*), Bash(git ls-files:*)
---

# ops-review

One review of how a system is run, changed and recovered, judged against the project's own targets. It is the entry point of the `ascent-ops` plugin. It runs surface checks itself and recommends [iac-config-check](../iac-config-check/SKILL.md), [runbook-check](../runbook-check/SKILL.md) or [ops-manuals](../ops-manuals/SKILL.md) only for the areas a surface check flags (the hybrid pattern). It never invokes them; they read the same sources.

It makes the ASCENT devops role checkable: infrastructure as code is the only way configuration changes, secrets are secure by design, every operation is a zero-touch command with pre-flight and post-flight checks, and two manuals let someone who did not build the system run it.

Shared sources:
- [secure-config-rules.md](../../references/secure-config-rules.md): S1–S10
- [sre-baseline.md](../../references/sre-baseline.md): health endpoints, SLOs, alerts, pinning, change and recovery
- [runbook-standard.md](../../references/runbook-standard.md)
- [manual-sections.md](../../references/manual-sections.md)
- [contract-template.yml](../../references/contract-template.yml): the `ops:` section of `.ascent/contract.yml`

## Rules

- **Read-only.** Never edit files, run a deploy, apply a plan, start or stop a service, or call a cloud API that changes anything. `git log` and `git ls-files` are the only commands pre-approved; the three scripts only read.
- **Evidence or it is not a finding.** Every finding cites a repository-relative `path/to/file:line` (never a bare file name or a directory) or "absent: searched <paths>", the rule it breaks (S1–S10, Z1–Z9, M1–M8, or the baseline item), a concrete failure scenario (what goes wrong, for whom, when), and a fix.
- **Fresh evidence.** Re-read the evidence for every finding in this run. Never carry findings over from an earlier pass, an agent's report or another session.
- **Rate only with the severity table.** A concern that matches no row goes under **Other observations (unrated)** and does not count toward the rating. Never invent a severity.
- **Judge against the contract**, not against an ideal. A gap covered by a waiver ADR is Info, not a finding.
- **Never "met" without a target.** A lens whose target is missing from the contract is unmeasured, never met; it is at risk instead when the evidence shows a gap.
- **Endpoints follow the contract.** The health, readiness and startup paths are `ops.health_path`, `ops.ready_path` and `ops.started_path`; the defaults are `/-/health`, `/-/ready` and `/-/started`. Never recommend a `z`-suffixed name. A route or probe at another path is fixed by renaming it to the contract path; an override is only the alternative, when a probe the project does not control needs the old path.
- **Rollback is rated by what exists.** The High needs a production deploy path that works: a deploy script, make target, CI job or IaC with content that ships to production. While the deploy files are empty or stubs, the missing rollback is the Low maturity gap; name the empty files as the evidence.
- **Maturity gaps are always rated.** With no confirmed contract, rate them against the enterprise defaults (Step 5) and say so; never list them unrated.
- **No secrets, account ids or personal data** in the report, even when a finding is about one: name the key and the location, never the value. A secret that is already committed is `ascent-security`'s finding too: mark it `→ ascent-security`. Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`.
- **Cost and platform choice** are `ascent-architecture`'s (`deployment-options`): mark such items `→ ascent-architecture` under Other observations.
- **Scripts and data.** The plugin's read-only scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`. The blueprint is in `$PLUGIN_ROOT/blueprints/operable-service/`.

## Severity

Every finding carries one of these severities. The other skills, the `ops-reviewer` agent and the three scripts use the same table.

<!-- ops-severity:start -->
| Finding | Severity |
|---|---|
| A secret value written in IaC, a Dockerfile, a Compose file, a script or a manual (S1, M8); the leak itself → ascent-security | High |
| A secret passed as a plain environment value to a task or function, or stored as an SSM String (S3) | High |
| Terraform state local, unencrypted, unlocked or committed (S4) | High |
| A .env file copied into an image (S8) | High |
| A script that takes a secret as an argument, reads it without -s or prints it (Z5) | High |
| A destructive command with no confirmation or explicit flag (Z6) | High |
| No rollback path for a production deploy that exists | High |
| A sensitive parameter not marked NoEcho or sensitive (S2) | Medium |
| A secret passed to a Compose service as an environment value instead of Compose secrets (S3) | Medium |
| A wildcard IAM action (S5) | Medium |
| No per-environment configuration (S7), or an env file in a production Compose file (S8) | Medium |
| No drift check, or drift hidden by ignore_changes = all (S9) | Medium |
| An operator script without a shebang or strict mode (Z1, Z2), or one that changes systems without a dry run (Z4) | Medium |
| A floating version: a :latest or untagged image, @latest, an action on a branch, a remote script piped to a shell, an unbounded provider (Z8) | Medium |
| A liveness or readiness endpoint missing at the contract path, a probe on another path, or a liveness check that depends on the database | Medium |
| A runbook without pre-flight or post-flight checks, or steps without Expect and Stop if | Medium |
| A manual missing, without front matter or a required section, out of date, without the three diagram levels, with a service missing from the diagrams, or without a symptom table (M1–M4, M6, M7) | Medium |
| Production infrastructure not in IaC (built by hand) at the standard or enterprise target | Medium |
| A secret without rotation (S6), or configuration not documented in the manual (S10) | Low |
| A script without --help (Z3), a make target without ## help (Z7), or a changing script without pre-flight and post-flight checks (Z9) | Low |
| A dependency map without versions (M5) | Low |
| Health endpoints at non-default paths with no contract override | Low |
| An ops target missing from the contract ("unmeasured") | Low |
| No rollback path while no production deploy exists yet (deploy files empty or stubs) | Low |
| Any other item the maturity target requires, missing with no waiver (Step 5) | Low |
| A gap covered by a waiver ADR | Info |
<!-- ops-severity:end -->

**Rating:** **strong**: no High and no Medium. **moderate**: no High, one or more Medium. **weak**: one or more High.

## Steps

### Step 0 — Load or propose the contract

Read `.ascent/contract.yml`, or `.claude/contract.yml` where ASCENT-named files are not allowed, and use its `ops:` section.

If it is missing, **detect, don't ask.** Propose the section from what the repository declares:

- **Environments:** `*.tfvars` names, workspaces, `environments/` or `envs/` directories, CloudFormation `Environment` parameters, `compose.<env>.yml`, CI deploy jobs.
- **IaC:** `*.tf`, CloudFormation templates (`Resources:` with `AWS::` types), `compose*.yml`, `cdk.json`, `Pulumi.yaml`.
- **Configuration store:** `AWS::SecretsManager::Secret`, `aws_secretsmanager_secret`, `AWS::SSM::Parameter`, `aws_ssm_parameter`, Compose `secrets:`, `vault` references, `.sops.yaml`.
- **Endpoints:** the routes that answer health and readiness, and the probes (`HEALTHCHECK`, Compose `healthcheck`, `healthCheck`, target groups). Propose the default paths even when the code serves others, and mark each detected path for rename (`# detected: <path:line>, rename to the default`). Never propose a `z`-suffixed value.
- **Runbooks and manuals:** `docs/operations/`, `docs/runbooks/`, `RUNBOOK*.md`, `*runbook*` folders.

Use only the keys and values of [contract-template.yml](../../references/contract-template.yml):
- `maturity_target` is one of enterprise, standard or prototype (never a new value)
- `iac.tool` and `config_store` take only the values listed in the template
- each waiver is an `id`, `skips` and `review_by`
- mark detected values with their source (`# detected: <path:line>`) and guesses with `# guess`

Show the proposal once and ask the operator to confirm it. Write nothing: the operator commits the file. Until it is confirmed, review against the enterprise defaults and the default endpoint paths, and say so in the report.

### Step 1 — Map operations

Build the inventory from the repository, not from memory:

| Item | Kind | Where defined | Environments | Notes |
|---|---|---|---|---|

List the environments; the IaC files and what each provisions; the configuration and secret stores; the operator scripts and make targets that change systems; the runbooks; the two manuals; the health endpoints and every probe that calls them; CI deploy and drift jobs; the backup jobs. A repository with no IaC (scripts that manage hosts or network devices, for example) lists the hosts and devices the scripts name instead.

### Step 2 — Surface checks (six lenses)

One line per lens: what the contract asks, the evidence found, and the status **met**, **at risk** or **unmeasured**. A lens whose target is missing from the contract is unmeasured, never met; it is at risk instead when the evidence shows a gap. Report these six lenses, in this order, and no others:

- **Infrastructure as code:** every environment in IaC; nothing built by hand; state handled safely (S4).
- **Secure configuration:** S1–S10 ([secure-config-rules.md](../../references/secure-config-rules.md)).
- **Scripts and runbooks:** zero-touch scripts (Z1–Z9) and runbooks with pre-flight, post-flight, Expect and Stop if ([runbook-standard.md](../../references/runbook-standard.md)).
- **Health and SLOs:** endpoints at the contract paths, liveness free of dependencies, probes on the same paths, SLOs and alerts each linked to a runbook, pinned versions ([sre-baseline.md](../../references/sre-baseline.md)).
- **Manuals:** both manuals present, current and complete, with diagrams and a dependency map ([manual-sections.md](../../references/manual-sections.md)).
- **Change and recovery:** deploy, rollback, backup and restore (with a restore-test date), drift check.

Two or more lenses at risk or unmeasured: recommend [iac-config-check](../iac-config-check/SKILL.md), [runbook-check](../runbook-check/SKILL.md) or [ops-manuals](../ops-manuals/SKILL.md) for the lenses concerned.

### Step 3 — Mechanical checks

Run the three scripts from the repository root and include their output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-iac-config.sh" --manual <ops.manuals.maintenance> .
bash "$PLUGIN_ROOT/scripts/check-ops-scripts.sh" .
bash "$PLUGIN_ROOT/scripts/check-ops-manuals.sh" --repo . <ops.manuals.maintenance> <ops.manuals.troubleshooting> .
```

- Each `FAIL` line is a finding with the severity it prints, under the rule id it names.
- An `absent` location means the control is missing everywhere searched: cite it as "absent: searched <paths>".
- `NOTE` lines are unrated: list them under Other observations (IaC the checks do not cover, source changes not checked).
- `N/A` is never a pass. Say what had nothing to check; for M4 with no IaC, check the diagrams against the Step 1 inventory by reading.
- If Bash is unavailable or the operator declines it, apply the rules by reading and say "checks applied by reading; scripts not run".

### Step 4 — Health endpoints

Search the code for the routes at `ops.health_path`, `ops.ready_path` and, when set, `ops.started_path` (defaults `/-/health`, `/-/ready`, `/-/started`). For each:
- the route exists, unauthenticated
- liveness does not touch the database or another dependency; readiness does
- every probe (Dockerfile `HEALTHCHECK`, Compose `healthcheck`, ECS `healthCheck`, target group `health_check`, Kubernetes probes) calls the same path

A route or probe at a non-default path: the fix renames it to the contract path, in the route, every probe and every caller. Setting the old path in the contract is the alternative only when renaming is not possible; say why.

A service with no HTTP interface (a batch job, scripts for network devices) has no endpoints to check: say "health endpoints: not applicable (<reason>)" and check that its runs are observable instead (exit codes, logs, alerts).

### Step 5 — Maturity gaps

Compare what you found with the `maturity_target` row by row, using the maturity table in the plugin [README](../../README.md#maturity-targets). Each missing item is a finding at the severity the table above gives it, unless a waiver ADR in `ops.waivers` covers it. Then it is listed as **Info: waived by ADR-NNN**, and the ADR is checked to exist in `adr_dir`. A waiver that points at a missing ADR is a Low finding.

### Step 6 — Report

The counts and the rating cover rated findings only. Every rated finding gets the full `X<n>` block, Low ones included: no condensed lists.

```
ops-review: <strong | moderate | weak> — <H> High, <M> Medium, <L> Low, <I> Info
Contract: <path, or "none — enterprise defaults, endpoints /-/health and /-/ready (proposal shown in Step 0)">
Maturity target: <target>   Environments: <list>   IaC: <tool or none>

Operations map (Step 1): <inventory table>
Lenses (Step 2): <one line per lens: target | evidence | status (met only when the contract sets a target)>

Findings, most severe first:
X<n>  <severity>  <file>:<line or "absent: searched …">  <rule id or baseline item>
      Scenario: <what goes wrong, for whom, when>
      Fix: <smallest change that closes it; through IaC, never by hand>

Other observations (unrated):
O<n>  <file>:<line>  <concern>  [→ ascent-security | → ascent-architecture]

Mechanical checks (Step 3): <the three scripts' output, verbatim>
Health endpoints (Step 4): <per endpoint: path, route, probes, or "not applicable: <reason>">
Recommended next: <only the deeper skills whose surface checks flagged something, with the reason; ascent-security when any item is marked → ascent-security>
```

## What this skill does not do

- Change code, IaC, scripts or manuals. Fixes go through the delivery loop (`ascent-delivery`) and the operator's runbook; the manuals are written by [ops-manuals](../ops-manuals/SKILL.md).
- Deploy, apply, roll back or run any operator script.
- Find leaked secrets in history (`ascent-security`) or estimate cost (`ascent-architecture`).
- Set up a monitoring vendor. It checks that SLOs, alerts and their runbooks exist.
