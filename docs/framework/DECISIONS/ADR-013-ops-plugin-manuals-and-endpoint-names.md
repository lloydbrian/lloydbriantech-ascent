# ADR-013: Operations plugin, operations manuals and health endpoint names

**Status:** Proposed
**Date:** 2026-10-25 (America/New_York)
**Decider:** lloydbriantech

## Context

`ascent-ops` is rank 3 of the plugin roadmap (decisions 2026-10-18, order confirmed 2026-10-24). ASCENT already defines the devops role in `skills/lloydbriantech-ascent/references/role-devops.md`: containers, healthchecks, make as operator vocabulary, deploy and rollback. No plugin makes that role checkable in an existing repository. `architecture-review` (ADR-011) only notes whether runbooks exist; it does not check how they are written, how configuration and secrets are stored, or whether anyone can operate the system from its documentation.

The operator asked for three things on top of the role:

- **Infrastructure as code is the mantra, with secure by design.** Every configuration value and every secret is defined in code and stored in a place built for it, never typed into a console or written into a file in the repository.
- **A Maintenance and Operations Manual and a Troubleshooting Manual**, kept current, each with architecture diagrams and a dependency map.
- **Health endpoints without a `z` suffix.** The scaffold template, the observability contract and the embedded observability-check skill all use `/healthz` and `/readyz`. Those names come from Google's internal convention and Kubernetes' own API server, where the `z` avoids collisions with application routes. The operator does not want them in ASCENT projects.

The standards to judge against, as of 2026-10-25:

- The AWS Well-Architected Operational Excellence and Security pillars, and the Google SRE books for SLOs, error budgets and runbooks.
- The C4 model for architecture diagrams, which Mermaid draws as `C4Context`, `C4Container` and `C4Deployment`.
- Twelve-factor configuration.
- Kubernetes liveness, readiness and startup probes. The probe paths are free choices; Kubernetes only requires that the probe and the route agree.

The ux trial (ADR-012, decision 11) and the architecture trial (ADR-011, decision E) showed which rules a review plugin needs from day one: severities only from the table, exact evidence, valid contract values, fresh evidence, security referrals, scripts that run with `LC_ALL=C`, and N/A that never counts as a pass.

## Decision

1. **A hand-written plugin, `ascent-ops` 0.1.0**, with no plugin dependencies. There are four sibling skills, and the hybrid pattern applies: the entry skill recommends deeper skills only where a surface check flags something.
   - `ops-review`: the entry point and the rating. It loads or proposes the `ops:` section of the contract (detect, don't ask), maps environments, IaC, configuration stores, scripts, runbooks, manuals and health endpoints, applies six lenses (infrastructure as code, secure configuration, scripts and runbooks, health and SLOs, manuals, change and recovery), runs the three scripts, and reports strong, moderate or weak.
   - `iac-config-check`: IaC coverage and secure configuration, S1–S10.
   - `runbook-check`: operator scripts, make targets and runbooks, Z1–Z9 and the runbook standard.
   - `ops-manuals`: creates or updates the two manuals and checks that they are current, M1–M8.

   A read-only `ops-reviewer` agent (Read, Grep, Glob) carries an identical copy of the severity table, so a delivery loop can use it as its operations lens.
2. **Secure configuration is checked mechanically** by `scripts/check-iac-config.sh` (S1–S10) on CloudFormation YAML, Terraform and tfvars, Dockerfiles, Compose files and ECS task definitions:
   - no literal secrets or secret defaults (S1)
   - sensitive parameters marked `NoEcho` or `sensitive` (S2)
   - secrets from a store, never plain environment values or SSM `String` parameters (S3)
   - Terraform state remote, encrypted, locked and not committed (S4)
   - no wildcard IAM actions; a KMS key policy's account-root statement is exempt (S5)
   - rotation for every secret (S6)
   - per-environment configuration (S7)
   - no `.env` file in an image or a production Compose file (S8)
   - a drift check, and no `ignore_changes = all` (S9)
   - every parameter documented in the Maintenance and Operations Manual (S10)

   CDK, Pulumi, Kubernetes manifests and CloudFormation JSON are detected and reported as NOTE lines, not checked, in 0.1.0. The script never prints a value: a finding names the key and its location.
3. **Operations are zero-touch scripts** checked by `scripts/check-ops-scripts.sh` (Z1–Z9): a shebang, strict mode, `--help`, a dry run for anything that changes systems, secrets read with `read -rs` and never taken as arguments or printed, destructive commands behind a confirmation or an explicit flag, `##` help on make targets, pinned versions (images, actions, providers, modules, `@latest`, `curl | sh`), and pre-flight and post-flight checks. Sourced libraries get only the secret and destructive-command checks, and test code is skipped. Runbooks follow `references/runbook-standard.md`: inputs as shell variables, a pre-flight section, numbered steps with Expect and Stop if, destructive steps flagged, a post-flight section, and a rollback. `runbook-check` never runs a script or a step, not even with `--dry-run`.
4. **Two manuals, current by evidence.** `ops.manuals.maintenance` and `ops.manuals.troubleshooting` default to `docs/operations/MAINTENANCE-AND-OPERATIONS.md` and `docs/operations/TROUBLESHOOTING.md`. `scripts/check-ops-manuals.sh` (M1–M8) checks:
   - front matter with `as_of`, `describes` and `sources` (M1)
   - the required sections from `references/manual-sections.md` (M2)
   - Mermaid diagrams at the C4 context, container and deployment levels (M3)
   - every IaC resource and Compose service drawn by name (M4); with no IaC or Compose, M4 is N/A and the diagrams are checked by reading
   - a dependency map with versions (M5)
   - current: `as_of` within `--max-age` days (default 90), and no commits to the `sources` since `describes` (M6)
   - a symptom table with symptom, where to look, likely cause and fix or escalation (M7)
   - no credential-like values (M8)

   `ops-manuals` is the only `ascent-ops` skill that writes, and it writes only those two files, or a draft directory the operator names. It edits surgically, keeps the operator's text, takes every fact from a cited source or writes "unknown", lists contacts as roles and channels, shows the diff, and never commits.
5. **Health endpoints are `/-/health`, `/-/ready` and an optional `/-/started`**, overridable through `ops.health_path`, `ops.ready_path` and `ops.started_path`. The `/-/` prefix is reserved for operational routes, so one proxy rule (`location ^~ /-/`) can keep them off the public site, and it does not collide with application routes, which is the reason the `z` suffix existed. `ops-review` checks that the routes exist at the contract paths, that liveness has no dependencies, and that every probe (Dockerfile, Compose, proxy, orchestrator) uses the same path. No skill recommends a `z`-suffixed name.
6. **Rename everywhere, in the same release.** The scaffold template (backend route, Dockerfile, the three Compose files, the three nginx configs, the make status and dev targets, `CLAUDE.md.tmpl`, `README.md.tmpl`), the embedded `ascent-observability-check`, `ascent-reflect` and `ascent-self-audit` skills and their test, the references (`observability-contract.md`, `role-devops.md`, `role-developer.md`, `feature-lifecycle.md`) and the root `README.md` move to `/-/health` and `/-/ready`. Historical records (CHANGELOG entries, phase plans, smoke-test logs) keep the old names.
7. **Enterprise maturity by default**, as ADR-011: `ops.maturity_target` is enterprise, standard or prototype, and every gap the target requires is a Low finding unless a waiver ADR covers it, which makes it Info.
8. **A worked blueprint**, `blueprints/operable-service/`: a Compose file (proxy, api, db; pinned images; Compose secrets), a CloudFormation template for secure parameters (a KMS key, a generated secret with a rotation schedule, an SSM parameter, a least-privilege task role), an operator script template, and the two manuals with all three diagram levels. The blueprint passes all three scripts, which the rule tests pin.
9. **Single source.** The plugin is the source. `role-devops.md` names the four skills instead of repeating their rules, and the `architecture-principles.md` Operations row in `ascent-architecture` (0.1.1) points to `ascent-ops` for depth.
10. **Trial**, read-only, each run in a fresh conversation: `aws-platform-lloydbriantech` (CloudFormation and Terraform), `homelab-toolkit` (about 85 shell scripts, no IaC; exercises Z1–Z9 and the M4 N/A path) and `ground-turf-truth` (an ASCENT-scaffolded app with Compose). The trial repositories are never modified; manual drafts go to `tmp/ascent-test-runs/` in this repository.

## Alternatives considered

- **Keep `/healthz` and `/readyz`.** They are widely recognized, and Kubernetes uses them for its own components. Rejected at the operator's request: they are a convention, not a requirement, and the `z` exists only to avoid route collisions, which the `/-/` prefix already prevents.
- **Plain `/health` and `/ready`.** Rejected: they can collide with application routes (a "health" product page, a `/ready` API resource), and a proxy cannot reserve them with one rule.
- **Rename the scaffold in a later release.** Rejected: `ops-review` would then flag the endpoints every ASCENT scaffold ships with, and the observability contract and the plugin would disagree for a release.
- **Wrap `checkov`, `tfsec` or `trivy` instead of writing checks.** Rejected as a requirement: they need installing, some download rule bundles, and none of them covers manuals or runbooks. `iac-config-check` runs them when the operator already has them and maps their findings to S1–S10.
- **One manual instead of two.** Rejected: the Troubleshooting Manual is read during an incident and has to be short and symptom-first. Maintenance and operations is read when planning. Different readers, different moments.
- **Generate the manuals on every run.** Rejected (no documentation theater, modify-not-overwrite): a regenerated manual loses the operator's notes. `ops-manuals` edits only the sections whose facts changed.
- **Diagrams as images.** Rejected: an image cannot be checked against the IaC. Mermaid is text, renders on GitHub, and M4 can match service names.

## Consequences

- Builders get a rated operations review, mechanical secure-configuration and script checks, and two manuals that a script can prove are current.
- Every project scaffolded after this release serves `/-/health` and `/-/ready`. A project scaffolded earlier keeps `/healthz` until it migrates; `ops-review` reports its endpoints as non-default paths with no contract override (Low), and the fix is either the rename or the `ops:` overrides.
- M6 needs git history. The skills run `git log` only through their read-only pre-approval, and without git they report "staleness by date only; source changes not checked".
- The scripts read IaC with bash and awk. They cover the common shapes of CloudFormation YAML, Terraform and Compose, not every form (CloudFormation JSON, CDK and Pulumi are NOTEs). What they cannot see is listed in `references/secure-config-rules.md` and read by the skill.
- An independent review before the trial (2026-10-25, 15 findings, all confirmed by the finding verifier) led to one calibration round:
  - The awk programs moved into `scripts/lib/*.awk`, because the stock macOS `/bin/bash` 3.2 cannot parse a quoted heredoc inside `$(...)`. Rule R16 runs every script under `/bin/bash`.
  - `check-iac-config.sh` now reads one-line environment arrays in task definitions, Dockerfile `ENV` continuation lines, and one-line Terraform blocks and inline maps. A secret version no longer counts as a rotation; the CloudFormation long-form `Ref` does.
  - It no longer rates token validity units or CodeBuild variables from Secrets Manager as secrets, and in a key policy it exempts only the statement that names the account root.
  - `check-ops-scripts.sh` counts a `read` as a confirmation only for a variable named like one (`confirm`, `answer`, `ok`, `yn`), reads `read -rp "…"` prompts, names a destructive command instead of printing its line, exempts Compose services with `build:`, and treats version-less tags (`:alpine`) as floating.
  - Front-matter comments are ignored, and comments and test code are not drift evidence.
  - The controls P167–P186 pin each fix.
- The trial (2026-10-25, T1–T6 on the three repositories above) led to a second calibration round:
  - `check-ops-scripts.sh` accepts `--help` handled by a shared help function the script hands `"$@"` to, and a script that previews by default and changes only with `--apply` as having a dry run.
  - It no longer reads quoted text or trailing comments as commands, unless the line hands the text to `ssh`, `sh -c`, `eval` or `sudo`. A command kept in a variable counts where the variable runs.
  - It finds pre-flight and post-flight checks by position: a gate, health, verify, check or require call before the last change and after the first.
  - It flags an unbounded Terraform `required_version` (Z8), and it no longer reads binary files as scripts.
  - On `homelab-toolkit` the script failures fell from 63 (most of them false positives) to 17, and the stderr warnings from 19 to none.
  - A missing rollback is High only for a production deploy that exists. While the deploy files are empty or stubs, it is the Low maturity gap, which the trial had rated High twice.
  - A non-default endpoint path is fixed by renaming it to the contract path. An override is the alternative only when a probe the project does not control needs the old path, and the contract proposal never carries a `z`-suffixed value.
  - `iac-config-check` runs `trivy config --skip-check-update --skip-version-check --quiet .` without asking, because it downloads nothing; plain `trivy config .` still needs the operator's agreement.
  - Rules R17 and R18 and the controls P187–P199 (group `ascent-ops-calibration`) pin each fix.
- A fresh scaffold still fails Z8 four times (`nginx:alpine` in three files, the untagged distributed backend image) and Z3 once (`make/help.sh`). The operator chose a separate template change (2026-10-25), listed under Planned in the CHANGELOG.
- Running `check-ops-scripts.sh` on this repository's own `make/` scripts finds missing `--help` (Z3) in eight scripts and `tokens-to-css.sh`. That is a follow-up for this repository, not a blocker: Z3 is Low.
- `make test-mutants` gains 82 controls (P118–P199) in five groups, `ascent-ops-config`, `ascent-ops-scripts`, `ascent-ops-manuals`, `ascent-ops-review` and `ascent-ops-calibration`, which CI picks up as parallel jobs through `--groups-json`. One control runs the ops tests in about 20 seconds, against about 7 for the other plugins, so a single group of 49 took 18m33s locally, past the CI job's 15-minute timeout; groups of 16 to 21 take 6 to 8 minutes each.
- The plugin gate's T5 now checks three marked severity tables (architecture, UX, operations) through one function.

## Cost implications

- About 2,700 lines of plugin (four skills, an agent, five references, three scripts with their awk programs, and a blueprint) and about 1,100 lines of tests and fixtures, plus 82 negative controls (P118–P199).
- The rename touches 21 files outside the plugin. Projects scaffolded earlier carry a small migration (or a contract override).
- Recurring: review the S, Z and M rules when the IaC tools change their syntax, and refresh the references' standards status with the other plugins.
- Runtime: bash, awk and git only. `cfn-lint`, `checkov` and `trivy` are used only when already installed.
