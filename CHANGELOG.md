# Changelog

All notable changes to the `lloydbriantech-ascent` framework will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Dates are in **America/New_York** timezone.

---

## [Unreleased]

### Planned

- Next, `ascent-session`, `ascent-adr`, `ascent-docs`, `ascent-node-stack` (decisions 2026-10-18; order confirmed 2026-10-24 and 2026-11-16)
- `ascent-security`: authenticated live checks, and a trial of the three scanner images against a real target, when a project needs them (ADR-026)
- Tests: the `edit()` helpers of `test-check-drills.sh`, `test-check-ops-manuals.sh` and `test-check-iac-config.sh` do not fail a case when their awk edit fails, as `test-check-threat-model.sh` now does
- Then auditability for projects (Compliance) and the `ascent-governance` conductor, deferred in ADR-015; "Recommended next" also names uninstalled plugins whose signals are present
- `ascent-quality`: more languages (Java, Ruby, Rust, .NET) when a trial needs them (ADR-019); Gatling and JMeter when a trial needs them (ADR-021)
- `ascent-security`: the dynamic-code rule scans code files only; code embedded in shell scripts (e.g. `python -c "eval(…)"`) is listed under Other observations, not rated
- `ascent-architecture` 0.3.0 candidates: more blueprints (containers on Fargate, Terraform), `cfn-guard` rules, Azure and Google Cloud pricing; from the trial: cite a principle by its id and its exact name, rate a missing ADR for a one-way door as Low every time, and drop API rows from the illustrative estimate when no API is deployed
- Phase 4: scaffolding scripts (`scaffold.py`, `bootstrap.py`)
- Phase 5: test harness with three eval scenarios
- Phase 6: starter repo generation tooling
- Phase 7: first production project scaffolded from ASCENT

See [`docs/framework/ROADMAP.md`](docs/framework/ROADMAP.md) for the full roadmap.

---

## [0.4.22] — 2026-11-17

**Live security testing and the threat model.** `ascent-security` 0.3.0 checks what no file can show: how a running application answers a hostile request, and which threats each way in faces ([ADR-026](docs/framework/DECISIONS/ADR-026-live-security-testing-and-threat-model.md)). The operator runs every request from a runbook Claude writes, against a local or beta target; Claude rates the committed results. Claude drafts the threat model, and only a person reviews it.

### Added

- `ascent-security` skill `security-test`: Step 0 proposes `security.endpoints` and `security.live` from the routes; it checks the threat model first, shows a dry run, writes the runbook (pre-flight, the live checks, ZAP baseline, nuclei and dalfox in pinned containers, post-flight), then rates the results; `live-severity` table, copied into the agent
- `ascent-security` skill `threat-model`: drafts or updates `docs/security/THREAT-MODEL.md` with STRIDE per entry point (ids `EP-<n>` and `TH-<n>`), writes only that file, never fills `reviewed_on` or `reviewed_by`
- `scripts/run-live-checks.sh` (the operator's): headers, TRACE and CONNECT, six traversal payloads, nine disclosure paths, and with `--allow-writes` unauthenticated writes, an oversized and a malformed body, with `--allow-ai` a prompt-injection canary whose answer an echo cannot produce, and a burst of ten; no credentials, no response bodies kept; refuses hosts off the allow-list, production without `--allow-prod`, and anything but loopback inside Claude Code; `--dry-run`
- `scripts/check-live-results.sh`: `SEC-L1`–`L10`, the results file and ZAP JSON, nuclei JSONL and dalfox v3 JSONL reports, with waivers, a threshold and prototype notes
- `scripts/check-threat-model.sh`: `SEC-T1`–`T4`
- `references/live-rules.md`; the contract's `security.endpoints`, `security.live` and `security.threat_model`
- `security-auditor` checks 9 (threat model) and 10 (committed live results), by reading
- Tests: `test-run-live-checks.sh` against a Python test server on 127.0.0.1 (hardened, vulnerable and rate-limited modes, stopped after 300 seconds at most), `test-check-live-results.sh`, `test-check-threat-model.sh`, `test-live-rules.sh`
- Controls P917–P1000 in groups `ascent-security-live` and `ascent-security-threat`
- ADR-026

### Changed

- Framework 0.4.21 → 0.4.22; `ascent-security` 0.2.0 → 0.3.0
- The registry: skills `security-test` and `threat-model`, families `SEC-L` and `SEC-T`, the `live-severity` marker; the "threat model" and "security testing (live, operator-run)" domains are released
- The gate checks the `live-severity` table (T5)
- PILLARS: security testing (live) and the threat model move from Gap to Partial
- The README, CLAUDE.md, ROADMAP, ARCHITECTURE, the capability map and the banners for 0.4.22; the component figure is 32, the suite figure 56, the control figure 1065 (981 plus P917–P1000) and the decision figure 26

### Fixed

- Control P890 (v0.4.20) changed nothing under GNU sed, so on Linux it never removed the guard it tests: its `$` is now `[$]`. Every control's edit was checked under both BSD and GNU sed
- The live-checks test fixture no longer looks up its host's name when it starts, which outlasted the test's wait on GitHub's macOS runners; the test waits up to 30 seconds and prints an early stop as a `FAIL` line the gate reports

### Notes

- The scanner images are `zaproxy/zap-stable:2.17.0`, `projectdiscovery/nuclei:v3.11.1` and `hahwul/dalfox:v3.3.0`, tags checked on Docker Hub on 2026-11-17. The rater is tested on recorded reports, not on the scanners' own runs
- The read-only trial (2026-11-17): no model in `regimedesk`, `sports-tennis-ptc-scoring` or `lloydbriantech-test-platform` (SEC-T1 Medium each); a drafted STRIDE model for a copy of `regimedesk` (one open threat, unreviewed); the live checks against that copy on 127.0.0.1, stopped in the same step (33 results, two Low SEC-L1 headers). One calibration: an oversized-body probe skipped for write endpoints without sign-in is now SEC-L10 and SEC-L5 unmeasured, not N/A
- Not exercised before release: an https target (HSTS), the scanners against a real target, and the skills' full flow on a repository whose contract lists endpoints

---

## [0.4.21] — 2026-11-16

**Faster local verification, with the same checks.** Verifying v0.4.20 took two full runs of the negative controls, about 55 minutes each, the second after a fix that could not change a verdict ([ADR-025](docs/framework/DECISIONS/ADR-025-faster-local-verification.md)). Every run now shows where its time went, T11 runs the right test first, the slowest rules test is about eight times faster, and local reruns can reuse the kills whose inputs have not changed. CI and the final run before a release run everything, as before.

### Added

- `make test-mutants TIMES=<file>` (`ASCENT_MUTANT_TIMES`): every timed control, slowest first (seconds, status, id, group, check, cached); the summary adds the three checks and the three groups that took the most time
- `make test-mutants CACHE=<dir>` (`ASCENT_MUTANT_CACHE`): reuses the kill of a single-plugin T11 control when nothing it can read has changed (the control, its plugin and tests, `skills/`, `.claude-plugin/`, `make/test-plugins.sh`, the harness without the other controls' declarations, bash and awk); only kills are kept, the baselines always run, full mode ignores it, and CI never sets it
- `test-mutants-harness.sh`: the times file and seven cache cases (reuse, another plugin's edit kept, the plugin's, its tests' or the gate's edit rerun, full mode)
- `test-gate-fast.sh` G4: the edited path first, then its file name
- Controls P913–P916: T11's path tier and file-name fallback (`T14.G4`), and R13 for a named id and a range
- ADR-025

### Changed

- Framework 0.4.20 → 0.4.21
- `make/test-mutants.sh` passes T11 the edited path relative to its plugin; `make/test-plugins.sh` runs first the tests that name it, then those that name its file name. P368 moves to the new code
- `tests/plugins/ascent-ops/test-ops-rules.sh` R13: one awk pass per script instead of a `grep` per id and row, 2 seconds instead of 17 for the whole test; checked to print the same results as before on the real table and five broken copies, under bash 5 and 3.2 and three awks
- The README, CLAUDE.md, ROADMAP, ARCHITECTURE and the capability map for 0.4.21; the control figure is 981 and the decision figure 25

### Notes

- Measured on v0.4.20: T11 controls used 93% of the control time, and `ascent-ops` and `ascent-quality` controls took 40–53 seconds each. The behavior tests that spend their time running the script they test were left as they are
- The full run's floor is its baseline, about eight minutes for the whole gate; a later change can scope it to the controls that run
- Local verification runs on a frozen copy of the work tree, so the tree can be edited while it runs

---

## [0.4.20] — 2026-11-16

**A person accepts each change before prod.** `ascent-delivery` 0.2.0 adds an acceptance record to the delivery loop ([ADR-024](docs/framework/DECISIONS/ADR-024-acceptance-sign-off-and-delivery-contract-section.md)): Claude drafts the criteria and their evidence, only a person fills in who accepted each one and when, and `check-acceptance.sh` stops prod until the record passes. The same release closes the `ascent-ux` trial candidates in 0.3.1, with the first Firefox and WebKit walk on real repositories, points operations-only architecture items to `ascent-ops` in `ascent-architecture` 0.2.1, and makes a fresh scaffold pass its own operations checks.

### Added

- `ascent-delivery` 0.2.0 (ADR-024):
  - `scripts/check-acceptance.sh`, read-only: every criterion has evidence that exists in the repository (`DEL-A1`), a person accepted it by name on a real date (`DEL-A2`), and that person is a listed acceptor (`DEL-A3`); `--draft` checks the evidence only. Any failure stops prod
  - `skills/delivery-loop/references/acceptance-template.md`, the record: criterion, evidence, accepted by, accepted on
  - `references/contract-template.yml`, the `delivery:` section of `.ascent/contract.yml`, with `acceptance_dir` and `acceptors`
  - the definition of done drafts the record and runs `check-acceptance.sh --draft`; the beta step has a person accept and the operator commit the record; the prod runbook starts with the full check, and its Stop-if is any `FAIL`
  - runbook steps labelled [C] (read-only, Claude may run it) or [O] (writes, deploys or credentials: the operator only)
  - behavior test `tests/plugins/ascent-delivery/test-check-acceptance.sh` (60 cases on every awk found); `test-delivery-rules.sh` D4 to D8; union-contract cases in `test-operator-boundary.sh`
- `ascent-ux` 0.3.1:
  - UX-U12 matches delegated listeners in any scanned file, and compound selectors (`div.tile[data-act="go"]`); a key listener in the listener's file covers the key handler
  - UX-U11 computes a box-shadow focus ring's contrast against the page background, in every theme: under 3:1 is a finding, and a colour it cannot read (`currentColor`, an unknown token, an inset ring) is a NOTE
  - UX-F3 finds dead-end pages when more than one page is scanned: a full page with no link, form, button, script, back control or refresh (Low; Medium in a core file)
  - UX-R1 and UX-R2 read the relative imports of a file one level deep, so a guard or a visible error in a shared hook or service counts, and the finding names the modules read
- `ascent-architecture` 0.2.1: operations-only items go under Other observations marked `→ ascent-ops`, and Recommended next names `ascent-ops` when any item is
- Template: a fresh scaffold passes `OPS-Z3` and `OPS-Z8`, checked by `test-check-ops-scripts.sh` on a rendered scaffold
- Controls P840 to P912: `ascent-ux` (P840–P871, P908–P912), `ascent-architecture` (P872–P875), the template (P876–P880) and `ascent-delivery` (P881–P907)
- ADR-024

### Changed

- Framework 0.4.19 → 0.4.20; `ascent-delivery` 0.1.3 → 0.2.0, `ascent-ux` 0.3.0 → 0.3.1, `ascent-architecture` 0.2.0 → 0.2.1
- `ascent-delivery` reads the `delivery:` section of `.ascent/contract.yml` (or `.claude/contract.yml`); `.delivery-loop.yml` keeps working. The operator-boundary hook blocks the deploy commands of every contract it finds, and its message names the file and key
- Template: nginx pinned to `1.30-alpine` (the stable line) in `docker-compose.yml`, `docker-compose.dist.yml` and `frontend/Dockerfile`; the prod and dist images tagged `-${PROJECT_VERSION}`; `make/help.sh --help` prints its usage
- `ascent-ux`: the `plugin.json` description matches the marketplace's, and the README's Evidence line names the flow-integrity and reliability checks. The Firefox and WebKit install command uses the `playwright` version `@playwright/mcp` itself depends on, and `flow-check` Step 5 lists the engine differences that are not findings
- `ascent-architecture`: the README no longer calls `ascent-ux` planned
- OWNERSHIP: the `delivery` contract section, the `DEL-A` rule family, and user acceptance sign-off released; ROADMAP, the capability map, PILLARS, ARCHITECTURE, the README and CLAUDE.md for the new versions and the order of 2026-11-16

### Notes

- Order of 2026-11-16: `ascent-security` 0.3.0 next, then `ascent-session`, `ascent-adr`, `ascent-docs` and `ascent-node-stack`, then auditability for projects and the `ascent-governance` conductor
- The control figure is 977 (904 plus P840–P912), the suite figure 52 and the decision figure 24
- Firefox and WebKit trial, read-only, on three of the 0.3.0 trial repositories (a static site of 10 pages, a PWA served without its API, a single-page app), all verified unchanged afterwards. Firefox 159 and WebKit 27.2 walked every page and agreed with Chromium: the failed request shown as an empty list (UX-R2) and the page with no way out (UX-F3, also found by the new static rule) reproduced in both, and a reflow overflow at 320 px showed in both. No engine-only defect was found. Four engine differences, none of them findings, are now in `flow-check` Step 5:
  - WebKit on macOS moves Tab through form controls only; Option+Tab reaches links
  - Firefox gives focus to scrollable regions
  - WebKit and Chromium log a failed request to the console and Firefox does not, so UX-F5 is read from the network requests
  - WebKit once asked for a localhost page's images over https and failed with a TLS error; it did not come back on reload
- `npx playwright install` installs the browsers of the latest stable `playwright` (1.65.1), while `@playwright/mcp@latest` uses 1.66.0-alpha and needs Firefox 1573 and WebKit 2391; the README's command now installs those
- The `.delivery-loop.yml` contract is not removed; a project moves when the skill next runs and the operator agrees

---

## [0.4.19] — 2026-11-16

**The CI scope runs on macOS's bash 3.2.** v0.4.18's `make/gate-scope.sh` built the `--explain` group list with a `case` statement inside `$( )`. bash 3.2, macOS's `/bin/bash`, cannot parse that: it reported a syntax error, skipped the block and still exited 0. The five outputs CI reads were right, so the Scope job and Linux were unaffected, but T15 failed on macOS. The macOS gate and the macOS `scope` controls failed on main and on every pull request.

### Fixed

- `make/gate-scope.sh` builds the group list with a plain loop, not a `case` inside `$( )`
- T15 (`tests/meta/test-gate-scope.sh`) fails a case on any shell error (`<script>: line N: …`), so an error bash 3.2 skips past cannot pass. With the old line back, T15 fails 47 of its 52 cases under bash 3.2

### Changed

- Framework 0.4.18 → 0.4.19

### Notes

- v0.4.18's own pull request found the bug on macOS, but merged at its first commit, before the fix: the required checks are Repository structure and Internal links, and the macOS gate is not one of them
- Verified under bash 3.2 and bash 5
- No plugin changed, so no plugin version or `make/plugins.lock` row changed; no control was added, so the figures are unchanged

## [0.4.18] — 2026-11-15

**CI runs what a change can affect.** A pull request always runs the cheap checks, `make qa`, `make test-skills` and the plugin gate, on both platforms. The slow checks run only where its changed paths reach: behavior tests, T13.0, harness self-tests and negative controls. Every control that edits a changed file runs too, and every behavior test that reads one. Baselines run only what their controls are judged by, T13.0 runs in parallel, and a newer push cancels the older run. Pushes to main and the weekly run still run everything (ADR-023).

### Added

- `make/gate-scope.sh`: from the paths a change touches, which plugins' behavior tests T11 runs, whether T13.0 runs, which harness self-tests run, and which negative controls run, as whole groups or by id. Paths without a rule run everything. `--explain` gives each path's rule; CI writes it to the job summary
- `make gate-scope` and `make gate-changed`: the same scope for a local branch, against `origin/main` (or `BASE=<ref>`), with uncommitted and untracked files; `gate-changed` also runs it
- `make/test-mutants.sh`:
  - `--list` prints every control with its group, check, kind, file, T11 scope and T13.0 and T14 switches
  - `ASCENT_MUTANT_IDS` (`make test-mutants IDS="<id> ..."`) runs named controls only; an unknown id stops the run
- T15 (`make test-plugins`): the scope self-test, `tests/meta/test-gate-scope.sh`. 52 checks: fixture changes with all five outputs checked, the outside reads found in the repository's own behavior tests, and the repository's own control list
- `validate-skills.yml`:
  - a Scope job;
  - `concurrency`, which cancels a superseded pull-request run, never one on main;
  - gate, harness and negative-control jobs that follow the scope
- Controls:
  - the `scope` group, P813–P831 and P836–P839, each narrowing a scope rule;
  - P832, cases dropped from the fixture shards;
  - P833 and P834, the list forms of `ASCENT_ONLY` and `ASCENT_T11_ONLY`;
  - P835, a broken behavior test the baseline must catch
- T14 cases G13 and G14 (`tests/meta/test-gate-fast.sh`) and harness self-test cases for `--list`, named controls and an unknown id
- ADR-023

### Changed

- Framework 0.4.17 → 0.4.18
- A fast-mode baseline runs only the checks its controls name and the behavior tests of the plugins its T11 controls edit, plus T13.0 or T14 when a control needs them, instead of the whole gate; the fast-mode T11 baseline runs only when a control is judged by T11. Full mode keeps the whole gate. P00-ownership-baseline and P00-harness-baseline are folded into P00-baseline
- `ASCENT_ONLY` and `ASCENT_T11_ONLY` (`make/test-plugins.sh`) take lists; `ASCENT_T11_ONLY=none` runs no behavior tests
- `tests/meta/test-check-ownership.sh` runs its cases in parallel: each awk's cases are split into shards, as many in all as there are cores (`ASCENT_TEST_JOBS`), each on its own fixture copy. The shards must cover every case once per awk. About 2.8 times faster locally (104 s for three awks, from about 290); the harness keeps one shard, since its controls already run in parallel
- The ownership group's 13 checker-code controls, judged by T13.0, move to a new `ownership-checker` group, so a plugin or registry change runs `ownership` without them
- P794, P796 and P798 match any version or figure, so a version bump no longer edits them
- The harness self-test jobs run when the harness or the gate changes, and on main and weekly
- ARCHITECTURE, ROADMAP, CLAUDE.md, CONTRIBUTING, the capability map, the README and the PR template describe the scoped CI

### Notes

- The control figure is 904 (877 plus P813–P839) and the decision figure 23
- Review before release (correctness, checked against the code and by running it). Two under-selections, fixed:
  - `ascent-ops`'s behavior tests read the observability contract and the template;
  - `ascent-architecture`'s R12 reads every plugin's directory.

  Both are now found from the tests themselves (a `$ROOT/<path>`, a glob over every plugin), when the scope runs. Also fixed:
  - the Scope job's own output file sat in the checkout, untracked, and would have made every pull request run everything; it now goes to `$RUNNER_TEMP`;
  - the harness diff is read with git's colour, external diff and prefixes reset, and fails closed when no changed line is found;
  - a harness-group control line also runs `test-mutants-harness`;
  - a pipe that SIGPIPE could have misread is gone;
  - if the Scope job fails, the gate runs whole
- No plugin changed, so no plugin version or `make/plugins.lock` row changed

---

## [0.4.17] — 2026-11-15

**The headline figures in the banner, checked against the repository.** The README banner now carries the six figures on one line under the plugin line, which names all six released plugins, `quality` included. The ownership gate reads both banner files and the image's alt text, so the banner cannot drift from the repository.

### Added

- `docs/assets/ascent-banner-light.svg` and `-dark.svg`: a figures line in the plugin line's font, size and colour (`6 plugins · 30 components · 28 project skills · 51 test suites · 877 negative controls · 22 ADRs`); the banner grows from 320 to 356 px, and its description and the README's alt text repeat the plugins and figures for screen readers
- T13.11 (`make/check-ownership.sh`): in both banners, the plugin line must name exactly the released plugins, in any order, and a figures line must exist; every "N label" figure in the banners, their descriptions included, and in the README must match the repository, so a stray "4 plugins" anywhere in the README fails too
- `tests/meta/test-check-ownership.sh`: two fixture banners and cases for the banner, 100 checks per awk, up from 87 (a stale figure in each banner and the alt text, a two-digit figure, a thousands comma, leading zeros, a missing figures line, a missing banner, a missing, an extra and a reordered plugin, no plugin line, a stray README figure)
- Controls P804–P809 in the `ownership` group break a banner (a stale figure in each file, a stale description, `quality` dropped, the figures line removed, a banner removed); P810–P812 break the checker and must be caught by its fixture tests

### Changed

- Framework 0.4.16 → 0.4.17
- README: the "At a glance" section is removed, and its nav link opens the capability map instead; the Now, Next and Later table opens "Status and roadmap", and the capability-map link ends it; v0.4.12 moves into "Earlier releases"
- The banner's chart starts 30 px later along the same slope, at (790, 248), so its first point clears the longer plugin line
- The capability map's figures stay in its own table; control P795 now breaks the README's alt text, and P794 and P798 follow the version bump
- ARCHITECTURE, ROADMAP, CLAUDE.md, the capability map and the PR template describe the banner check

### Notes

- The negative-control figure counts declared controls: 877, 868 before this release plus P804–P812. A CI run of every group reports more, because each group also runs one or two baseline checks of an unmodified copy, which break nothing and are not controls (52 at v0.4.16: 920 in CI, 868 controls)
- No plugin changed, so no plugin version or `make/plugins.lock` row changed

---

## [0.4.16] — 2026-11-15

**A capability map, checked against the repository.** `docs/framework/CAPABILITY-MAP.md` shows what ASCENT can do today: every plugin with its skills, rules and next step, the parent skill and the roadmap, and the README opens with the same headline figures. The ownership gate counts every version and figure on both pages from the repository, so they cannot drift. A documentation audit brought the framework docs, GitHub templates and security policy up to date.

### Added

- `docs/framework/CAPABILITY-MAP.md`: at-a-glance figures (plugins released, plugin skills, agents and hooks, embedded skills, behavior-test suites, negative controls, decision records), one section per plugin, the parent skill, the roadmap and a table of every component. The claude.ai page stays as its visual copy
- README: an "At a glance" section with the same figures and a Now, Next, Later status; the four pillars as a table under "Why ASCENT"; "Built to be trusted" joins the plugin promises and the release bar; releases are listed newest first, with releases before v0.4.12 folded away
- Ownership check T13.11 (`make/check-ownership.sh`, `make ownership`): the map's row and heading for each released plugin give its `plugin.json` version and its skill, agent and hook counts; the parent skill row, "Counts from the repository at vX" and the parent `SKILL.md` version give the `Makefile`'s `FRAMEWORK_VERSION`; the six figures in the map and the README, and the README's plugin badge, are counted from the repository. A figure may carry a thousands comma
- `tests/meta/test-check-ownership.sh`: the fixture gains a map, a Makefile, controls, ADRs and test suites, and 17 cases for T13.11, among them a two-digit skill count, a control written with an environment prefix and a missing map (87 checks per awk)
- Controls P791–P799 in the `ownership` group break the map, the README or `SKILL.md` and must be caught by T13.11; P800–P803 break the checker and must be caught by its fixture tests (T13.0)
- "Checking this role in any repository" sections for the architect, cybersecurity and delivery-lead role references, pointing to their plugins, as the tester and devops references already do

### Changed

- Framework 0.4.15 → 0.4.16; the parent skill's `SKILL.md` version, which had stayed at 0.4.9, is 0.4.16 again and is now checked
- `.claude-plugin/marketplace.json`: the `ascent-ux` entry describes 0.3.0 (four principles, flow integrity and reliability checks, a browser walk of each core flow)
- `.github/SECURITY.md`: supported versions are the latest 0.4.x release and the latest version of each plugin; what counts as a security issue now covers plugin scripts, hooks and agents, a way around the operator-boundary hook, and a report that prints a secret
- ARCHITECTURE: the ownership gate's T13.1–T13.11, a continuous-integration section, the starter-repository build described as Phase 6 work, ADR-022 in the `ascent-ux` row, and "Reading further" through ADR-022, PILLARS, OWNERSHIP and the map
- CLAUDE.md: version, phase line, the layout's PILLARS and CAPABILITY-MAP, the `framework` and `release` commit scopes, the TEST and RELEASE make sections, eval scenarios as Phase 5 work, and `make release-tag`
- CONTRIBUTING: the version lockstep is enforced by T13.11; the Code of Conduct is linked; the Phase 3 export-and-push steps are marked as history
- PILLARS and SCOPE: the quality and security plugins also rate against the contract; the security gap is the threat model and live testing, not a vulnerability scan
- PRINCIPLES §16 names the plugin behavior tests and the negative controls; PHILOSOPHY links PILLARS, OWNERSHIP and the map
- ROADMAP: the current state, a v0.4.16 section, the 0.2.0 releases in the plugin rows, and ADR-013 shown as accepted
- DECISIONS/INDEX: ADR-022 under its exact title
- The PR template asks for OWNERSHIP rows and `make test-harness` when the harness changes; the enhancement template lists plugins
- `make status`, `make help` for `test-plugins`, the `validate-skills` and `release` workflow comments, and the make files' stale "lands in Phase N" headers describe what exists today

### Notes

- No plugin changed, so no plugin version or `make/plugins.lock` row changed. Two audit findings need a plugin bump and are listed under Unreleased: the `ascent-ux` `plugin.json` description and README Evidence line (0.3.1), and two `ascent-architecture` README lines
- ADR bodies, the Phase 3 plans and earlier CHANGELOG sections are records and were not edited

---

## [0.4.15] — 2026-11-13

**`ascent-ux` 0.3.0: functional, reliable, accessible, pleasant.** A review now asks whether users can finish the core flows and whether those flows survive a failed request, a double click, a reload or a lost connection, not only whether the pages are accessible. Four principles order the report as a ladder (functional, reliable, accessible, pleasant) and its headline names the lowest one at risk, with the unmeasured ones listed apart; severities still come only from the severity table ([ADR-022](docs/framework/DECISIONS/ADR-022-ux-principles-flow-integrity-and-reliability.md)).

### Added

- `references/flow-and-reliability.md`: three plugin-qualified rule families, `UX-F1`–`F7` (flow integrity), `UX-R1`–`R7` (reliability as experienced) and `UX-P1`–`P4` (pleasantness, observed and never met), defined once for both scripts, the skills and the agent
- `scripts/check-flow-integrity.sh` (UX-F1–F4, F7): links, form actions and router targets resolve across plain HTML, React Router, Vue Router, SvelteKit and file routes; in-page and ARIA id targets exist; each core-flow step has a way forward and a way out; a not-found route exists; build targets match the contract's browsers
- `scripts/check-ux-resilience.sh` (UX-R1–R7, UX-P1–P4): double-submit guards, a visible failure path for every request (fetch, axios, ky, XMLHttpRequest, API clients, data hooks), retry, drafts on long forms, view state in the URL, an offline notice, optimistic rollback, progress feedback, motion through tokens, no pre-checked consent, a way out after sign-up
- The `flow-check` skill: contract-driven runs of both scripts, a browser walk of each core flow (navigation only, unless `test_data` names a fixture and the target is localhost) and an engine loop the operator drives with one Playwright engine per launch
- Contract keys in the `ux:` section: `core_flows[].steps`, `core_flows[].test_data`, `engines`, `reliability` (`draft_fields`, `url_state`, `offline`) and `pleasant` (`motion_tokens`); every 0.2.0 contract stays valid, and a missing key makes its rule unmeasured
- Behavior tests `test-check-flow-integrity.sh` (337 checks) and `test-check-ux-resilience.sh` (277 checks), each run on BWK awk, mawk and gawk, with fixtures `flows-good` and `resilience-good`; `test-ux-rules.sh` gains R25–R38 (168 checks)
- Negative controls in two new groups, `ascent-ux-flows` (P612–P655, P719–P726, P743–P754, P767–P771, P789) and `ascent-ux-resilience` (P656–P703, P727–P742, P755–P766, P772–P773, P790), and P704–P718 and P774–P788 in `ascent-ux` for the skills and docs: 72 of 72, 81 of 81 and 89 of 89 killed

### Changed

- `ux-review` is rebuilt on the four principles over seven lenses: Flow integrity (new) under functional, Reliability (new) under reliable, and the five existing lenses under the principle they serve; it runs four scripts and recommends `flow-check` when the functional or reliable group is at risk
- `ux-reviewer` applies the UX-F, UX-R and UX-P static checks by reading; its severity table and the skill's stay identical, with rows for a core flow that cannot be completed (High), reliability gaps on core flows, pre-checked consent and a broken page off the core flows (Medium)
- `docs/framework/OWNERSHIP.md`: the `flow-check` skill, the three rule families, the two new lenses and the domain "UI reliability (as experienced)"; navigational integrity and cross-browser compatibility move from planned to released
- `ascent-ux` 0.2.0 → 0.3.0 in `plugin.json`, the marketplace entry and `make/plugins.lock`

### Fixed

- CI: fast-mode negative-control jobs get 25 minutes instead of 15 in `validate-skills.yml` (full mode stays at 40). Slow macOS runners took one group from 4 to over 15 minutes on the same code; a group that needs more than 25 is split, not given more time (ADR-022 decision 10)

### Notes

- Read-only trial on five real repositories: two tennis apps (TypeScript PWA, plain HTML), a lawn-care app (plain JS), a React registration form and a 130-page documentation site, all verified unchanged afterwards. About 15 false positives were fixed at the source, each with a behavior test and a control (P719–P742): `/*` in page text read as a comment, links built by concatenation, server templates resolved from their own folder, ids another file defines (now a NOTE), escaped quotes in script strings, UX-F4 on single-page apps, `pages/` outside Next, Nuxt, Astro and Gatsby, catch blocks around storage or parsing, failures handed to the caller, `finally` and re-render, `!ok` inside an expression, result objects, `${` in a template string, debounce guards, and sign-up words in headings and prose
- The Chromium walk confirmed the static findings that remained (missing ARIA targets, placeholder links, no not-found page) found three defects only a browser sees (inline scripts that never run because of a syntax error, pages with no link back to the site, tab state lost on refresh) and confirmed a static one (a failed request shown as an empty list). Its lessons are in `flow-check` Step 4. Firefox and WebKit were not run in the trial and are recorded as unmeasured
- Review before release (correctness of the two scripts, and consistency across the skills, agent, reference, contract template and ADR, checked by `finding-verifier`): 22 findings confirmed and fixed, among them an absolute or `../` PATH and route-file order breaking UX-F1, nested, JSX and server routes, a `{` in a route path that stopped BWK awk and gawk, bundles over 512 KB (now skipped with a NOTE: 25 s to 0.6 s on BWK awk), the walk allowed to submit outside `localhost` in `ux-review`, and ADR-022 decision 5 aligned with the severity table (UX-R3 and UX-R7 Low); controls P743–P766
- The contract-driven options (`--core`, `--flow`, `--url-state`, `--offline`, `--draft-fields`) were run on two of the trial repositories with a contract proposed as Step 0 would: every result held up against the code, and a wrongly guessed flow showed why guessed flows are labelled. The walk that types `test_data` and submits has been tested on fixtures only, and Firefox and WebKit have not run
- Product, test, operations and security review before release, checked by `finding-verifier`: 31 of 43 findings confirmed and fixed. Among them: the flow check took 163 s on a dense 465 KB page under BWK awk (now 3.8 s); the headline counted unmeasured principles as not met; a run with no contract listed every unmeasured target as its own Low finding (now one); the severity table had no rows for broken pages, unreachable pages and lost view state off the core flows; a link's query string, which can carry a token, was printed; and the reviewed repository is now treated as untrusted (contract values quoted, the `test_data` fixture kept inside the repository, no `git status` there, a warning before its dev server runs). The README shows how to add a Playwright server per engine; controls P767–P788
- CI on the release PR caught a check that failed at random: both scripts piped a file list into `grep -q` under `pipefail`, so when grep stopped at the first match the writer's broken pipe failed the check and a `--core` or flow-step file "is not among the scanned files" (exit 2; 15 in 720 parallel runs of the flow check, 2 in 720 of the resilience check). The lists are now read from a here-string, 0 in 1,680 runs on each script across BWK awk, mawk and gawk; a static check in both behavior tests keeps the pipe out, controls P789–P790
- The 0.2.0 trial calibrations (delegated listeners across files, box-shadow ring contrast) are left to 0.3.1 (ADR-022 decision 9)

---

## [0.4.14] — 2026-11-12

**Copy failures in the negative controls.** A repository copy that fails is reported as `COPY FAIL`, never as a verdict. On a macOS CI runner with a full disk, `tar: Write error` became the first line of a control's result and was counted as a surviving control named `r: Write err`, although the control had been killed.

### Fixed

- `make/test-mutants.sh`: `plugin_copy` checks both sides of the tar pipe and keeps tar's messages apart; a control, a baseline or a harness case whose copy fails prints `COPY FAIL <id> copying the repository failed: <tar's first message>` instead of running on a partial copy
- A control's stderr is written below its result line, indented, so the first line is always its status
- `COPY FAIL` is counted apart from killed and survived: the summary shows `copy fail N`, the totals line keeps its format and is followed by a line naming the controls that could not be copied, and any copy failure fails the run
- The baseline copies no longer end the whole run without a result when they fail

### Added

- Control P611 in the `harness` group: with `MUTANT_FAULT=copy-fail` every copy fails, and the harness must report `COPY FAIL`
- `tests/meta/test-mutants-harness.sh` counts `COPY FAIL`, and a new case puts a fake `tar` that fails every extraction on `PATH` and requires every other control to be reported as `COPY FAIL`, P611 confirmed, none survived, tar's message kept out of the status lines, and a failing exit

### Notes

- ADR-018 describes six `expect_case` controls in the `harness` group; with P611 there are seven. ADR-018 is unchanged
- No plugin changed, so no plugin version, marketplace entry or `make/plugins.lock` row changed

---

## [0.4.13] — 2026-11-01

**Load tests and mutation evidence.** `ascent-quality` 0.2.0 checks that a load test would fail when the service misses its latency or throughput target, and that there is evidence the tests fail when the code is broken ([ADR-014](docs/framework/DECISIONS/ADR-014-testing-ownership-and-dependency-scan.md), [ADR-021](docs/framework/DECISIONS/ADR-021-load-test-alignment-and-mutation-evidence.md)). The targets stay `ascent-architecture`'s: `p95_latency_ms` and `peak_rps` are read from `architecture.quality_targets`, never copied. Claude never runs a load test or a mutation tool.

### Added

- `ascent-quality` 0.2.0:
  - `test-evidence`: lists every load-test script with the p95 threshold it asserts, the rate it reaches and what runs it, and every mutation tool with its break threshold, its CI step and its reports; reads what the script cannot (rates set at runtime, virtual-user loads, Gatling and JMeter)
  - `check-test-evidence.sh`: `QA-L1`–`L5`, a k6, Artillery or Locust load test exists when a target is set, its p95 threshold is no looser than `p95_latency_ms`, its rate reaches `peak_rps` (k6 arrival-rate scenarios read one by one with their own `timeUnit`, Artillery `arrivalRate` and `rampTo`, Locust `constant_throughput` or `constant_pacing` times its users), it has an error-rate threshold and a CI step, make target, package script or runbook runs it; a load in virtual users is a NOTE, never a pass. `QA-M1`–`M4`, a mutation tool is configured (Stryker, PIT through Maven or Gradle, gremlins, mutmut, go-mutesting), its break threshold is at least `quality.mutation.min_score`, a CI step runs it, and the newest usable report in the repository (Stryker `mutation.json`, PIT `mutations.xml` or a score summary) is no older than `max_age_days` and scores at least `min_score`. Standard maturity requires `QA-L1`, `QA-L2` and `QA-M1`, enterprise all nine
  - The contract's `quality.mutation` block (`min_score` 60, `max_age_days` 90, `reports`)
  - `references/test-strategy.md`: a "Load tests and mutation evidence" section
  - Behavior tests: `test-check-test-evidence.sh` (184 cases on each awk), `test-quality-rules.sh` 192 cases (was 132), with the new skill in R5, R8, R9 and R11, the `mutation` keys in R7, the new script in R12, and R6 and R13 reading the rule families from the script headers
- Groups `ascent-quality-load` and `ascent-quality-mutation`, controls P519–P610: every rule, the k6 scenario, threshold and comment parsing, the report scoring and dating, the git safety options, the `--report` guards, the maturity levels, the skill's rules and the severity copy (T5)
- ADR-021

### Changed

- `quality-review` 0.2.0 has five lenses and runs three scripts; the `quality-reviewer` agent applies `QA-L` and `QA-M` by reading; both severity tables have rows for both families
- The package.json and make parsers and the make and npm-script expansion moved from `check-test-inventory.awk` to the shared `qa-common.awk`, unchanged except a cap of 500 expansions per command, so a crafted fan-out cannot exhaust memory; install commands (`pip install`, `go install`, …) are dropped by one shared function, which now also knows `go` and `cargo`. P380, P381, P457, P458 and P460 follow the code (P460 now uses `return`, which is legal in a function on every awk)
- `docs/framework/OWNERSHIP.md`: `test-evidence` registered, `QA-L` and `QA-M` families added, the load and mutation-evidence domains released
- PILLARS: performance efficiency and scalability read load-test thresholds and rates, functional suitability the mutation score
- The tester role module names `test-evidence`; README, ARCHITECTURE, ROADMAP and CLAUDE.md list the release

### Notes

- An independent review before release (correctness, security and privacy, tests, documentation), checked by `finding-verifier`, confirmed 35 of 41 findings, all fixed, each with a behavior test and a control where it is code; 5 were rejected and 1 left to the operator:
  - Report dating ran `git log` from the report's own folder, where a committed folder laid out like a bare repository could have supplied a config that runs a program. git now runs once from the current directory with bare-repository discovery, signature checks and fsmonitor switched off, dates by the author date (a rebase keeps it), and dates nothing in a shallow clone. `--report` must be a file inside the repository, never a symbolic link
  - k6 rates were the largest number anywhere in the file over its first `timeUnit`, so a `ramping-vus` stage target counted as a rate; each scenario is now read on its own. Block and line comments, several thresholds on one line and several p95 entries in one array are read correctly
  - A `docker run -u UID` counted as Locust users; installing locust or go-mutesting counted as running it; prose naming locust counted as a runbook; commented-out break thresholds counted; a "minimum mutation score" line was read as the score; any `errors.` in an Artillery file counted as an error threshold
  - A stray local report beside a usable one failed `QA-M4`; it is now a NOTE. A Java or Kotlin project had `QA-M1` N/A instead of FAIL
  - The new report name patterns took `src/mutation-score.js` for a report, which also hid it from `check-test-inventory.sh` and `check-tests.sh`; code files are never reports now
  - The docs claimed a "committed" report where the check reads any report in the repository, gave wrong ADR-021 consequences, and did not say PIT's `target/` folder must be listed under `reports`
- Left to the operator: whether `quality.mutation.min_score` makes `ascent-quality` the target owner of the mutation-evidence domain in OWNERSHIP.md (it stays `—`, like the test-types row)
- Read-only trial, on copies with `.env` files excluded, of four application and infrastructure repositories and this one: none has a load test, a mutation tool or a contract, so with no targets the only finding is `QA-M1` on the four with source files, and with example targets also `QA-L1`. The trial does not exercise the k6, Artillery, Locust or mutation-tool parsing on real files; the behavior tests do. `check-test-inventory.sh` and `check-tests.sh` give identical output before and after the code move on all five
- Checked on Linux in podman (Ubuntu 24.04, bash 5.2) with gawk and mawk, and on macOS with BWK awk and bash 3.2

---

## [0.4.12] — 2026-11-01

**Recovery drills and readiness exercises.** `ascent-ops` 0.3.0 checks that a backup has been restored, a failover has been run, a paging alert has reached someone and readiness has been seen failing, from records the operator commits after each drill ([ADR-014](docs/framework/DECISIONS/ADR-014-testing-ownership-and-dependency-scan.md), [ADR-020](docs/framework/DECISIONS/ADR-020-recovery-drills-and-readiness-exercises.md)). Claude never runs a drill and never writes a record; a record shows a drill was recorded consistently, not that it was honest.

### Added

- `ascent-ops` 0.3.0:
  - `recovery-drill`: finds the recovery paths and paging alerts, checks the drill records, proposes a `drills:` contract block from the IaC when it is missing, and writes a missing drill runbook as a new file; it never edits a runbook, a manual, the contract or a record
  - `check-drills.sh`: `OPS-R1`–`R8`, a runbook per recovery path with pre-flight, post-flight, rollback, Expect and Stop if; a passing record of each path within `ops.drills.max_age_days`; the newest passing drill's `measured_rto` and `measured_rpo` against `architecture.quality_targets`; evidence present, inside the repository and free of credentials, email addresses and phone numbers (values never printed); a failed drill followed up; the manual's restore date not behind the newest restore drill; failover declared in the IaC (Multi-AZ, Route 53 failover, global tables and clusters, read replicas) with a failover path. `OPS-X1`–`X3`, every paging alert exercised and reaching a role, readiness answering non-2xx with a dependency down, every alert runbook dry-run. Standard maturity requires `OPS-R1`–`R5`, enterprise all; a credential in a record is High at every level
  - `references/drill-records.md`: the record format and fields, durations, what a record must never hold, and a runbook outline per kind of drill
  - The contract's `ops.drills` block (`dir`, `max_age_days`, `paths`) and `page: true` on alerts
  - The blueprint's `runbooks/restore-db.md`, `runbooks/ready-failing.md` and a real restore drill, run in podman against PostgreSQL 16.4 (200 customers and 1,000 orders restored and counted, 2 seconds), with its record and evidence; the blueprint's `db` has a healthcheck
  - Behavior tests: `test-check-drills.sh` (164 cases), `test-check-iac-config.sh` 78 cases (was 70), and `test-ops-rules.sh` (150 cases) with R13, R14 and R16 extended to `check-drills.sh` plus R19 for the new skill's rules
- Group `ascent-ops-drills`, controls P461–P500, P503, P504 and P507 onward: every rule of `check-drills.sh`, the duration and date arithmetic, the maturity levels, the input guards, the skill's rules, the severity copy (T5) and the agent's keys
- Controls P501, P502, P505 and P506 for the `OPS-S8` fix, in `ascent-ops-calibration`
- ADR-020

### Changed

- `ops-review` runs four scripts and its Change and recovery lens reads the drill records; the `ops-reviewer` agent applies `OPS-R` and `OPS-X` by reading; the shared severity table has rows for both families; `sre-baseline.md` and `runbook-standard.md` describe drills
- `docs/framework/OWNERSHIP.md`: `recovery-drill` registered, `OPS-R` and `OPS-X` moved from Reserved to Rule-id families, the restore and failover and operational readiness domains released; the Reserved table may now be empty (T13.1); P207, P218 and P229 re-anchored, and P466, P467, P475 and P481 follow the review fixes
- PILLARS: recoverability and restore and failover proof Strong, operational readiness added
- The devops role module names `recovery-drill`; README, ARCHITECTURE, ROADMAP and CLAUDE.md list the release

### Fixed

- `OPS-S8` classified a Compose file as production or development by its absolute path, so a checkout under a folder named `dev`, `test` or `Developer` hid every production env file, and the environment-folder check of `check-iac-config.sh` matched the same way. Both now read the path relative to the scanned root (P501, P502). Control P178 anchors on the new code
- The blueprint's Troubleshooting Manual probed `/-/ready` with `curl` on the host, where the api publishes no port; it now runs the probe inside the api container

### Notes

- An independent review before release (correctness, security and privacy, operations, tests and documentation), checked by `finding-verifier`, confirmed 31 of 33 findings, all fixed, each with a behavior test and a control where it is code:
  - `OPS-R5` read a value after `=` as prose (`PGPASSWORD=… pg_restore`) and missed compact JSON, a password in a URL, bearer and basic tokens and a credential in a table row; messages printed raw record values. Every shape is now a High finding, and a value that is not plain and short is printed as `<value withheld>`
  - `OPS-R3` accepted a fresh failed drill as current and `OPS-R4` measured a stale pass; only a passing record within `max_age_days` makes a path current now, and R4 measures that record. Dates are checked against the calendar (no 31 February), a planned date in the manual no longer counts as a restore (`OPS-R7`), and a stale readiness record no longer passes `OPS-X2`
  - The `OPS-S8` fix itself classified files relative to the scanned path, so `check-iac-config.sh deploy/prod` hid that folder's name; the scanned folder's own name now counts
  - `check-drills.sh` validates `--today`, `--rto` and `--rpo`, follows a symlinked drills or IaC folder, and never hands `find` a path that starts with `-`; an empty record file is still read as a record
  - The blueprint restore runbook measured the RTO to the database, not to the api's readiness, kept the scratch volume and the dump (production data) after the drill, and put the scratch password in podman's arguments; the readiness runbook probed a port the api does not publish and could recreate the database. Both are rewritten, with every removal flagged and confirmed
  - The redaction in `drill-records.md` used GNU-only `sed`; it is now a `perl` line, tested on all five credential shapes
- A negative control showed that no test read an `--iac` folder named `-iac`; the test now puts a Multi-AZ resource there and expects `OPS-R8` to cite it
- Read-only trial, on copies with `.env` files excluded, of four application and infrastructure repositories and this one: none has an `ops:` contract, so every drill check is N/A on the four; on this repository, scanning `.` reaches the architecture blueprint's versioned S3 bucket and reports the Low `OPS-R1` "unmeasured", as designed. `homelab-docs` has a quarterly drill page whose only entry is a blank template row. The old and new `check-iac-config.sh` give identical output on all five
- The blueprint's restore drill ran in podman (`v0412-drill-src`, `v0412-drill-db`); the record notes two deviations from the runbook, which was revised after the drill
- Checked on Linux in podman (Ubuntu 24.04, bash 5) with gawk and mawk, and on macOS with BWK awk and bash 3.2

---

## [0.4.11] — 2026-10-31

**Test strategy.** `ascent-quality` 0.1.0 checks that a repository's tests can be trusted to catch a broken change: the test types the contract requires exist and CI runs them, every database, queue and HTTP client is reached by a test, every acceptance criterion and core rule is named by a test, and no test is focused, skipped without a reason, assertion-less or retried ([ADR-014](docs/framework/DECISIONS/ADR-014-testing-ownership-and-dependency-scan.md), [ADR-019](docs/framework/DECISIONS/ADR-019-quality-plugin-rules.md)). It reads the repository and never runs a test.

### Added

- `ascent-quality` 0.1.0, hand-written, no plugin dependencies:
  - `quality-review`, the entry point: the `quality:` contract section (proposed when missing), a test map, the inventory, traceability and hygiene lenses, maturity gaps and waivers, and a strong, moderate or weak rating from its `qa-severity` table
  - `test-inventory` and `check-test-inventory.sh`: `QA-I1`–`I5`, test types by path, name and import; CI steps followed through make recipes, `$(MAKE)` and npm, yarn, pnpm and bun scripts, three levels deep; integration boundaries and test doubles matched per language
  - `test-check` and `check-tests.sh`: `QA-T1`–`T4`, criterion ids (`AC-<n>[.<n>]` by default, ids in code fences ignored, a parent id counted through its children) and core rules traced to tests; `QA-H1`–`H4`, focused, skipped, assertion-less and retried tests, with test blocks read per language (JS and TS by parentheses, Go by braces, Python by indentation, bats by a closing brace in column 1) and project assertion helpers through `--helper`
  - `quality-reviewer`, a read-only agent with an identical copy of the severity table
  - Behavior tests: `test-check-tests.sh` (72 cases), `test-check-test-inventory.sh` (49), `test-quality-rules.sh` (132), each run under `/bin/bash` 3.2 and once per awk installed
- Groups `ascent-quality-inventory`, `ascent-quality-trace`, `ascent-quality-hygiene` and `ascent-quality-rules`, controls P377–P460: every script rule, the block-end and masking logic, the input guards, every skill rule but R12 (which only macOS's bash 3.2 can fail), the severity copy (T5), the agent's tools (T4) and steps (T9), the version (T3) and the tests themselves (T11)
- T5 checks the `qa-severity` table (`marked_table qa-severity quality`)
- ADR-019, the plugin's rules

### Changed

- `ascent-delivery` 0.1.3: the Tests lens uses `ascent-quality:quality-reviewer` first, then `engineering:testing-strategy`
- `docs/framework/OWNERSHIP.md`: `ascent-quality` released, with its components, the `QA-I`, `QA-T` and `QA-H` families (no longer reserved), a signals row and the unit, integration and contract, regression and end-to-end, and traceability domains; P207, P209, P221 and P222 anchor on rows that stay planned
- PILLARS: functional suitability Partial → Strong for traceability, test types and hygiene
- The tester role module names the plugin; README, ARCHITECTURE, ROADMAP and CLAUDE.md list it
- CI: the negative-control jobs time out after 15 minutes in fast mode again, as ADR-017 decision 5 and ADR-018 decision 8 set; the weekly and on-request full runs keep 40. Four fast runs on PR #62 and `main` showed every macOS group under 10 minutes (8.5 the longest), and the full run after the v0.4.10 release took 10.3 at most (PR #63)

### Notes

- Read-only trial, on copies with `.env` files excluded, of four application and infrastructure repositories and this one: two have no tests (QA-I1), one has no CI (QA-I2), two have no integration tests (QA-I1), and none uses criterion ids (QA-T3). Two tests in one repository only check that a call does not raise (QA-H3), confirmed by reading. One calibration came from the trial: a repository with a make `test` target and no npm test script passes QA-I5. No false positives remained
- An independent review before release (correctness, security and privacy, tests and documentation), checked by `finding-verifier`, confirmed 17 findings, all fixed with a test and a control each:
  - Python: a signature over several lines (Black's style) no longer ends the test before its body, and a triple-quoted string carries across lines, so its lines neither end a test nor count as assertions
  - CI: installing a runner (`pip install pytest`, `npm i -D jest`) no longer counts as running the tests; a make prerequisite cycle no longer crashes the inventory check; a `package.json` on one line is read
  - Files: a repository under a directory named `test/` is typed by the path below the search root; `impact.test.js` is not a contract test; a dotted core file (`user.service.ts`) is named through its import path; retries passed to the code under test are not runner retries; a path that starts with `-` never reaches `find` as an expression; the empty-pattern guard reads the pattern as the check does
  - Skills: every contract value goes to a script in single quotes, a value holding a quote, a newline, `$(` or a backtick is refused, and `git log` is never run with `--output`, `--ext-diff` or `--textconv`
  - `Makefile` `FRAMEWORK_VERSION` is 0.4.11 (it still said 0.4.9, so `make release-tag` would have refused); the delivery README and PILLARS list `ascent-quality`
- A negative control that removed the empty-pattern guard made `check-tests.sh` loop forever on `--id-pattern 'x*'`. `ids()` now stops on an empty match as well, so the control fails a test instead of hanging the run
- Control P457 (the prerequisite-cycle depth limit removed) recursed without end under gawk, which grew to the runner's memory and took the Ubuntu CI job down; BWK awk and mawk stop at their own stack limits. The cycle test now runs the check with CPU and memory capped (`ulimit -t 10`, and `-v` 1 GiB where the system allows it), so gawk stops in under a second and the control fails the test

---

## [0.4.10] — 2026-10-29

**Faster negative controls.** `make test-mutants` runs in fast mode by default ([ADR-017](docs/framework/DECISIONS/ADR-017-faster-negative-controls.md), [ADR-018](docs/framework/DECISIONS/ADR-018-fast-negative-control-harness.md)): a control runs only the gate check it names, behavior tests stop at their first failure, and controls run in parallel. Verdicts do not change: before release, every one of the 439 controls got the same verdict from the old harness and the new one. Framework tooling only; no plugin versions change.

### Added

- Fast mode in `make/test-mutants.sh` (`MODE=full`, `ASCENT_MUTANT_MODE=full`, runs the whole gate for every control, as before):
  - **One check.** `make/test-plugins.sh` takes `ASCENT_ONLY=<label>` and runs the shared setup and that section only (`T13.4` runs T13). An unknown label exits 2
  - **First failure.** With `ASCENT_T11_FAST=1`, T11 runs each behavior test in its own process group and `TMPDIR`, watches its output file and stops the group at the first FAIL line, then stops T11 at that test and plugin. Tests that name the edited file run first (`ASCENT_T11_FIRST`). The output is watched, never piped, so SIGPIPE cannot end the gate
  - **Parallel.** Controls and group baselines run in the background, `JOBS` at a time (`ASCENT_MUTANT_JOBS`, default the number of cores), each on its own copy, deleted after its verdict; results print in control order, and the totals line now also names the mode. Works in bash 3.2. The `core` group stays serial. `MODE` and `JOBS` count only when given on the make command line, and an interrupt stops every running control
  - **Survivors rerun in full.** The report shows the FAIL lines of both runs. A control full mode kills and fast mode does not is reported as `MODES DIFFER` and fails the run, never counted as a kill
  - **Progress and summary.** While controls run, a progress bar on stderr shows how many are done and running, how many were not killed, the elapsed time and an estimate of the time left, when stderr is a terminal (`ASCENT_MUTANT_PROGRESS=0` turns it off, `=1` forces it). Every run ends with a summary block above the totals line: counts by kind, the controls not killed, the time and the three slowest controls. The bar's total is counted from the control declarations before the run, and the run fails if it launched a different number
- Guards that keep the two modes in agreement:
  - T11 fails a behavior test that prints a FAIL line and exits 0, in both modes
  - Gate check T14 runs `tests/meta/test-gate-fast.sh` (26 cases, fixture plugins): the first-failure stop and the stopped test's children, the stop at the first failing test and plugin, the ordering, a `TMPDIR` per test, the FAIL-line rule, the label handling, T7's reasons under its FAIL line (or the checker's last lines when it gave none), and T7 on a valid skill whose frontmatter is larger than a pipe buffer. Each failing case is its own result, `T14.G<n>`. `make test-mutants` skips it except for the harness group
  - Every group gets a second baseline in fast mode, `P00-fast-baseline`: all behavior tests, unmutated, run the way fast mode runs them. The harness group's baseline runs T14
  - `tests/meta/test-gate-sections.sh`: each gate section run alone prints exactly its lines from the full gate
  - `tests/meta/test-mutants-harness.sh`: the `harness` group gives the same results in the same order with 1 job and with 4, and a raw run (`ASCENT_MUTANT_RAW=1`) holding every kind of result is counted right and fails; the summary block counts what the totals line counts and lists every control not killed, the progress bar ends at N/N on stderr, and a control declared where the count before the run cannot see it fails the run
  - `make test-harness` runs the last two; CI runs it on both platforms in a new job
- Group `harness`, controls P359–P376: six `expect_case` controls that must be reported as SURVIVED (a harmless edit, a kill on the wrong check, and a T13.4 control that only breaks T13.2), ANCHOR MISS, MODES DIFFER (`MUTANT_FAULT=fast-pass` makes fast mode pass everything) and CONTROL FAIL; nine that break fast mode and must be killed by the T14 case they break; P374, which drops T7's reasons and must be killed by T14.G10; and P375 and P376, which put back the frontmatter checker's pipes and must be killed by T14.G12
- `--help` for `make/test-plugins.sh` and `make/test-mutants.sh`
- CI: a weekly full-mode run of every group (Mondays, 06:17 UTC) and a `mode` input on `workflow_dispatch`
- ADR-018, the harness design

### Changed

- `make test-plugins` reports T1–T14. CLAUDE.md, CONTRIBUTING and ARCHITECTURE describe fast mode, `MODE`, `JOBS` and `make test-harness`; CONTRIBUTING states the FAIL-line rule for behavior tests
- ROADMAP: the missing v0.4.8 and v0.4.9 sections, and v0.4.10
- The negative-control CI jobs keep their 40-minute limit for the weekly full run; fast runs return to 15 minutes once two CI runs show every group under 10 (ADR-017 decision 5)

### Fixed

- `make test-plugins` T11 no longer ends the gate early when a behavior test fails with long output. It quoted the first FAIL lines through `grep | head -3`; under `set -euo pipefail`, `grep` sometimes died of SIGPIPE and the assignment ended the script before T11 printed. Negative controls whose tests failed at length were then reported as SURVIVED, intermittently and mostly on Linux (P246, P255 and P265 in `ascent-security-deps` on the v0.4.9 CI runs). Reproduced on Ubuntu 24.04: 11 of 300 runs at 13.5 KB of FAIL lines, every run at 113 KB; `awk`, which reads to the end, none. New control P358 makes a behavior test fail with 3,000 FAIL lines; it survives the old line and is caught by T11 with the fix
- `make test-plugins` T7 says why it failed: it lists each failing `SKILL.md` and the checker's reason, indented under its FAIL line, and the negative-control reports carry those lines. Before, it discarded the checker's output: on this release's first CI run, the `ascent-ops-scripts` baseline failed T7 once on Ubuntu with no reason given, then passed on rerun and in six local runs
- `make/qa-skill-frontmatter.sh` (T7, and `make qa`) no longer reports a field as missing when the machine is busy. It fed the frontmatter to `grep -q` and to an `awk` that stops early through `printf |` pipes; under `pipefail`, a reader that stopped before `printf` finished killed it with SIGPIPE, and the checker reported `missing required field 'name'` for a file that has one. T7's new reasons named it on this release's second CI run: the Ubuntu baselines of `ascent-ops-scripts` and `ownership`, each on a different `SKILL.md`. On a 10-core Mac, 16 checkers at once: 107 of 400 runs failed with the old checker, none with here-strings. T14.G12 makes it deterministic with a frontmatter larger than a pipe buffer: the old checker fails it every time

### Notes

- Equivalence, measured locally before release: the old harness (full mode, serial) and the new one (fast mode, parallel) gave the same verdict for all 439 controls in 16 groups, before and after the review fixes. On a 10-core Mac, every group in fast mode, one after another, took 21 minutes (25 to 96 seconds a group); the old harness took 31 minutes with eight groups running at once. CI timings for macOS and Ubuntu come from the pull request's runs
- Gate totals, under bash 5.3 and the macOS awk (the gate also under `/bin/bash` 3.2): `make qa` OK (483 internal links), `make test-skills` 28/28, `make test-plugins` 69/69 (T14 26/26), `make test-harness` 15/15 and 16/16, `make test-mutants` 475 results in 17 groups (the 439 controls, P359–P376 and the group baselines), all killed, 0 survived, 0 anchor misses; in full mode, the harness group 20/20 and the ownership group 38/38
- Review before release (correctness, tests, operations and security lenses, checked by `finding-verifier`): 16 findings confirmed and fixed, among them no baseline for T14 or for the behavior tests in fast mode, T14 controls that any failing self-test case would have counted as killed, no control for the fast-mode label check, totals counting that nothing tested, `kill -0` on a pid that may be reused, and an interrupt that left controls running. One more, the 60-day pause of scheduled workflows on a public repository, is recorded in ADR-018. A second review, of the progress bar, the summary and the T7 change: no Critical, High or Medium findings; two Low ones (stale totals here, and no test for the count check) are fixed. A third review, of the frontmatter fix: no Critical, High or Medium findings; two Low ones (a `sed | head` left in the checker, and a `printf | grep -q` in T14.G10) are fixed
- CI on the pull request's first run: every macOS negative-control group under 5 minutes (the harness group the longest, 4.2), every Ubuntu group under 2, the whole run 16 minutes (34 on `main` before). Second run: every macOS group under 10 minutes again (`ascent-ops-review` the longest, 8.5), every Ubuntu group under 3, the whole run 33 minutes; its two failures were the frontmatter race above

---

## [0.4.9] — 2026-10-27

**Dependency checks in `ascent-security` 0.2.0.** A hand-written `dependency-check` skill joins the three generated security skills, so the plugin is now hybrid ([ADR-016](docs/framework/DECISIONS/ADR-016-dependency-checks-in-ascent-security.md), extending ADR-014 decision 2). It checks that a repository installs exactly what it declares, from where it declares, and scans what it installs for known vulnerabilities, offline by default. Other plugins are unchanged.

### Added

- `ascent-security` 0.2.0, skill `dependency-check` with ten rules, `SEC-D1`–`SEC-D10`, rated from its own `dep-severity` table:
  - `scripts/check-dependencies.sh` (SEC-D1–D6, SEC-D10), files only: a lockfile present, covering the manifest and tracked by git; pinning against `ops.version_pinning`; the lockfile in step with the manifest; an engine constraint; dependencies, registries and indexes from unexpected sources (plain `http://` is High, credentials in URLs masked); licences on `security.dependencies.licences_denied`; scanner ignore entries (`.trivyignore`, `.trivyignore.yaml`, `osv-scanner.toml`, `.nsprc`, `audit-ci.json`) without a waiver ADR or past their expiry. npm (package-lock v1–v3, yarn, pnpm) and Python (pyproject, Poetry, uv, PDM, Pipfile, pip-compile requirements) get every rule; Go and Cargo get SEC-D1 and SEC-D5
  - `scripts/run-vuln-scan.sh` (SEC-D7–D9): trivy with flags proven to send nothing (`--skip-db-update --skip-java-db-update --offline-scan --skip-version-check`), on lockfiles, image archives and local daemon images, from a scratch directory with an empty `--config` and `--ignorefile` so a committed `trivy.yaml` or `.trivyignore` cannot change what it reports; osv-scanner, `npm audit` and pip-audit only with `--allow-network`, after a `--dry-run` plan the operator agrees to; `--from` rates output recorded elsewhere. Duplicate advisories across scanners merge; the threshold and the database age (SEC-D8) come from the contract. A scanner that fails, or writes an error or a cut-short report, leaves that part of the scan unmeasured (SEC-D8), never clean
  - `scripts/lib/json.awk`, a streaming JSON reader shared by both scripts
  - `references/dependency-rules.md` and `references/contract-template.yml`, the `security:` section of `.ascent/contract.yml`
- `security-auditor` gains check 8, dependencies by reading (SEC-D1–D6, SEC-D10), with an identical copy of the `dep-severity` table; the scan and lockfile tracking are reported as not checked
- Gate: `marked_table dep-severity dependency` (T5). Behavior tests `test-check-dependencies.sh` (162 cases per awk, with a stand-in git so results never depend on the host repository), `test-run-vuln-scan.sh` (137, against recorded trivy output and stand-in scanners on a PATH without real ones) and `test-dependency-rules.sh` (119). Negative controls P241–P357 in five new groups, `ascent-security-deps`, `ascent-security-scan` and `ascent-security-regressions-1` to `-3`; the last three hold one control for each defect the review found
- ADR-016. Roadmap and registry: live, operator-run security testing is `ascent-security` 0.3.0
- Review before release (security, correctness, operations and tests lenses, checked by `finding-verifier`): 39 findings confirmed and fixed, among them trivy reading the repository's own config, an npm error or cut-short scan rated clean, `GPL-3.0-only AND (MIT OR BSD-3-Clause)` passing a GPL deny list, a declared registry matched without a host boundary, tokens printed in SEC-D3 messages, `setup.cfg` and multi-line arrays with extras not read, and a PATH named `build` or `test` checking nothing. The real-repository trial added one more: SEC-D7 now reports N/A, not PASS, when no scan had a lockfile to read

### Changed

- GitHub-facing docs (README, CONTRIBUTING, CLAUDE.md, the `docs/framework` living docs and `.github`): a new tagline, "Disciplined delivery for Claude Code, from first commit to long after launch", in the README banner and its alt text; "Day 0 to Day 1000" rephrased in plain words; sentence dashes replaced with ordinary punctuation. (PR #58)
- `docs/framework/OWNERSHIP.md`: `ascent-security` is `hybrid` with the `security` contract section and the `dep-severity` marker; `dependency-check` and the `SEC-D` family registered (no longer reserved); dependency vulnerabilities and supply chain released; security testing (live, operator-run) planned. P207 now anchors on the `QA-I` reserved row
- PILLARS: dependency vulnerabilities and supply chain Strong with trivy and a current database, Partial without; version pinning tested for package manifests; live security testing listed as a committed gap
- CLAUDE.md, README, ARCHITECTURE: `ascent-security` described as hybrid; framework version 0.4.9
- CI: the negative-control jobs get 40 minutes, up from 15. A control takes about 50 seconds on a macOS runner (about 9 on Ubuntu), and the new security groups hold up to 31

### Notes

- Read-only trial on copies of `ground-turf-truth`, `aws-platform-lloydbriantech`, `homelab-docs` and `homelab-toolkit` (ADR-016 decision 9). Not exercised: real Python, Go and Cargo lockfiles, image scanning, the network scanners, and the skill's full flow beyond its scripts

---

## [0.4.8] — 2026-10-27

**Ownership registry and plugin-qualified rule ids.** Every plugin, component, rule-id family, contract section, domain and review lens now has one registered owner, and the plugin gate fails when the repository drifts from the registry ([ADR-015](docs/framework/DECISIONS/ADR-015-ownership-registry-and-gate.md)). Rule ids name the plugin that raised them. Plugins: `ascent-architecture`, `ascent-ops` and `ascent-ux` 0.2.0 (report output changes), `ascent-delivery` 0.1.2; `ascent-security` is unchanged at 0.1.1.

### Added

- `docs/framework/OWNERSHIP.md`, the ownership registry: seven marked tables (repository signals, plugins with their codes, components, rule-id families, reserved names, domains and testing types, review lenses). Its "Which plugins do I need?" section maps what a repository contains to the plugin that checks it; the README links to it
- Gate check T13 in `make test-plugins`, from `make/check-ownership.sh` (`make ownership` runs it alone): T13.1 registry well-formed, T13.2 plugins, T13.3 components, T13.4 codes and families, T13.5 contract sections, T13.6 cross-plugin markers, T13.7 domains, T13.8 delivery lenses, T13.9 README versions and PILLARS names, T13.10 qualified ids. T13.0 runs the checker's fixture tests, `tests/meta/test-check-ownership.sh` (69 cases on every awk installed), and the gate fails if the checker prints fewer than ten results
- `ascent-delivery` 0.1.2: an "Architecture and cost" review lens served by `ascent-architecture:architecture-reviewer`, with its own fallback prompt
- ADR-014 (testing ownership across plugins; the dependency scan in `ascent-security`, test strategy in `ascent-quality`, restore proof in `ascent-ops`), accepted and built from v0.4.9; its rule-id families are reserved in the registry. ADR-015 (the registry and gate)
- `make test-mutants` gains the `ownership` group, controls P205–P240: one or more for every T13 rule, five that break the checker itself and must be caught by T13.0, and a group baseline that runs T13.0 unmutated. P04 and P161 no longer depend on a version number

### Changed

- **Rule ids are plugin-qualified, `<CODE>-<family><n>`.** Codes: `SEC`, `DEL`, `ARC`, `UX`, `OPS`; `QA` and `GOV` reserved. Every definition, report line, reference, test and negative control is renamed; no aliases are kept. Anyone parsing report output must update:

  | Plugin | Before | After |
  |---|---|---|
  | `ascent-architecture` | template checks C1–C12, principles P1–P12, deployment options O1–O5, component mapping B1 | `ARC-C1`–`ARC-C12`, `ARC-P1`–`ARC-P12`, `ARC-O1`–`ARC-O5`, `ARC-B1` |
  | `ascent-ops` | secure configuration S1–S10, scripts Z1–Z9, manuals M1–M8 | `OPS-S1`–`OPS-S10`, `OPS-Z1`–`OPS-Z9`, `OPS-M1`–`OPS-M8` |
  | `ascent-ux` | static checks U1–U12, heuristics H1–H10, design directions D0–D7 | `UX-U1`–`UX-U12`, `UX-H1`–`UX-H10`, `UX-D0`–`UX-D7` |

  Report lines read `FAIL  OPS-S3  High  …`; the id column is seven characters wide. The `ux.direction` contract value is now `UX-D1` (it was `D1`). Gate check ids (T), negative controls (P) and validator cases (V) are internal and keep their form. Past CHANGELOG entries, accepted ADRs and closed plans keep the old ids as history
- `ascent-delivery` 0.1.2: the lens tables in the skill, `review-lenses.md` and the plugin README list providers in preference order, ASCENT reviewers first: `ux-reviewer` for accessibility and for UX and navigation (launched once when it serves both), `ops-reviewer` for operational and deploy impact, `architecture-reviewer` for the new architecture and cost lens. At v0.4.7 the tables named none of them
- `make release-tag` and the release docs say `git push origin v<version>`, not `git push --tags`, which would also publish any stale local tag (`make/release.mk`, CLAUDE.md, ROADMAP, the skill's `PHASE-PROTOCOL.md` and `role-devops.md`)
- CONTRIBUTING and CLAUDE.md: a new plugin, skill, agent, hook, rule family, contract section or lens starts with a registry row
- PILLARS: T13.9 keeps the "Checked by" names true. ROADMAP: the release order v0.4.9 to v0.4.11, and committed follow-ups for project auditability, the `ascent-governance` conductor, "Recommended next" naming missing plugins, navigational integrity and UAT sign-off

### Notes

- T13 was proven against `main` at v0.4.7 with only the registry added: it failed T13.4 (no family defined by a qualified id), T13.8 (the lens drift in all three delivery tables) and T13.10 (unqualified ids), and passed every other rule
- The migration was checked by reversing it: stripping the codes from v0.4.8 reproduces v0.4.7 exactly in 382 files, and the remaining differences are the intended non-id changes listed above
- Gate totals, under `/bin/bash` 3.2 and the macOS awk: `make qa` OK (452 internal links), `make test-skills` 28/28, `make test-plugins` 65/65 (T13.0 69/69), `make test-mutants` 307 controls, 307 killed, 0 survived, 0 anchor misses
- An independent review (correctness and tests lenses, checked by `finding-verifier`) found 15 issues, all fixed before release: bare skill names in PILLARS were not checked, nested marketplace names, backticked unqualified ids, rows without a leading pipe, a missing marketplace aborting the checker, padded lens headers, nine untested checker branches, and four imprecise controls

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

[Unreleased]: https://github.com/lloydbrian/lloydbriantech-ascent/compare/v0.4.11...HEAD
[0.3.1]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.3.1
[0.3.0]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.3.0
[0.2.0]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.2.0
[0.1.0-alpha]: https://github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.1.0-alpha
