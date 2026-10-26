# ascent-ops

Operations review for any repository. It checks that the system can be run, changed and recovered by someone who did not build it:
- infrastructure as code, with configuration and secrets stored securely by design
- zero-touch scripts and runbooks with pre-flight and post-flight checks
- a Maintenance and Operations Manual and a Troubleshooting Manual, each with architecture diagrams and a dependency map, kept current

It makes the ASCENT devops role checkable in an existing repository ([ADR-013](../../docs/framework/DECISIONS/ADR-013-ops-plugin-manuals-and-endpoint-names.md)). You don't need an ASCENT project to use it.

```
/plugin marketplace add lloydbrian/lloydbriantech-ascent
/plugin install ascent-ops@lloydbriantech-ascent
```

Start with `/ascent-ops:ops-review`, or ask "is this operable?". For an independent pass: "Use the ascent-ops:ops-reviewer agent to review this repository."

## What's inside

| Part | Kind | What it does |
|---|---|---|
| `ops-review` | skill, entry point | contract, operations map, six lenses, the three checks, maturity gaps; strong, moderate or weak |
| `iac-config-check` | skill | IaC coverage and secure configuration: S1–S10, plus cfn-lint, checkov or trivy when the project already has them |
| `runbook-check` | skill | operator scripts (Z1–Z9), make targets and runbooks: pre-flight, post-flight, Expect and Stop if, rollback |
| `ops-manuals` | skill, writes two files | creates or updates the two manuals with surgical edits, C4 diagrams and a dependency map; never commits |
| `ops-reviewer` | agent, read-only | independent review; a delivery-loop review lens for infrastructure and operations changes |
| `check-iac-config.sh` | script | S1–S10 on CloudFormation, Terraform/OpenTofu, Dockerfiles, Compose and ECS task definitions; never prints a value |
| `check-ops-scripts.sh` | script | Z1–Z9 on shell scripts, make targets, images, workflows and Terraform versions |
| `check-ops-manuals.sh` | script | M1–M8: front matter, sections, diagram levels, services drawn, dependency map, staleness, symptom table, no credentials |
| `blueprints/operable-service/` | blueprint | both manuals as a worked example with Mermaid C4 diagrams, a zero-touch script template, a CloudFormation secure-parameter template and a Compose file; passes all three checks |
| `references/` | references | secure-configuration rules, the SRE baseline, the runbook standard, the manual sections, the contract template |

## Boundaries

- **Deploying** is the operator's: the plugin never runs a change. Fixes go through `ascent-delivery` and its runbook.
- **Leaked secrets** are `ascent-security`'s: a finding names the location, never the value, and is marked `→ ascent-security`.
- **Cost and the choice of platform** are `ascent-architecture`'s (`deployment-options`).
- **Setting up a monitoring vendor** is out of scope; the plugin checks that SLOs, alerts and their runbooks exist.

## Health endpoint names

The defaults are `/-/health` (liveness), `/-/ready` (readiness) and, for a slow start, `/-/started`. The reserved `/-/` prefix keeps them clear of application routes. A project that must keep other paths sets `ops.health_path`, `ops.ready_path` and `ops.started_path` in its contract; the checks follow the contract.

## Maturity targets

| Item | Prototype | Standard | Enterprise (default) |
|---|---|---|---|
| Infrastructure as code | — | production in IaC; state remote and encrypted | every environment in IaC; a scheduled drift check; plans reviewed before apply |
| Secure configuration | no literal secrets (S1) | secrets in a store, sensitive values marked (S1–S4, S8) | S1–S10: least privilege, rotation, per-environment configuration, configuration documented |
| Scripts and make | `make help` lists the targets | Z1–Z5: shebang, strict mode, `--help`, dry run, secrets with `read -rs` | Z1–Z9: guarded destructive commands, pinned versions, pre-flight and post-flight in every changing script |
| Runbooks | a deploy runbook | deploy and rollback runbooks with pre-flight and post-flight sections | deploy, rollback and incident runbooks; every step has Expect and Stop if |
| Health and SLOs | a liveness endpoint | liveness and readiness at the contract paths | startup where the start is slow; SLOs and alerts in the contract, each alert linked to a runbook |
| Manuals | — | Maintenance and Operations Manual, current (M1, M2, M6) | both manuals; C4 diagrams cover every service; dependency map with versions (M1–M8) |
| Decisions | — | an ADR for the IaC tool and the configuration store | ADRs for those and for every waiver |

## Evidence, strongest first

1. **The three scripts:** exact, repeatable, `file:line`, labelled with their check id.
2. **The project's own tools,** when already installed: `cfn-lint`, `checkov`, `trivy config`. The plugin never installs them.
3. **Reading** the IaC, scripts, runbooks and manuals: the agent's view.

## Tests

`make test-plugins` runs `tests/plugins/ascent-ops/`, on every awk installed:
- `test-check-iac-config.sh`: the good fixtures pass S1–S10; one broken copy per control fails that check and no other; values are never printed
- `test-check-ops-scripts.sh`: the good fixtures pass Z1–Z9; one broken copy per control; exemptions; the plugin's own scripts pass
- `test-check-ops-manuals.sh`: the blueprint manuals pass M1–M8; staleness by date and through a fake git; N/A without IaC
- `test-ops-rules.sh`: the skill rules, the endpoint defaults and the blueprint against all three checks

`make test-mutants GROUP=ascent-ops` adds negative controls that must each make a named check fail.
