# ADR-016: Dependency checks in ascent-security: SEC-D1–D10, an offline-first scan, and live security testing as the 0.3.0 follow-up

**Status:** Accepted
**Date:** 2026-10-27 (America/New_York)
**Decider:** lloydbriantech

## Context

[ADR-014](ADR-014-testing-ownership-and-dependency-scan.md) decision 2 put a hand-written `dependency-check` skill in `ascent-security` 0.2.0. It made the plugin hybrid, named the `SEC-D` rules and the `dep-severity` table, and planned `run-vuln-scan.sh`. ADR-014 is immutable. Building it raised questions that decision did not settle:

- **Which scanner runs without asking?** ADR-014 listed osv-scanner, trivy, `npm audit` and pip-audit, and allowed "an invocation proven to download nothing". Only trivy (0.76.1) could be proven offline here; osv-scanner and pip-audit were not installed. `npm audit` and pip-audit always send package names to a third party.
- **How old may the database be?** A stale database finds old advisories and misses new ones.
- **What counts as a waiver?** Projects already suppress advisories in scanner ignore files (`.trivyignore`, `osv-scanner.toml`, `.nsprc`, `audit-ci.json`), and nothing ties those entries to a decision.
- **Images.** The operator's earlier red and blue test platform scanned local images with `trivy image` and kept accepted risks in a plain list. Its lessons: never `npm install --package-lock-only` to make a lockfile for scanning (it rewrites the file under review), and never use `:latest` images.
- **Live security testing.** That platform also ran checks against a running application: headers, verb tampering, path traversal, unauthenticated writes, request size limits, information disclosure, a prompt-injection canary, ZAP, dalfox and nuclei. None of it is static, and all of it needs a running target and the operator.

## Decision

1. **Ten rules, `SEC-D1`–`SEC-D10`**, defined in [dependency-rules.md](../../../plugins/ascent-security/references/dependency-rules.md) and rated only from the `dep-severity` table in `dependency-check`, copied into `security-auditor` (T5 checks the copies):
   - `check-dependencies.sh` reads files only: SEC-D1 lockfile present, covering the manifest and tracked by git; SEC-D2 pinning against `ops.version_pinning`; SEC-D3 lockfile in step; SEC-D4 engine constraint; SEC-D5 unexpected sources (plain `http://` is High); SEC-D6 denied licences; SEC-D10 scanner ignore entries without a waiver ADR, or past their expiry.
   - `run-vuln-scan.sh`: SEC-D7 advisories in dependencies, SEC-D8 an unmeasured scan or a database older than `scan_max_age_days`, SEC-D9 advisories in local images.
   - npm and Python get SEC-D1–D6. Go and Cargo get SEC-D1 and SEC-D5 only: they pin by checksum or lockfile, so range rules add little.
2. **Offline first; trivy is the scanner that runs unasked.** It runs with `--skip-db-update --skip-java-db-update --offline-scan --skip-version-check --scanners vuln`, from a scratch directory with an empty `--config` and `--ignorefile` (a `trivy.yaml` committed with `severity: [CRITICAL]` cut a recorded scan from 9 advisories to 1; scanner ignore entries are SEC-D10's to rate), and images come only from an archive (`--input`) or a local daemon (`--image-src docker,containerd,podman`; the default source list includes the registry). These invocations were run with the network denied (`sandbox-exec -p '(version 1)(allow default)(deny network*)'` on macOS, where `curl` fails) and produced the recorded fixtures. osv-scanner, `npm audit` (with `--package-lock-only`) and pip-audit (`--no-deps --disable-pip`, fully pinned files only) run only with `--allow-network`, which the skill passes only after the operator has seen the `--dry-run` plan and agreed in that session. `--from FORMAT:FILE` rates output the operator recorded elsewhere.
3. **The database is the operator's.** The skill never refreshes it; the runbook carries `trivy image --download-db-only`. A stale database is SEC-D8 Low, and the advisories found are still rated. With no scanner and no network agreement the scan is unmeasured (SEC-D8 Low), never PASS. So is each scanner that fails or writes something that is not a complete report of its format.
4. **Severity** follows ADR-014 and adds the cases it left open. A Critical or High advisory with a fixed release is High; with no fix yet, Medium. An advisory with no scanner severity (pip-audit, trivy UNKNOWN, some osv-scanner entries) is Medium at any threshold: an unknown severity cannot be shown to be below it. Medium and Low advisories at or above the threshold are Low. `vuln_threshold` (High at enterprise, Critical at standard, none at prototype) is applied once, in the normaliser: advisories below it are NOTE counts. The same advisory from several scanners (the same package and version at the same place, sharing an id or alias) is one finding.
5. **Waivers.** A waiver lists its advisory ids under `security.waivers[].advisories`, and the skill passes them as `--waived`. A waived scanner ignore entry or advisory is Info; an unwaived ignore entry is SEC-D10 Low and names its expiry when it has passed. At prototype it is a NOTE.
6. **No credentials in output.** URLs are printed with `user:password@` masked and query strings dropped. Only the `registry=` lines of `.npmrc` are read into the output.
7. **The contract gains `security:`** ([contract-template.yml](../../../plugins/ascent-security/references/contract-template.yml)) with `maturity_target`, `dependencies` (`ecosystems`, `lockfile_required`, `vuln_threshold`, `scan_max_age_days`, `licences_denied`, `registries`, `images`), `adr_dir` and `waivers`. Pinning stays `ops.version_pinning`; there is no second key. The registry records `security` as the plugin's section, `hybrid` as its build and `dep-severity` as its second marker.
8. **Live security testing is `ascent-security` 0.3.0**, recorded in the roadmap and the registry as "security testing (live, operator-run)". The candidates from the test platform are: response headers, HTTP verb tampering, path traversal, unauthenticated write and destructive endpoints, 413 on oversized requests, information disclosure, a prompt-injection canary and an AI request burst, ZAP, dalfox and nuclei, a self-check against a deliberately vulnerable app, an endpoint list in the contract (`security.endpoints`), and the threat model. Every one runs from an operator runbook; Claude reads the redacted result. Not taken: load testing (it belongs to `ascent-quality`), checks specific to that platform's apps and agents, ffuf, blocking CI by force, and Colima.
9. **Review and trial before release.** Four review lenses (security, correctness, operations, tests) raised 42 findings; `finding-verifier` confirmed 39, rejected 1 and left 2 unconfirmed (one was then disproved by running trivy, the other is fixed anyway: package names merge case-insensitively). All 39 are fixed, each with a regression case and a negative control (groups `ascent-security-regressions-1` to `-3`). The read-only trial (2026-10-27, trivy database of that day) ran both scripts on copies of four repositories: `ground-turf-truth` (an npm workspace with a v3 lockfile of 123 packages: SEC-D2 Low under the enterprise default of exact pinning, SEC-D1, D3, D4 and D5 pass, and the scan rated 2 of 11 advisories High), and `aws-platform-lloydbriantech` (Terraform), `homelab-docs` (documentation) and `homelab-toolkit` (a `pyproject.toml` with no dependencies), which have no manifest and are N/A throughout. It led to one calibration: SEC-D7 was PASS when no scan had a lockfile to read, and is now N/A. Each run took about a second.

## Alternatives considered

- **osv-scanner as the default scanner.** Rejected for now. It was not installed, so its offline behaviour (it needs a local database download first) is unproven here. It stays supported behind `--allow-network`.
- **Ask before every scan, trivy included.** Rejected. The offline invocation was proven to send nothing, and asking every time would make the check skipped in practice.
- **Refresh the database when it is stale.** Rejected. A refresh is a network call and a write outside the repository; the operator does it.
- **A plain accepted-risks list** (the test platform's `accepted-risks.txt`). Rejected. A list has no decision, owner or review date; an ADR id in the contract's waivers has all three.
- **Every ecosystem gets every rule.** Rejected. Go and Cargo ranges are resolved into checksummed lockfiles, so SEC-D2–D4 would mostly report noise.
- **Live checks in 0.2.0.** Rejected. They need a running target, an operator runbook and a different test strategy (recorded responses), which is a release of its own.

## Consequences

- `ascent-security` 0.2.0 ships five components: three generated skills, the hand-written `dependency-check` and the `security-auditor` agent. Contributors check for the GENERATED marker before editing a security skill.
- Dependency vulnerabilities move from Gap to Strong where trivy is installed and its database is current, and Partial otherwise; version pinning is tested for package manifests. `sec-posture` is unchanged (ADR-014).
- The agent has no shell. It checks SEC-D1–D6 and SEC-D10 by reading and reports the scan and lockfile tracking as not checked.
- A trial result depends on the operator's trivy database date. The report prints it.
- **(uncertain)** Not exercised by the trial: Python, Go and Cargo lockfiles in a real repository (none of the four has one), image scanning (no local image or archive), the network scanners, and the skill's full flow (Step 0 contract proposal and the report) as opposed to its scripts. osv-scanner v1 and v2 syntax, pip-audit's behaviour with `--no-deps`, and trivy with a local daemon image were not exercised here. Stand-ins test the commands; the trials will show whether the real tools agree.

## Cost implications

| | Estimated (ADR-014) | Built |
|---|---|---|
| Plugin lines (scripts, skill, references) | about 1,000 | about 1,500, plus about 35 in the agent |
| Test lines | about 500 | about 710, plus 30 fixture files |
| Negative controls | about 25 | 117, in five groups (`ascent-security-deps`, `ascent-security-scan`, `ascent-security-regressions-1` to `-3`) |

- **CI:** five mutant groups. Each control runs the plugin gate with the three behavior tests, about 20 seconds locally with one awk, about 9 on an Ubuntu runner and about 50 on a macOS runner. The negative-control jobs' timeout rises from 15 to 40 minutes; the largest group (31 controls) needs about 26 on macOS.
- **Recurring:** keep the offline flag list current as trivy changes, re-run the network-denied proof when trivy's major version changes, and refresh the recorded fixtures when a scanner changes its JSON.
- **Runtime:** bash, awk and git; trivy when installed; the network only with the operator's agreement.
