---
name: iac-config-check
description: >-
  Use when asked "is our infrastructure as code complete?", "are secrets
  stored securely?", "check our Terraform or CloudFormation configuration",
  "is the Terraform state safe?", or when ops-review flags the IaC or
  secure-configuration lens. Checks IaC coverage and secure-by-design
  configuration (S1–S10): no literal secrets, secret stores and rotation,
  encrypted and locked state, least privilege, per-environment configuration,
  drift detection. Never prints a value. Read-only.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*)
---

# iac-config-check

The deep infrastructure-as-code and configuration check behind [ops-review](../ops-review/SKILL.md). It is a sibling that shares that skill's severity table, contract and evidence rules. It checks the mantra: infrastructure as code is the only way configuration changes, and every value and secret is stored securely by design.

Sources: [secure-config-rules.md](../../references/secure-config-rules.md) (S1–S10 with fixes per tool) and the blueprint's [secure-parameters.yaml](../../blueprints/operable-service/secure-parameters.yaml), a template that passes every rule.

## Rules

- All `ops-review` rules apply: read-only; repository-relative `file:line` evidence; fresh evidence; severities only from the `ops-review` table; no personal data.
- **Never print a value.** Name the key and its location. Do not quote the line when it holds a secret, not even partly or masked.
- **Committed secrets are referred.** A literal secret (S1, S4 state files) is also `ascent-security`'s finding: mark it `→ ascent-security`, and say it must be rotated, not just deleted, because it stays in the history.
- **Optional tools run only when present.** `cfn-lint`, `checkov` and `trivy` run only if the operator already has them on `PATH`; never install them or download their rules without asking.

## Steps

### Step 1 — IaC inventory

List every IaC source with its tool and what it provisions: CloudFormation templates, Terraform/OpenTofu roots and modules, Dockerfiles, Compose files, ECS task definitions. Detected but not covered in 0.1.0: AWS CDK (`cdk.json`; read the synthesized template from `cdk synth` if the operator has it), Pulumi (`Pulumi.yaml`), Kubernetes manifests, CloudFormation JSON. Compare with the contract's `ops.environments` and `ops.iac`: an environment with no IaC, or production resources the IaC does not describe (named in runbooks or scripts, missing from the code), is the "built by hand" finding.

### Step 2 — Mechanical checks

Run the script from the repository root and include its output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-iac-config.sh" --manual <ops.manuals.maintenance> .
```

`PLUGIN_ROOT` is two directories above this skill's base directory. Each `FAIL` line is a finding at the severity it prints; `absent` means the control is missing everywhere searched. `NOTE` lines (IaC not covered) go under Other observations.

### Step 3 — What the script cannot see

Read the IaC for the items in [secure-config-rules.md](../../references/secure-config-rules.md#what-the-script-cannot-see):
- secrets under key names that do not say so (a `config` or `settings` blob, a connection URL with credentials)
- secret reads granted on `Resource: "*"`, or a task role that can read another service's secrets
- a secret store with no customer-managed key where the contract's maturity target asks for one
- rotation scheduled on a function that cannot reach its target
- values resolved from the wrong environment (`/prod/` read by the dev stack)
- the configuration store named in `ops.config_store` not used for every secret (some in Secrets Manager, others in environment files)

### Step 4 — Project tools (only when present)

When they are already installed, run them read-only and include the summary:
- `cfn-lint <template>` for each CloudFormation template
- `checkov -d . --compact --quiet` (it reads only)
- `trivy config .` (ask first: it may download its check bundle)

Their findings are evidence for the rule they match (S1–S10); a finding that matches no rule goes under Other observations. Never treat a tool's silence as a pass for a rule it does not cover.

### Step 5 — Report

Use the `ops-review` Step 6 format, limited to the IaC and secure-configuration lenses: inventory, findings with rule ids, Other observations, the script output verbatim, and the tools' summaries. Recommended next names `ascent-security` whenever any item is marked `→ ascent-security`.
