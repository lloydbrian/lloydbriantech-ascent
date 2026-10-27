# Changelog

All notable changes to the `lloydbriantech-ascent` framework will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Dates are in **America/New_York** timezone.

---

## [Unreleased]

### Planned

- Scaffold template, from the `ascent-ops` review: pin `nginx:alpine` (`docker-compose.yml`, `docker-compose.dist.yml`, `frontend/Dockerfile`) to a verified release tag, tag the distributed backend image in `docker-compose.dist.yml`, and give `make/help.sh` a `--help`, so a fresh scaffold passes Z8 and Z3; and this repository's own `make/` scripts lack `--help` (Z3)
- `ascent-quality` next (plugin roadmap rank 4), then `ascent-session`, `ascent-adr`, `ascent-docs`, `ascent-node-stack` (decisions 2026-10-18; order confirmed 2026-10-24)
- `ascent-ux` 0.2.0 candidates from the trial: a framework repository (JSX, Vue or Svelte) as a second real-repository trial; delegated listeners across files and for compound selectors; the box-shadow ring's contrast computed rather than left to the browser
- `ascent-delivery` 0.2.0 — read the `delivery:` section of `.ascent/contract.yml` (`.delivery-loop.yml` stays supported); runbook steps labelled C (Claude: read-only checks) and O (operator: writes)
- `ascent-security` — the dynamic-code rule scans code files only; code embedded in shell scripts (e.g. `python -c "eval(…)"`) is listed under Other observations, not rated
- `ascent-architecture` 0.2.0 candidates: more blueprints (containers on Fargate, Terraform), `cfn-guard` rules, Azure and Google Cloud pricing; from the trial: cite a principle by its id and its exact name, rate a missing ADR for a one-way door as Low every time, and drop API rows from the illustrative estimate when no API is deployed
- Restore and failover proof (Resilience pillar, committed 2026-10-26): a drill runbook the operator runs, with the measured recovery time checked against the contract's `rto` and `rpo`; today `ascent-ops` and `quality-attributes` only read the date of the last restore test. See `docs/framework/PILLARS.md` for the other gaps
- Phase 4 — Scaffolding scripts (`scaffold.py`, `bootstrap.py`)
- Phase 5 — Test harness with three eval scenarios
- Phase 6 — Starter repo generation tooling
- Phase 7 — First production project scaffolded from ASCENT

See [`docs/framework/ROADMAP.md`](docs/framework/ROADMAP.md) for the full roadmap.

---

## [0.4.7] — 2026-10-26

**Housekeeping.** Three plugin patch releases and repository fixes, shipped as one pull request with the version bump: `ascent-architecture` 0.1.2, `ascent-delivery` 0.1.1 and `ascent-ux` 0.1.1.

### Changed

- `ascent-architecture` 0.1.2: `quality-attributes` no longer calls `ascent-ux` planned, and a rule (R12) fails whenever a skill or the agent calls a plugin that ships in `plugins/` planned. `check-cfn-static-site.sh` answers `--help`
- `ascent-delivery` 0.1.1: the runbook template has a "Stacked pull requests" rule, learned on #54. Retarget a stacked PR to `main` before its base merges; retargeting does not start CI, so close and reopen it; after a squash merge of the base, replay the stacked commits with `git rebase --onto` and flag the force push. The operator-boundary hook states why it is exempt from the `ascent-ops` Z2 and Z3 checks. A new `test-delivery-rules.sh` pins both (D1–D3)
- `ascent-ux` 0.1.1: `tokens-to-css.sh` answers `--help`
- Every script in `make/` answers `--help` with its header, so `check-ops-scripts.sh` finds no Z3 gap in this repository's scripts or plugin scripts, apart from the exempt operator-boundary hook
- `make doc-stub` is marked as landing with the `ascent-docs` plugin instead of the out-of-date Phase 2
- `make test-mutants` gains controls P200–P204, one for each new rule

### Notes

- The `ascent-ops` trial run T6 (the `ops-reviewer` agent) has no saved report and is recorded as skipped. T1–T5 exercised the same rules, and the agent's severity table is checked against the skill's by the plugin gate (T5)

## [0.4.6] — 2026-10-26

**Operations plugin.** `ascent-ops` 0.1.0 rates how a system is run, changed and recovered against the `ops:` section of the project contract: secure-by-design IaC configuration, zero-touch scripts and runbooks with pre-flight and post-flight checks, and operations manuals proven current. It was trialled read-only on three repositories and calibrated twice. Health endpoints move to `/-/health`, `/-/ready` and `/-/started`. The front-facing docs are rewritten for the plugin direction, with a new page mapping every quality attribute to four pillars. ADR-013 is accepted.

### Added

- `ascent-ops` 0.1.0 (plugin roadmap rank 3, ADR-013): `ops-review` rates operations against the `ops:` section of the project contract over six lenses; `iac-config-check` checks secure configuration in CloudFormation, Terraform, Docker, Compose and ECS task definitions (S1–S10: no literal secrets, NoEcho and sensitive, secrets from a store, safe Terraform state, no wildcard actions, rotation, per-environment configuration, no `.env` in images, drift checks, documented parameters); `runbook-check` checks operator scripts and runbooks (Z1–Z9: strict mode, `--help`, dry run, `read -rs`, guarded destructive commands, pinned versions, pre-flight and post-flight); `ops-manuals` creates and updates the Maintenance and Operations Manual and the Troubleshooting Manual with C4 context, container and deployment diagrams, a dependency map and a symptom table, and proves them current (M1–M8). A read-only `ops-reviewer` agent and an `operable-service` blueprint that passes all three checks. The scripts run under the stock macOS `/bin/bash` 3.2 (their awk programs are in `scripts/lib/`). Calibrated on a read-only trial of three repositories: shared help functions, preview-by-default `--apply` scripts and position-based pre-flight and post-flight checks are recognized; quoted messages are not commands; an unbounded Terraform `required_version` is a floating version; a missing rollback is High only when a production deploy exists; a non-default endpoint is fixed by renaming it; `trivy` runs unasked only offline. Negative controls P118–P199 run as five CI groups (`ascent-ops-config`, `ascent-ops-scripts`, `ascent-ops-manuals`, `ascent-ops-review`, `ascent-ops-calibration`), so each job stays inside its timeout

### Changed

- Front-facing documentation brought up to date with the plugin direction: a new README (banner in light and dark, live CI and release badges, the five plugins and the bar each clears, honest scaffolding status, the full release history); the plugin channel, gate and shared contract in `ARCHITECTURE.md`; a plugin roadmap in `ROADMAP.md`; a "Contributing a plugin" bar in `CONTRIBUTING.md`; current version, layout and plugin rules in `CLAUDE.md`; a plugin paragraph in `SCOPE.md` and `PHILOSOPHY.md`; a plugin proposal issue template and plugin checks in the PR template. A new `docs/framework/PILLARS.md` maps every quality attribute to one of four pillars (driving business value, compliance, trust and security, resilience), the plugin that checks it and the gaps, and the README plugin table gains a Pillars column. `ROADMAP.md` records restore and failover proof as a committed follow-up. The README no longer points at the starter template repository, which arrives in Phase 6
- Health endpoints are `/-/health` and `/-/ready` (and an optional `/-/started`) instead of `/healthz` and `/readyz`, overridable through `ops.health_path`, `ops.ready_path` and `ops.started_path` (ADR-013): the scaffold template's route, Dockerfile, Compose files, nginx configs, make targets and docs, the embedded `ascent-observability-check`, `ascent-reflect` and `ascent-self-audit` skills, and the references. A project scaffolded earlier keeps its paths until it migrates or sets the overrides
- `ascent-architecture` 0.1.1: the Operations row of the principles asks for runbooks with pre-flight and post-flight checks, both operations manuals and secure configuration, and points to `ascent-ops`
- `make test-plugins` T5 checks the operations severity table copies too, through one function for all three marked tables
- CI runs the negative controls in parallel, one job per group and platform: `make test-mutants GROUP=<group>` runs `core` (embedded-skill rows and validator controls) or one plugin's section, `make test-mutants-groups` lists the groups for the CI matrix, and an unknown or empty group fails. The gate job keeps qa, the skill tests and the plugin gate, with a 15-minute timeout. Locally the longest group (`ascent-ux`, 57 controls) takes about 6.5 minutes; before, one macOS job ran all 183 in 18m39s of its 25 minutes

## [0.4.5] — 2026-10-25

**UX plugin.** `ascent-ux` 0.1.0 rates any web UI against the project contract with WCAG 2.2 AA evidence: static checks on markup, CSS and single-page-app views, exact contrast for every token pair in every theme, and a Playwright browser pass that is authoritative. It checks the design system, and it offers five predefined design directions as mocks of the project's own pages, each verified for contrast and accessibility before it is shown. Installing it also installs `design`, `frontend-design` and `playwright`. A read-only trial on two real repositories (five runs) and a re-trial drove two calibration rounds before release. See [ADR-012](docs/framework/DECISIONS/ADR-012-ux-plugin-design-directions-and-plugin-dependencies.md), now Accepted.

### Added

- `plugins/ascent-ux/` 0.1.0 (ADR-012): UX review for any web UI. Four hand-written skills: `ux-review` (entry point: contract, UI map, five lenses, static checks, a Playwright browser pass, maturity gaps; severity table and strong/moderate/weak rating), `accessibility-audit` (all 55 WCAG 2.2 A and AA criteria for the core flows, ARIA widgets against the APG, axe-core when the project has it), `design-system-check` (token source, hard-coded values, contrast in every theme, theming, motion, component states) and `design-directions` (five predefined design directions shown as checked mocks of the project's pages, more on request, ADR and token hand-off); a read-only `ux-reviewer` agent
- `ascent-ux` dependencies: installing it installs and enables `design` (Anthropic directory), `frontend-design` and `playwright` (claude-plugins-official). The marketplace allowlists both marketplaces in `allowCrossMarketplaceDependenciesOn`
- `scripts/check-web-accessibility.sh`: 12 static checks (U1–U12) on HTML, JSX/TSX, Vue, Svelte, Astro and server templates, each mapped to a WCAG 2.2 criterion; `--core` raises U3 and U12 to High on core flows; comments, script bodies and capitalized components are skipped; every finding is "static" until the browser pass confirms it
- `scripts/check-token-contrast.sh`: exact WCAG contrast (sRGB relative luminance, truncated, never rounded up) for token pairs per theme, from Design Tokens 2025.10 JSON or CSS custom properties, with pair files or inferred pairs; `scripts/tokens-to-css.sh`: Design Tokens JSON to CSS custom properties with light and dark blocks; shared parser `scripts/lib/tokens.awk`
- `directions/`: D1 Clean neutral, D2 Bold brand, D3 Editorial, D4 Soft friendly and D5 Dense professional, each a light and dark Design Tokens 2025.10 set on one schema, all passing `pairs.tsv` (16 pairs, both themes)
- Blueprint `accessible-page`: a token-only accessible page starter (skip link, landmarks, labelled form with hint, error and status patterns, visible focus, 44px targets, reduced motion, 320px reflow); the mock template
- `ascent-ux` references: WCAG 2.2 checklist, ARIA patterns, Nielsen's heuristics with ISO 9241-110, design tokens, performance UX, an accessibility law and standards map (as_of 2026-10-24, not legal advice), a manual keyboard and screen-reader checklist, and the `ux:` section of `.ascent/contract.yml`
- `tests/plugins/ascent-ux/`: `test-check-web-accessibility.sh` (good fixtures in four syntaxes pass all 12 checks; one broken copy per check fails that check and no other), `test-check-token-contrast.sh` (hand-checked ratios; every direction in both themes), `test-tokens-to-css.sh` (value shapes; no blueprint drift) and `test-ux-rules.sh` (R1–R12), on every awk installed
- `make test-mutants`: plugin controls P62–P93 for the checks, the contrast math, the token parser, the directions, the blueprint, the severity table, the dependency allowlist, the manifest keys and the skill rules
- `ascent-ux` trial calibration (read-only trial on two repositories, 2026-10-24): `check-web-accessibility.sh` reads HTML inside JS/TS template literals (single-page-app views, marked "[js template]") and judges an outline removal per selector against the `:focus-visible` rules; `check-token-contrast.sh` labels a plain `:root` palette "base", infers `text-*`/`bg-*` names without a `color-` prefix and accepts `--` in pair files; `--core` accepts paths with or without `./`; the blueprint's tables scroll inside a labelled, focusable region at 320 px; the browser pass is mandatory when Playwright is present, asks for a localhost server when `file://` is blocked, and reports any `.playwright-mcp/` folder; guessed core flows are labelled; contrast findings group by token; maturity gaps are always rated; the agent carries the `ux:` keys and never rates estimated contrast; `design-directions` offers a brand-adapted option and legible gallery screenshots. Controls P94 onward
- `ascent-ux` re-trial calibration (ground-turf-truth, 2026-10-25): the three scripts run awk with `LC_ALL=C`, so line numbers stay right after non-ASCII text and UTF-8 input can no longer stop a scan (in a UTF-8 locale U11 lines were up to 157 too low and a file could stop awk); U7 accepts an `<h1>` rendered by a scanned JS template as a NOTE; U12 follows delegated click listeners (`e.target.closest()` and `.matches()` on attribute, class and id selectors, "[delegated]"); U11 accepts a box-shadow ring in the same `:focus` rule as a NOTE, with its contrast not computed. NOTE lines are unrated and never a pass. Controls P108–P117

### Changed

- `make test-plugins` T5 also keeps every copy of the UX severity table (`ux-severity` markers) identical; new T12 fails on an unknown `plugin.json` key and on a dependency from another marketplace that is not allowlisted
- `docs/framework/DECISIONS/INDEX.md`: ADR-011 shown as Accepted (it was accepted in v0.4.4)
- `role-ui-ux-designer.md` points to `ascent-ux` as the single source of the role's checks
- ADR-012 Proposed → Accepted after the trial and re-trial (U-H)

---

## [0.4.4] — 2026-10-24

**Architecture plugin.** `ascent-architecture` 0.1.0 reviews any repository's architecture against a project contract (`.ascent/contract.yml`): a system map, quality attributes, design principles, deployment and dated cost estimates, with rated findings and a strong/moderate/weak rating. It ships a static-site blueprint on AWS with a template checker and a cost estimator. A read-only trial on a real repository (five runs) drove two calibration rounds before release. See [ADR-011](docs/framework/DECISIONS/ADR-011-architecture-plugin-and-project-contract.md), now Accepted.

### Added

- `plugins/ascent-architecture/` 0.1.0 (ADR-011): architecture review for any repository. Four hand-written skills — `architecture-review` (entry point: maps the system, surface checks for quality attributes, design principles, deployment and cost, maturity gaps; severity table and strong/moderate/weak rating), `quality-attributes` (measurable targets, met / at risk / unmeasured with evidence), `design-principles-check` (style detection; separation of concerns, coupling, SOLID, twelve-factor, API design) and `deployment-options` (five options compared by setup effort, dated monthly cost, operations burden and maturity fit; ADR draft; blueprint hand-off) — and a read-only `architecture-reviewer` agent
- `ascent-architecture` references: architecture principles P1–P12 with evidence, the six Well-Architected pillars, the Solutions Architect Professional lens, prototype/standard/enterprise maturity targets; AWS ↔ Azure ↔ Google Cloud component mapping; the `architecture:` section of the project contract `.ascent/contract.yml` (`.claude/contract.yml` where ASCENT-named files are not allowed)
- Blueprint `static-site-serverless-aws`: CloudFormation for a private S3 origin behind CloudFront (Origin Access Control, security headers, HTTPS only), an HTTP API on Lambda arm64 with DynamoDB on demand, retained data, point-in-time recovery, log retention, throttling, an error alarm and a monthly budget; passes `cfn-lint`; README with architecture, cost, effort, operator deploy runbook (change-set dry run, personal values as shell variables) and rollback
- `scripts/estimate-cost.sh` and pricing files (AWS us-east-1 list prices and CloudFront flat-rate plans with their feature tiers, as_of 2026-10-18, source URL per row): itemized monthly estimate, shared free-allowance pools, flat-rate comparison that honors `plan_needs_<feature>` rows, 90-day staleness warning, exit 2 on any unpriced or malformed usage line
- `scripts/check-cfn-static-site.sh`: 12 read-only per-resource checks (C1–C12) on CloudFormation YAML for the static-site pattern, N/A when a check's resources are absent, exit 2 on syntax it cannot read; CRLF and tabs accepted
- `tests/plugins/ascent-architecture/`: `test-estimate-cost.sh` (hand-checkable fixtures, pools, plan features, shipped files and documented totals, bad input) and `test-check-cfn.sh` (blueprint passes 12/12 in six layouts; one broken copy per defect fails that check and no other; severities agree across script, skill and output; `cfn-lint` when installed), on every awk installed
- `make test-mutants`: plugin controls P30–P61 for the agent, the estimator, the checker, the blueprint, its documented cost, the pricing version gate, the tests, the skill links, the severity tables and the trial-calibration rules (127 in total)
- `ascent-architecture` trial calibration (read-only trial on a real repository, 2026-10-24): off-table concerns go under "Other observations (unrated)" and never get an invented severity; new severity row for multi-step writes with no transaction or idempotency (Medium); repository-relative `file:line` evidence and fresh evidence per run; `architecture-review` names the pricing files and offers an illustrative estimate from the blueprint's sample profile; contract proposals use only the template's keys and `maturity_target` values; a missing target is unmeasured (or at risk when the evidence shows a gap), never met; client code and templates are searched for secrets, High even before publishing, and `ascent-security` is recommended whenever an item is referred to it; C1–C12 may be applied by reading setup scripts; `deployment-options` keeps the usage profile, script lines and ADR text in the report, defines `O<n>′` variants and detects targets like `architecture-review` Step 0. Pinned by `test-skill-rules.sh` (R1–R11)

### Changed

- `make test-plugins` T11 runs behavior tests for every plugin that ships `scripts/` as well as `hooks/`; a plugin with either and no tests fails, and so does a script that no test names
- `make test-plugins` T5 also requires every copy of the architecture severity table (`arch-severity` markers) to be identical
- `.claude-plugin/marketplace.json`: `ascent-architecture` entry (`/plugin install ascent-architecture@lloydbriantech-ascent`)

---

## [0.4.3] — 2026-10-18

**Security rules, version gate and the delivery-loop plugin.** `ascent-security` 0.1.1 rates short hardcoded secrets and dynamic code execution, both found by the first trial run. A new gate makes every plugin change carry a version bump so installed copies update. `ascent-delivery` 0.1.0 ships the delivery loop with a hook that blocks Claude from git writes and deploys. See [ADR-010](docs/framework/DECISIONS/ADR-010-delivery-loop-plugin-and-operator-boundary-hook.md).

### Added

- `make test-plugins` T10: fails when any file under a plugin changes while its `plugin.json` version stays the same, or when the version is not recorded. `make/plugins.lock` holds each plugin's version and content hash (`make/plugin-hash.sh`); `make plugins` writes a row when the version changes and warns, without changing the lock, when content changed under the same version
- `ascent-security-audit` Step 2: short hardcoded secrets (Medium) — a quoted literal of 4–7 characters with no spaces, assigned or compared to a key with a whole credential word (`pin`, `passcode`, `password`, `passwd`, `secret`, `token`, split at `_`, `-` and camelCase). Quoted digits count; findings cite `file:line` only
- `ascent-security-audit` Step 6: dynamic code execution (Medium) — `eval(` and `new Function(` in code files under the source locations, `scripts/` and root-level scripts, skipping commented lines, member calls such as `model.eval()`, look-alikes such as `evaluate(`, vendored directories and `*.min.js`
- Two Medium rows in the shared severity table (short hardcoded credential; dynamic code execution)
- `make test-mutants`: 15 mutants (M47–M61) for the two rules and their severities, and plugin control P14 (content changed without a version bump)
- `plugins/ascent-delivery/`: the delivery loop as a plugin for any repository — a hand-written `delivery-loop` skill (Steps 0–7: contract, decide, build with a file-modification audit, test with negative controls, gate and review, fix and definition of done, operator runbook, beta/prod verification and release record), a read-only `finding-verifier` agent, references (`.delivery-loop.yml` schema, runbook template with a `redact` helper, review lenses with provider-or-fallback prompts), `plugin.json` and README
- `ascent-delivery` operator-boundary hook (`PreToolUse` on Bash): blocks git writes, gh writes, deploys listed in `.delivery-loop.yml` and well-known deploy/publish verbs, through compound commands, subshells, substitutions (heredoc-aware), unquoted heredoc bodies, shells fed by stdin, `bash -c`, `eval`, `find -exec` and wrapper prefixes; contract entries match by command and positional words, ignoring flags; commands over 512 KB are blocked; portable bash and POSIX awk, no jq. Hardened after an independent adversarial review (174 cases)
- `.claude-plugin/marketplace.json`: `ascent-delivery` entry (`/plugin install ascent-delivery@lloydbriantech-ascent`)
- `tests/plugins/ascent-delivery/test-operator-boundary.sh`: 199 allow/block cases fed as real PreToolUse JSON, run on every awk found (mawk, gawk, BWK awk)
- `make test-plugins` T11: every plugin with `hooks/` has passing hook behavior tests with an `N/N PASS` summary, and `hooks.json` runs only scripts that exist
- `make test-mutants`: 15 plugin controls (P15–P29) for the hook (including heredocs in substitutions, the size guard, stdin shells, unquoted heredocs and contract chains), its tests, `hooks.json`, the verifier agent and the skill's links
- ADR-010: Delivery-loop plugin and operator-boundary hook (Proposed)
- `make test-mutants`: 95 in total (26 loop-1 mutants, 4 validator controls, M27–M61, P00 baseline, P01–P29)

### Changed

- `ascent-security` 0.1.1: generated skills carry the two new rules; the `security-auditor` agent rates short secrets under check 3 and adds check 7 (dynamic code execution, security-audit Step 6), so neither lands under "Other observations" any more
- `ascent-security-audit` reports 6 checks; "Aggregate and report" is now Step 7. `ascent-sec-posture` applies security-audit Steps 1–6 and counts dynamic-code findings under the credential-hygiene surface

---

## [0.4.2] — 2026-10-18

**Skill hardening, loop 1 (foundations).** Makes the embedded-skill test suite give the same answer on macOS, Linux and in containers, shows each rewritten check both passing and failing, proves it with named negative controls, runs all of it in CI on both platforms, and makes each skill's description do its routing. See [ADR-008](docs/framework/DECISIONS/ADR-008-portable-skill-tests-and-negative-controls.md).

**Skill hardening, loop 2 (`ascent-security` plugin).** The first ASCENT plugin, installable in any repository from Claude Code, VS Code or Cowork. Its skills are generated from the template so there is one source of truth. See [ADR-009](docs/framework/DECISIONS/ADR-009-plugins-generated-from-template-skills.md).

### Added (loop 2)

- `plugins/ascent-security/`: `env-audit`, `security-audit` and `sec-posture` skills (generated), a read-only `security-auditor` agent (Read, Grep, Glob), `plugin.json` and README
- `.claude-plugin/marketplace.json`: installs with `/plugin marketplace add lloydbrian/lloydbriantech-ascent`, then `/plugin install ascent-security@lloydbriantech-ascent`
- `make plugins` (`make/build-plugins.sh`): builds plugin skills from the template sources; fails if a placeholder survives
- `make test-plugins` (`make/test-plugins.sh`): drift and orphans, placeholders, name/version/source agreement with the marketplace, read-only agents (tools and frontmatter keys), read-only skill tool pre-approvals, the shared severity table in the skills that need it, links, frontmatter, agent step references, and `claude plugin validate` when the CLI is installed; added to the CI gate
- `make test-mutants`: 20 security-rule mutants (M27–M46), a baseline control and 13 plugin controls (P01–P13), each of which must fail on the check it names — 64 in total with loop 1's 26 mutants and 4 validator controls
- README section on installing ASCENT skills as plugins
- ADR-009: Plugins generated from the template skills

### Changed (loop 2)

- `ascent-security-audit` and `ascent-sec-posture` share one severity table (credentials are High in both); credential scanning covers object-style secret literals and `AKIA…` keys and never prints a matched value; nginx checks require CSP and HSTS, flag `location` blocks whose own `add_header` drops the security headers, and treat `X-XSS-Protection` as deprecated (Info)
- Credential findings and the security-audit report cite `file:line` and the rule name only, never the matched value or line; `.gitignore` forms (`/.env`, `*.env`, `.env*`) are recognized, and a missing `.gitignore` is High; container checks add `network_mode: host` and a mounted Docker socket; production-URL checks skip localhost, single-label service names and XML namespaces
- The three skills pre-approve only read tools (Read, Grep, Glob; `env-audit` adds `git ls-files` and `git log`)
- `ascent-sec-posture` rating rules are exhaustive: any High → weak; no Medium and critical surfaces assessed or not present → strong; otherwise moderate. A project with no compose files or Dockerfiles has no container surface ("not present") and can still rate strong; source code that cannot be located remains a gap
- `security-auditor` reports anything outside its six checks under an unrated "Other observations" section, so the rating stays comparable between runs (both found in the first trial run on a real repository)
- `ascent-env-audit`, `ascent-security-audit` and `ascent-sec-posture` detect source, compose, Dockerfile and nginx locations instead of assuming the ASCENT layout; `ascent-env-audit` drops its fictional component mode and exit code for a verdict line

### Added (loop 1)

- `tests/skills/lib/portable.sh` (template): GNU/BSD-safe helpers for file ages, backdating, DST-safe calendar dates, in-place sed, zero-safe match counts and git fixtures (`main` default branch, hooks disabled, isolated from the outer repository's git environment)
- `make test-skills` (meta-repo): renders the template with `make/render-template.sh` (fails if any placeholder survives) and runs all 28 embedded-skill tests
- `make test-mutants` + `make/mutants.tsv`: 26 named mutants guarding 12 tests, plus 4 validator controls; fails on any survivor, anchor miss or skipped row
- CI `gate` job: `make qa`, `make test-skills` and `make test-mutants` on `ubuntu-latest` and `macos-latest`
- `test-ascent-standup.sh` Test 6: exercises the shipped `make session-resume` classifier (FRESH, STALE, EMPTY)
- `.github/dependabot.yml` for the SHA-pinned actions
- ADR-008: Portable skill tests and named negative controls

### Changed (loop 1)

- All 28 tests source the portable library. The 8 that failed on Linux (delivery-status, doc-sweep, env-audit, health, reflect, self-audit, standup, vitality) now pass; BSD-only `sed -i ''` calls in adr-conformance, adr-write, feature-intake and qa were latent failures and are fixed too
- Rewritten tests assert on a passing and a failing fixture at threshold ±1 day: delivery-status, doc-sweep, env-audit, health, layering-check (now also routes→services and controller→storage), self-audit (now also an empty `phase`), skills-doctor, standup and vitality. The SKILL.md prose greps in self-audit and standup are replaced with behavior checks; "platform limitation" pass branches are removed
- All 28 skill descriptions and the parent skill's description lead with "Use when …" trigger phrases, point to the sibling skill where triggers overlap, and contain no template placeholders
- `qa-skill-frontmatter` enforces the trigger-first description, no placeholders in descriptions, and `name` matching the directory; accepts an optional root for self-testing
- `ascent-skills-doctor`, INTENT-MAP.md and the parent skill now state that Claude routes on the description; the parent defers to the project's `ascent-*` skills in enhance mode
- `ascent-env-audit` reports `.env.example` violations with values redacted
- `validate-skills.yml`: `permissions: contents: read`, `actions/checkout` pinned to the v4.2.2 commit; `release.yml`: `actions/checkout` and `softprops/action-gh-release` pinned to commit SHAs
- PR template and CONTRIBUTING: `make test-skills` / `make test-mutants`, portable helpers and a mutant per new rule are part of the checklist

### Fixed (loop 1)

- Template `make session-resume` misreported file ages on Linux (BSD-first `stat`) and its zero-line counts produced `0\n0`; the same zero-count bug in `make dev-status`
- `test-ascent-vitality.sh` no longer depends on a fixed 2026-05-18 fixture date, on git's default branch name, or on colored `git branch` output

---

## [0.4.1] — 2026-05-21

**Phase 3 retrospective.** Captures the 5 durable lessons from Phase 3 as framework artifacts: cluster-based PR discipline, four architectural patterns, process-leak class detection, behavior verification as Principle §16, and phase-plan discipline. Matches the v0.3.1 precedent — focused patch adding framework discipline between phase releases.

### Added

- Principle §16: Behavior verification, not documentation grep (`PRINCIPLES.md` + `ASCENT-INVARIANTS.md`)
- Patterns reference module (`skills/lloydbriantech-ascent/references/patterns.md`) formalizing 4 architectural patterns with concrete Phase 3 examples
- `RETROSPECTIVES/` directory established; first entry `PHASE-3.md` (~167 lines) narrates the 5 lessons in present-narrative voice
- 3 `CONTRIBUTING.md` sections under "Lessons codified from Phase 3" heading: cluster-based discipline, cross-cutting artifact verification, phase-plan discipline
- `make/qa-claimed-vs-actual.sh` validator (structural file-existence check against plan's artifact catalog)
- `make qa-claimed-vs-actual` target wired into `make/qa.mk`

### Changed

- Framework version: 0.4.0 → 0.4.1
- `PRINCIPLES.md`: 15 → 16 principles; relate-to-framework table row added for §16; 2-sentence pointer to `patterns.md` added to introductory framing
- `ASCENT-INVARIANTS.md`: "fifteen" → "sixteen"; §16 section added
- README badge: principles-15 → principles-16

### Decided

- **Phase retrospectives as a first-class surface.** `RETROSPECTIVES/` directory established as durable record of phase lessons. `PHASE-3.md` is the template for future phase retros: present-narrative voice, per-lesson "what this establishes" sections, named-skill sparsity, almost-went-wrong stories anchored to specific PRs.
- **Patterns library separate from principles library.** Patterns are descriptive shapes that emerged from practice (sibling, hybrid, detect-don't-ask, enumerate/summarize); principles are invariants. `patterns.md` serves a different role than `PRINCIPLES.md` — referenced for design choices, not audited for compliance.
- **Behavior verification as Principle §16.** The documentation-grep-is-not-a-test boundary established in Phase 3 Cluster 2 codifies as a framework invariant. Principle does not prescribe a specific test framework — behavior verification through mechanical stand-ins is the discipline; bash, Vitest, or other runners can implement it.
- **Structural-only verification for cross-cutting artifacts.** `qa-claimed-vs-actual` catches "file claimed in plan but absent in repo" — the exact failure mode from Phase 3's INTENT-MAP gap. It does NOT catch "file exists but content edit is missing" — that semantic check is deferred to v0.4.x or later. The validator's first useful run (Chunk 2) demonstrated both: it caught one genuine leak (quality.mk vs qa.mk path discrepancy in the plan) AND correctly reported PASS for 4 files that existed but had not yet received their Chunk 3 edits. Both results are the validator working as designed.
- **Phase-plan discipline generalizes from phase-scale to retro-scale.** `PHASE-3-RETRO-PLAN.md` (~196 lines, 3 implementation chunks) applied the same discipline as `PHASE-3-PLAN.md` (~500 lines, 8 implementation chunks). The self-test appendix documents what the smaller-scope application revealed.
- **Pattern emergence is retrospective, not designed.** None of the four patterns were named in `PHASE-3-PLAN.md`. Patterns emerged from specific design decisions and were recognized as recurring shapes only after multiple clusters applied them. Future phases should expect new patterns to emerge in the same order — design first, name second.

### Deferred to v0.4.x and beyond

- Semantic verification for cross-cutting artifacts (does file content match plan's intent?)
- Per-skill design retrospectives (phase-level retro only in v0.4.1)
- Pattern formalization for Phase 4 design (patterns.md is descriptive, not prescriptive)
- Phase 4 work itself (clean separation; Phase 4 opens against v0.4.1 baseline)
- Hardening of 14 specialized/conditional skills to baseline-deep depth (remains from v0.4.0 Deferred; not addressed in v0.4.1)
- License revisit — dual MIT/Apache-2.0 vs alternatives (remains from v0.4.0 Deferred; not addressed in v0.4.1)

### Statistics

- 4 PRs across v0.4.1 (Chunk 0 planning + Chunks 1-3 implementation)
- 5 lessons codified as 16 artifacts
- 1 new principle (§16) bringing total to 16
- 1 new reference module (patterns.md)
- 1 new RETROSPECTIVES/ surface
- 3 new CONTRIBUTING.md sections
- 1 new validator (qa-claimed-vs-actual)
- 383 internal markdown links validated by `make qa-links`
- 212 placeholder names validated by `make qa-template-placeholders`
- qa-claimed-vs-actual self-test: 14 PASS / 1 FAIL (plan-path discrepancy documented in appendix) / 1 SKIP

---

## [0.4.0] — 2026-05-20

**Phase 3 — Project-embedded skills.** Implements all 28 project-embedded skills that keep a scaffolded project disciplined as it grows. Each skill has gated-step operational logic, a corresponding bash test script with mechanical stand-in verification, and documented cross-skill relationships. The skills are organized across 8 implementation clusters, each shipped as a reviewed PR with behavior-verifying tests, full validator passes, and a review packet before merge.

### Added

#### Cluster 1 — Foundation (4 skills)

- `ascent-self-audit` — umbrella audit composing 3 sub-checks + 12 direct invariant checks (281 lines)
- `ascent-layering-check` — validates backend import graph: routes → controllers → services → storage
- `ascent-env-audit` — validates .env discipline: gitignored, empty defaults, code-reads match schema
- `ascent-observability-check` — validates logger, trace context, healthchecks, lifecycle events
- 4 test scripts with trap-based cleanup and per-test fixture subdirectories

#### Cluster 2 — Delivery (3 skills)

- `ascent-delivery-status` — surfaces current phase, exit-criteria progress, recommended next actions; §15 four-state integration
- `ascent-feature-intake` — decomposes requests into testable acceptance criteria; appends to working-memory.md per §15
- `ascent-standup` — summarizes recent activity into standup format; 24-hour default window
- 3 test scripts with §15 four-state classification stand-ins

#### Cluster 3 — Authoring (3 skills)

- `ascent-adr-write` — guides ADR creation with interview, numbering, INDEX.md update; atomic write (both or neither)
- `ascent-doc-stub` — generates persona-targeted documentation skeletons with provenance comments
- `ascent-make-target` — proposes correctly-named make targets with section-aware Edit placement
- 3 test scripts; write-tool boundary discipline established (valid paths only, never overwrite without confirmation, write as final step)

#### Cluster 4 — Health checks (5 skills)

- `ascent-data-health` — validates SQLite-WAL config: WAL mode, foreign keys, migration tracking, migration ordering
- `ascent-doc-sweep` — validates doc freshness: persona provenance, orphaned refs, 30-day stale TODO markers
- `ascent-dependency-health` — static package.json analysis: pinned versions, engines, traceability, unused deps
- `ascent-adr-conformance` — deeper ADR analysis: section completeness, INDEX sync, supersession bidirectionality, status consistency
- `ascent-skills-doctor` — validates skill collection: frontmatter, INTENT-MAP sync, cross-references, allowed-tools honesty
- 5 test scripts; sibling-not-component pattern introduced (skills read shared sources, no runtime invocation)

#### Cluster 5 — Lifecycle (3 skills)

- `ascent-reflect` — end-of-session interview capture; writes session-state.md (overwrite) + working-memory.md (append) per §15
- `ascent-handoff` — progressive-depth HANDOFF.md: "Where to start" / "Project state" / "Project conventions"
- `ascent-onboard` — read-only "first hour" walkthrough; detects project maturity from state
- 3 test scripts; detect-don't-ask pattern introduced (onboard detects project maturity from state); shared-artifact data flow through §15 layer

#### Cluster 6 — Quality gates (2 skills)

- `ascent-qa` — surface-level quality gate across 5 areas with conditional sub-skill recommendations (hybrid pattern introduced)
- `ascent-release-readiness` — pre-release validation: CHANGELOG, version consistency, clean tree, branch, tag uniqueness
- 2 test scripts; detect-don't-ask pattern reinforced from Cluster 5

#### Cluster 7 — Security/cost conditional (4 skills)

- `ascent-security-audit` — point-in-time: 5 static checks (env scope, credentials, privilege, headers, URLs)
- `ascent-sec-posture` — current-stance summary: severity classification, coverage gaps (drift detection deferred)
- `ascent-cost-posture` — cloud-generic cost discipline: resource declarations, retention docs, IaC presence
- `ascent-vitality` — activity/momentum signals: commits 14d, work items 30d, CHANGELOG 60d
- 4 test scripts; enumerate/summarize sibling pattern reinforced from Cluster 4 at 1:1 fan-in

#### Cluster 8 — Advanced conditional (4 skills)

- `ascent-health` — composite stance summarizer at 1:4 fan-in over Cluster 4 enumerators (baseline-deep, 196 lines)
- `ascent-ai-evals` — validates eval scenario structure and prompt-test coverage; no-ops when absent
- `ascent-design-system-audit` — validates token consistency and hardcoded values; no-ops on plain CSS
- `ascent-persona-coverage` — validates persona entry points and 3-click depth limit per §14
- 4 test scripts; enumerate/summarize generalized to 1:4 fan-in; detect-don't-ask for conditional skills

#### Test framework

- `assets/template/tests/skills/` directory with 28 bash test scripts
- `make test-skills` aggregator with per-skill `SKILL=<name>` filter
- Per-test fixture subdirectories at `.fixtures/<skill>/<scenario>/`
- Trap-based cleanup discipline across all 28 tests
- Behavior verification via mechanical stand-ins (not documentation-grep)

### Changed

- Framework version: 0.3.1 → 0.4.0
- INTENT-MAP.md: expanded from 9-skill routing table to full 28-skill table with intent mappings and cadences
- README.md: skill count "10 implemented, 18 in progress" → "all 28 implemented"; version badge 0.3.1 → 0.4.0
- ASCENT-INVARIANTS.md: updated "fourteen" → "fifteen"; added §15 Session resumption section

### Decided

- **Four architectural patterns** established and propagated across Phase 3:
  - Sibling pattern: introduced in Cluster 4 (adr-conformance, skills-doctor as siblings to self-audit); reinforced in Cluster 5 (reflect, handoff, onboard share §15 artifacts) and Cluster 7 (security-audit and sec-posture as siblings)
  - Hybrid pattern: introduced in Cluster 6 (ascent-qa self-executes surface checks, conditionally recommends sub-skills)
  - Detect-don't-ask: introduced in Cluster 5 (onboard detects project maturity from state); reinforced in Cluster 6 (release-readiness detects meta-repo vs scaffolded context)
  - Enumerate/summarize sub-pattern: introduced as a sub-pattern of sibling in Cluster 4 (adr-conformance enumerates, self-audit §7 summarizes); reinforced at 1:1 fan-in in Cluster 7 (security-audit enumerates, sec-posture summarizes); generalized to 1:4 fan-in in Cluster 8 (ascent-health summarizes across 4 Cluster 4 enumerators)
- **Cluster-based PR discipline** (established Cluster 1, refined through Cluster 8): each cluster ships as a single reviewed PR with behavior-verifying tests, full validator passes, review packet, pre-push spot-check
- **Behavior verification via mechanical stand-ins**, not documentation-grep — established discipline through all 28 tests
- **Lean-tier target at middle of range (~125 lines)**, not floor — calibrated from Cluster 5 observation
- **Conditional skill framing**: 7 of 28 skills ship as conditional. Single-sentence boilerplate announces Phase 4 scaffolder will gate inclusion; until then, skills exit gracefully when subsystem is absent
- **Composite stance definitions** (ascent-health): mutually exclusive classification ladder — Strong / Partial / Moderate / Weak — with not-assessed as honest partial coverage

### Deferred to v0.4.x and beyond

- Hardening of 14 specialized/conditional skills to baseline-deep depth
- Routing verification (real-use testing)
- Performance profiling
- True two-file atomicity for ascent-reflect (temp-file + rename)
- Drift detection for ascent-sec-posture (requires storage mechanism)
- npm audit / SBOM / CVE database for ascent-dependency-health and ascent-security-audit
- Conditional skill inclusion mechanism (Phase 4 scaffolder)
- Smoke-test extension to invoke `make test-skills` (requires scaffolded project context)
- License revisit (dual MIT/Apache-2.0 vs alternatives)

### Statistics

- 9 PRs across Phase 3 (Cluster 0 planning + Clusters 1-8 implementation)
- 28 SKILL.md files (14 baseline-deep, 14 specialized-lean)
- 28 bash test scripts with mechanical stand-in verification
- 368 internal markdown links validated by `make qa-links`
- 212 placeholder names validated by `make qa-template-placeholders`
- 4 architectural patterns established and propagated
- 8 implementation clusters, each shipping as a reviewed PR

---

## [0.3.1] — 2026-05-17

**Session resumption protocol.** ASCENT now treats session resumption as a first-class concern. Long projects span dozens of sessions; this patch makes "where we left off" an explicit, machine-readable artifact rather than something Claude is asked to remember.

### Added

#### Framework commitments (Chunk 1)

- Principle §15: Session resumption — project state is durable, machine-readable, and inspected on every session start
- `session-protocol.md` reference module — the authoritative specification: four file states (MISSING/EMPTY/STALE/FRESH), 6-step resumption protocol, capture discipline, verification mechanism
- ROADMAP v0.3.1 entry between Phase 2 (complete) and Phase 3 (awaiting signal)

#### Template artifacts (Chunk 2)

- `docs/delivery/` directory with README, `working-memory.md` (git-tracked, accumulating), `session-state.md` (gitignored, transient), `snapshots/` archive
- `make session-snapshot` — captures current state to `session-state.md` + archives to `snapshots/YYYY-MM-DD-HHMM.md`. Reads git state and `.ascent-meta.json` automatically; prompts for human-judgment fields.
- `make session-resume` — displays both files with MISSING/EMPTY/STALE/FRESH classification. The verification mechanism: shows exactly what Claude reads on session start.
- `CLAUDE.md.tmpl` protocol section — what Claude reads on session start: file-state handling, source-citation commitment, confabulation refusal, verification via `make session-resume`
- `.gitignore.tmpl` updated: `docs/delivery/session-state.md` gitignored (transient); `working-memory.md` stays tracked
- `make/session.mk` with `SHELL := /bin/bash` pinned for `local` variable support

#### Skill scaffold extensions (Chunk 3)

- `ascent-delivery-status` operational-logic paragraph extended: reads `session-state.md` for current focus + `working-memory.md` for accumulated decisions into status synthesis
- `ascent-feature-intake` operational-logic paragraph extended: writes locked acceptance criteria as dated entries to `working-memory.md`

### Changed

- Framework version: 0.3.0 → 0.3.1
- Principles count: 14 → 15
- ROADMAP.md: v0.3.1 ✅ complete; Phase 3 status note about §15 skill extensions
- CLAUDE.md (framework): v0.3.1 complete
- `session-protocol.md` cross-references: stale "template lands in v0.3.1 Chunk 2" suffixes replaced with substantive descriptions (templates now exist)

### Decided

- **Four-state file classification** (MISSING/EMPTY/STALE/FRESH) — eliminates ambiguity; truly-empty scaffold ships as EMPTY by design
- **Dual-write architecture** — `session-state.md` (current state, overwritten) + `snapshots/YYYY-MM-DD-HHMM.md` (history, git-tracked)
- **`session-state.md` gitignored, `working-memory.md` tracked** — transient vs accumulating concerns separated cleanly
- **No make target aliases** — `make session-snapshot` is canonical; `make session-checkpoint` was considered and dropped (Principle 2: one name per operation)
- **Citation-by-filename + `make session-resume`** — the honest verification chain; Claude refuses to confabulate prior context not grounded in the files
- **`session-state.md.tmpl` ships truly empty** (title only) — classifies as EMPTY on session start until first `make session-snapshot` populates it; avoids ambiguity between EMPTY and FRESH states

### Deferred

- Full `ascent-delivery-status` skill implementation reading session state into synthesis — Phase 3
- Full `ascent-feature-intake` skill implementation writing locked criteria to working memory — Phase 3
- Automatic-on-commit capture (git hook integration) — Phase 3 design discussion
- Claude-judgment-based capture during sessions (recognizing decision-moments) — Phase 3 design discussion
- `.ascent-meta.json` extension for configurable staleness threshold — currently hardcoded at 7 days

### Statistics

- 3 PRs (#18, #19, #20) across 3 chunks of v0.3.1 work
- 1 new principle (§15) + 1 new reference module + 5 new template files + 4 surgical template edits + 2 skill scaffold extensions + 4 stale-suffix cleanups
- 80 files / 167 placeholder names validated by `make qa-template-placeholders`
- 298 internal markdown links validated by `make qa-links` across 58 files

---

## [0.3.0] — 2026-05-16

**Phase 2 — Template assets.** The substantive baseline content for every file the architect role emits at scaffold time. After this phase, a project scaffolded from these templates produces a working stack: `make dev-up` boots backend + frontend + nginx; the layered API serves CRUD operations; observability emits per contract; tests pass.

### Added

#### Root template files (Chunk 1)

- `assets/template/` directory established with README.md.tmpl, CLAUDE.md.tmpl, CHANGELOG.md.tmpl, .ascent-meta.json.tmpl, LICENSE files, .gitignore.tmpl, .dockerignore.tmpl, .env.example, .claudeignore.tmpl, .editorconfig
- `make qa-template-placeholders` validator: validates every `<<PLACEHOLDER>>` token against the canonical 20-name set
- `FRAMEWORK_VERSION` bumped to 0.3.0 (lockstep); `<<PROJECT_VERSION>>` added as 20th canonical placeholder

#### Make framework (Chunk 2)

- Project-level Makefile + 9 child `.mk` files using SDLC section order META · DEV · TEST · QA · SEC · VALIDATE · DOCS · INFRA
- Real targets: `make help`, `make version`, `make status`, `make dev-up`/`dev-down`/`dev-logs`/`dev-shell`/`dev-restart`/`dev-clean`, `make dev-status`/`dev-status-quick`, `make engine-clean-project`/`engine-clean-images`/`engine-clean-volumes`
- 17 stub targets across 6 `.mk` files using project-level `[STUB] implement when <context>` convention

#### Container topology (Chunk 3)

- docker-compose family: dev (base), prod (overrides), prod.local (local testing), dist (standalone), suite (test runner)
- nginx/ skeleton: dev (Vite proxy + HMR), prod (static + security headers + caching), dist (standalone)
- Backend healthcheck enables `depends_on: condition: service_healthy` for nginx
- All resources labeled `project=<<PROJECT_LABEL>>` per Principle 9

#### Backend skeleton (Chunk 4)

- Working `server.js` with Express + structured logging + graceful shutdown (SIGTERM + 15s drain)
- Full `routes → controllers → services → storage` layering with `/api/items` GET + POST
- `/healthz` (liveness, no DB) + `/readyz` (readiness, DB + schema check) — deliberately differentiated
- SQLite-WAL via `better-sqlite3` with migration runner (~30 lines, no library dependency)
- Middleware: request-id (W3C TraceContext extraction), pino-http logger, error handler (sanitized in prod)
- Observability: structured logger, trace utilities, metrics counter scaffold
- Multi-stage Dockerfile (builder + production + development) with `build-base python3` for native compilation
- Vitest test file (3 tests) proving the runner works
- Pinned dependencies (no `^` or `~`): express 4.21.2, better-sqlite3 11.7.0, pino 9.6.0

#### Frontend skeleton (Chunk 5)

- Vite + React 19 shell with working `/api/items` integration (GET list + POST form)
- Three-stage Dockerfile (builder + production + development) with development as last stage (compose default)
- `server.host: '0.0.0.0'` in vite.config.js + package.json dev script (Vite-in-Docker gotcha prevented)
- Plain CSS styling (system-ui font, minimal, not opinionated about framework)

#### Project ADRs (Chunk 6)

- 7 always-emitted project-level ADRs using canonical template (Context, Decision, Alternatives, Consequences, Cost implications)
- ADR-001 Container-first, ADR-002 Backend layering, ADR-003 Make vocabulary, ADR-004 SQLite-WAL, ADR-005 JSON logging, ADR-006 Dual licensing, ADR-007 Phase-gated delivery
- INDEX.md with supersession documentation ("ADR-008 supersedes ADR-004 for projects choosing Postgres")
- Cross-reference graph: ADR-002→001, ADR-004→002, ADR-005→001, ADR-007→003

#### Embedded skills (Chunk 7)

- 9 baseline `ascent-*` project-embedded skill scaffolds at substantive-scaffold standard
- Structural enforcement (5 read-only): ascent-self-audit (umbrella), ascent-layering-check, ascent-env-audit, ascent-observability-check, ascent-delivery-status
- Authoring assistance (4 write-capable): ascent-adr-write, ascent-doc-stub, ascent-make-target, ascent-feature-intake
- INTENT-MAP.md: intent→skill table with cadence column (per-commit, daily, per-feature, per-decision, per-deploy)

#### Smoke test (Chunk 8)

- `tools/scratch/scaffold-hello-world.sh` — one-shot scaffold script (cp + sed substitution)
- `tools/scratch/SMOKE-TEST-LOG.md` — durable verification evidence (14/14 steps PASS)
- 5 template bugs found and fixed during smoke test (documented in log)

### Changed

- Framework version: 0.2.0 → 0.3.0
- `ROADMAP.md`: Phase 2 marked ✅ complete; Phase 3 marked ⏸️ awaiting signal
- `CLAUDE.md` phase status: Phase 1 complete → Phase 2 complete
- `.gitignore`: `tools/scratch/` pattern adjusted to allow tracking scaffold scripts while ignoring outputs
- Backend Dockerfile: added development stage (last) + `npm ci` → `npm install` (lockfile not required at scaffold time)
- Frontend Dockerfile: `npm ci` → `npm install` (same lockfile fix)
- `docker-compose.yml`: backend data volume changed from named to bind mount for dev (host-visible for dev-status)

### Decided

- **Substantive-scaffold standard** for embedded skills: Frontmatter + Header + Inputs/Outputs + Operational-logic paragraph + Examples pointer + Anti-patterns paragraph. Phase 3 fills in full decision trees.
- **5+4 split** for project-embedded skills: 5 read-only audit/check + 4 write-capable authoring assistance
- **SQLite-WAL as default database** (ADR-004) with documented supersession path to Postgres when projects outgrow it
- **Three-stage Dockerfile pattern** (builder + production + development) with development as last stage = compose default
- **Backend healthcheck + nginx `service_healthy` dependency** closes the `make dev-up` → immediately ready gap
- **Container-first dependency management** — host `npm install` removed from scaffold; container handles deps per Principle 1
- **`npm install` over `npm ci` in Dockerfiles** — templates ship without lockfiles; `npm install` generates them at build time

### Deferred

- 22 additional project-embedded skill scaffolds (5 baseline remaining + 7 specialized + 8 conditional) — Phase 3
- Production scaffolding script (`scaffold.py`, `bootstrap.py`, `enhance.py`, `migrate.py`) — Phase 4
- Phase 4 carry-forward: how `scaffold.py` handles host Node version compatibility (container-only vs hybrid vs host-aware)
- Eval test scenarios — Phase 5
- Starter repo generation tooling — Phase 6
- First production project scaffolded from ASCENT — Phase 7

### Statistics

- 8 PRs (#9–#16) across 8 chunks of Phase 2 work
- 75+ template files scanned by `make qa-template-placeholders`; 165 unique placeholder names validated against canonical 20-name set
- 10 SKILL.md files validated by `make qa-skill-frontmatter` (1 parent + 9 embedded)
- 293 internal markdown links validated by `make qa-links` across 57 files
- 1 functional exit criterion met: 14/14 smoke test steps PASS (first in framework history)
- 5 template bugs found and fixed during smoke test (durable evidence in `tools/scratch/SMOKE-TEST-LOG.md`)

---

## [0.2.0] — 2026-05-15

**Phase 1 — Parent skill skeleton.** The framework's first executable layer. SKILL.md with routing logic, 21 reference modules, the `make` operator vocabulary, and the QA validators that keep them honest.

### Added

#### Operator vocabulary (Chunk 1)

- Root `Makefile` and `make/*.mk` SDLC-sectioned tree (META · DEV · TEST · QA · DOCS · DIST · RELEASE)
- Working targets: `make help` (default), `make version`, `make status`, `make install` / `make uninstall`, `make qa-skill-frontmatter`, `make qa-links`, `make qa`, `make release-tag`
- Stub targets per Principle 4 (stub-first naming): `make test`, `make doc-stub`, `make package`, `make release`
- Bash 3.2–compatible validator scripts: `make/qa-skill-frontmatter.sh`, `make/qa-links.sh`, `make/help.sh`

#### Parent skill (Chunks 2 + 6)

- `skills/lloydbriantech-ascent/SKILL.md` — frontmatter (name, description, version 0.2.0, allowed-tools), trigger conditions, operating modes table, nine-role mental model, references index, routing logic (3 stages per ADR-001), 13 representative examples, "does not engage when" boundary

#### Reference modules — protocols and conventions (Chunk 3)

- `references/ASCENT-INVARIANTS.md` — 14 invariants in runtime form
- `references/MAKE-NAMING.md` — make-target naming convention
- `references/SLUG-CONVENTIONS.md` — slug taxonomy and derivation
- `references/PHASE-PROTOCOL.md` — phase-gated delivery contract
- `references/ENV-DISCIPLINE.md` — `.env` handling rules
- `references/ADR-TEMPLATE.md` — canonical ADR format

#### Reference modules — practices and style (Chunk 4)

- `references/feature-lifecycle.md` — happy-path role flow
- `references/observability-contract.md` — JSON logs / Prometheus metrics / W3C traces baseline
- `references/writing-style.md` — voice, tense, anti-patterns (dogfooded with framework prose)
- `references/doc-architecture.md` — doc-graph rules, 3-click depth limit
- `references/audience-mapping.md` — canonical persona→entry-point mapping
- `references/external-services-integration.md` — vendor pattern (wrapper, retry, secrets, observability)

#### Reference modules — roles (Chunk 5)

- `references/role-delivery-lead.md` — phase plans, escalation, kill criteria
- `references/role-architect.md` — design discipline, ADR practice, specialist engagement
- `references/role-ui-ux-designer.md` — design system, accessibility-as-design
- `references/role-developer.md` — backend layering + frontend conventions (one role per ADR-001)
- `references/role-data-engineer.md` — schema, indexing, migration safety
- `references/role-ai-engineer.md` — prompts, evals, model abstraction, safety guardrails
- `references/role-tester.md` — test discipline hierarchy, NFR catalog, traceability
- `references/role-devops.md` — CI/CD, AWS, observability collection, releases
- `references/role-cybersecurity.md` — baseline, threat modeling, secret management

#### Repository hygiene (between v0.1.0-alpha and v0.2.0)

- `.github/SECURITY.md` — vulnerability disclosure policy
- `.github/CODE_OF_CONDUCT.md` — concise community expectations
- `.github/CODEOWNERS` — automatic PR review assignment

### Changed

- Repository visibility flipped from private to public for the duration of development (originally planned for v1.0)
- `CLAUDE.md` phase status: Phase 0 — Foundation → Phase 1 — Parent skill skeleton (complete)
- `docs/framework/ROADMAP.md`: Phase 1 marked ✅ complete; Phase 2 marked ⏸️ awaiting signal
- `README.md` adds "Documentation by persona" section referencing `audience-mapping.md` as canonical (per architectural review during Chunk 4)
- `CONTRIBUTING.md` adds "Cross-linking in reference modules" rule statement codifying the document-map discipline applied across all 21 reference modules
- `SKILL.md` Operating modes section: ADR-003 second mention demoted to plain text (Rule 1 violation cleanup)

### Decided

- **Cross-linking discipline for reference modules.** Each module's header carries 1–2 authoritative links; body content links to siblings, ADRs, and `docs/framework/` documents on first mention only; subsequent mentions stay as code spans or plain text. Code paths, make targets, and skill names stay as code spans regardless. Forward references to unlanded modules stay as code spans until promotion. The full 7-rule statement lives in `CONTRIBUTING.md`.
- **Routing logic operationalizes ADR-001's three-stage shape:** mode detection (`.ascent-meta.json` per ADR-003) → role inference (explicit, implicit, or multi-role expansion) → reference-module loading (always / per-mode / per-role, lazily).
- **Minimum-sufficient principle.** Engage the smallest set of roles that fully covers the task. When intent is ambiguous, ask a clarifying question; multi-role expansion is the wrong default response to ambiguity.
- **Skill talks but does not yet write.** Phase 1 constraint upheld; scaffolding scripts arrive in Phase 4.

### Deferred

- Template assets (substantive baseline content for every file the architect role emits) — Phase 2
- Project-embedded skill SKILL.md files (14 baseline + 8 conditional) — Phase 3
- Scaffolding scripts (`scaffold.py`, `bootstrap.py`, `enhance.py`, `migrate.py`) — Phase 4
- Eval test scenarios — Phase 5
- Starter repo generation tooling — Phase 6
- First production project scaffolded from ASCENT — Phase 7

### Statistics

- 7 PRs across the v0.1.0-alpha → v0.2.0 development window (PR #1 hygiene + PR #2–#7 substantive chunks)
- 21 reference modules under `skills/lloydbriantech-ascent/references/`
- `SKILL.md` grew from 0 lines to 296 lines across the phase
- `make qa-links` validates 263 internal markdown links across 39 files; `make qa-skill-frontmatter` validates 1 SKILL.md

---

## [0.1.0-alpha] — 2026-05-14

**Phase 0 — Foundation.** Meta-repository foundation. Framework identity, conventions, and architectural decisions established. No skill code yet — this release is the rationale, scope, and decisions that will guide every subsequent phase.

### Added

#### Framework identity

- `README.md` — framework overview, install paths, role inventory, mode taxonomy, project-embedded skill catalog, documentation map
- `CLAUDE.md` — working conventions for the meta-repository itself
- `LICENSE`, `LICENSE-MIT`, `LICENSE-APACHE` — dual MIT/Apache-2.0 licensing
- `CONTRIBUTING.md` — contribution model, versioning approach, review bar, role-addition criteria

#### Framework documentation

- `docs/framework/PRINCIPLES.md` — the fourteen ASCENT invariants in narrative form
- `docs/framework/PHILOSOPHY.md` — why ASCENT exists, what problems it solves, what it deliberately is not
- `docs/framework/SCOPE.md` — what ASCENT is for, what it isn't, the exit story
- `docs/framework/ROADMAP.md` — phase plan from v0.1 to v1.0 with exit criteria per phase
- `docs/framework/ARCHITECTURE.md` — the framework's own architecture: meta-repo + skill + starter + project-embedded layer

#### Framework decisions (ADRs)

- `ADR-001` — single parent skill (consolidated from six-role design) to avoid trigger collision
- `ADR-002` — modify-not-overwrite contract for all skill interactions with existing files
- `ADR-003` — `.ascent-meta.json` as project-root marker for mode detection (scaffold / enhance / migrate)
- `ADR-004` — slug conventions (kebab-case, 2–4 segments, mechanical derivations)
- `ADR-005` — skill naming convention (`lloydbriantech-ascent` parent, `ascent-*` project-embedded)
- `ADR-006` — dual MIT/Apache-2.0 licensing (Rust-ecosystem convention)
- `ADR-007` — template repo pairing (`lloydbriantech-ascent-starter` generated from skill via CI)

#### Tooling and editor conventions

- `.gitignore` — Python, Node, OS, and editor patterns
- `.editorconfig` — consistent indentation, line endings, final newlines across editors
- `.github/workflows/validate-skills.yml` — CI placeholder for Phase 1+ skill validation
- `.github/workflows/release.yml` — CI placeholder for Phase 6+ release pipeline
- `.github/ISSUE_TEMPLATE/{skill-bug, new-skill-proposal, enhancement}.md` — structured intake templates
- `.github/PULL_REQUEST_TEMPLATE.md` — PR checklist aligned with framework conventions
- `.vscode/{extensions, settings, tasks}.json` — recommended VS Code config for working on the framework

### Decided

- The framework is dual-licensed MIT OR Apache-2.0 at the user's option
- The framework dogfoods ASCENT conventions on itself wherever applicable
- The framework version applies to both the skill and the starter repo in lockstep
- Phase 0 ships no executable code — only identity, conventions, and decisions

### Deferred

- The Makefile and `make/` operator vocabulary — arrives in Phase 1
- The skill itself (`skills/lloydbriantech-ascent/SKILL.md`) — arrives in Phase 1
- Reference modules (~30 files) — arrives in Phase 1
- Template assets — arrives in Phase 2
- Project-embedded skill SKILL.md files — arrives in Phase 3
- Eval test scenarios — arrives in Phase 5

---

[Unreleased]: https://github.com/lloydbrian/lloydbriantech-ascent/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.3.1
[0.3.0]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.3.0
[0.2.0]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.2.0
[0.1.0-alpha]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.1.0-alpha
