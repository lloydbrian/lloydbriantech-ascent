---
name: dependency-check
description: >-
  Use when asked "are our dependencies safe?", "check for vulnerable
  packages", "are we pinned and locked?", "scan our images for CVEs", "any
  denied licences?", or before a release. Checks manifests and lockfiles for
  npm, Python, Go and Cargo (SEC-D1–D6: lockfile present, tracked and in
  step, pinning, engine constraints, unexpected sources, denied licences),
  runs an offline vulnerability scan of dependencies and local images
  (SEC-D7–D9), and checks scanner ignore entries for waivers (SEC-D10).
  Read-only; anything that uses the network runs only after the operator
  agrees.
version: 0.2.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# dependency-check

The supply-chain check of the `ascent-security` plugin. It answers two questions about a repository: does it install exactly what it says, from where it says, and does what it installs carry known vulnerabilities? Every result is judged against the `security:` section of the project contract.

Shared sources:
- [dependency-rules.md](../../references/dependency-rules.md): SEC-D1–D10, the files each rule reads, and the offline scan
- [contract-template.yml](../../references/contract-template.yml): the `security:` section of `.ascent/contract.yml`

## Rules

- **Read-only.** Never install, update, resolve, audit-fix or delete anything, and never write a lockfile. Never run `npm install --package-lock-only` (or `npm i`, `yarn`, `pnpm install`, `pip install`, `poetry lock`, `uv lock`) to make a lockfile for scanning: it rewrites the file under review.
- **Offline first.** The two scripts read files and run trivy with its offline flags. Anything that sends data to a third party (`--allow-network`: osv-scanner, `npm audit`, `pip-audit`) needs the operator's yes in this session, after they have seen the `--dry-run` plan. Never refresh the vulnerability database; the operator does (`trivy image --download-db-only`).
- **Evidence or it is not a finding.** Each finding cites a repository-relative `path/to/file:line` (an image finding cites the image), its rule id (SEC-D1–D10), a concrete failure scenario, and a fix. Script `FAIL` lines are findings at the severity they print; include the script output verbatim.
- **Fresh evidence.** Run the scripts in this session. Never carry findings over from an earlier pass, an agent's report or another session.
- **Rate only with the severity table.** A concern that matches no row goes under **Other observations (unrated)**.
- **Judge against the contract.** An advisory or ignore entry listed under a waiver ADR is Info.
- **No secrets or personal data.** Registry tokens in `.npmrc` or URLs are never printed: the scripts mask them, and a report names the file and line, never the value. A committed registry token is also a `security-audit` finding.
- **Scripts.** The scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`.

## Severity

Every dependency finding carries one of these severities. The `security-auditor` agent and both scripts use the same table.

<!-- dep-severity:start -->
| Finding | Severity |
|---|---|
| A Critical or High advisory with a fixed release, in a dependency (SEC-D7) or a local image (SEC-D9) | High |
| A licence the contract denies (SEC-D6) | High |
| A dependency, registry or index fetched over plain http:// (SEC-D5) | High |
| A Critical or High advisory with no fixed release yet (SEC-D7, SEC-D9) | Medium |
| An advisory the scanner gives no severity (pip-audit, trivy UNKNOWN, some osv-scanner entries), at any threshold (SEC-D7, SEC-D9) | Medium |
| A manifest with no lockfile, a lockfile that does not cover it, or one git does not track, where a lockfile is required (SEC-D1) | Medium |
| A lockfile out of step with its manifest (SEC-D3) | Medium |
| A dependency or registry from an unexpected source: git, a URL, another registry or index, a Go replace, --trusted-host (SEC-D5) | Medium |
| A Medium or Low advisory at or above the threshold (SEC-D7, SEC-D9) | Low |
| Ranges under version_pinning exact, or unbounded ranges under minor (SEC-D2) | Low |
| No engine or Python version constraint (SEC-D4) | Low |
| The scan unmeasured, or its database older than scan_max_age_days (SEC-D8) | Low |
| A scanner ignore entry with no waiver ADR, or past its expiry (SEC-D10) | Low |
| A dependency target missing from the contract ("unmeasured") | Low |
| An advisory or ignore entry covered by a waiver ADR | Info |
<!-- dep-severity:end -->

**Rating:** **strong**: no High and no Medium. **moderate**: no High, one or more Medium. **weak**: one or more High.

## Steps

### Step 0 — Load or propose the contract

Read `.ascent/contract.yml`, or `.claude/contract.yml` where ASCENT-named files are not allowed, and use its `security:` section and `ops.version_pinning`.

If the section is missing, **detect, don't ask.** Propose it from what the repository declares: `ecosystems` from the manifests found in Step 1, `registries` from `.npmrc`, pip index options and uv or Poetry sources (URL without credentials), and `images` from Compose `image:` tags and Dockerfile build targets. Use only the keys and values of [contract-template.yml](../../references/contract-template.yml), mark each detected value `# detected: <path:line>` and each guess `# guess`. Show the proposal once and ask the operator to confirm it. Write nothing: the operator commits the file. Until it is confirmed, check against the enterprise defaults (lockfile required, threshold High, database within 7 days, exact pinning) and say so; each target the contract lacks is a Low "unmeasured" finding.

The flags each script takes come from the contract: `--maturity`, `--pinning` (`ops.version_pinning`), `--lockfile-required` (`lockfile_required`), `--registry` (each of `registries`), `--deny` (`licences_denied`), `--threshold` (`vuln_threshold`), `--max-age` (`scan_max_age_days`), `--image` or `--image-tar` (each of `images`), and `--waived` (every `advisories` id of every waiver).

### Step 1 — Inventory

List the manifests, lockfiles and ignore files by ecosystem with `git ls-files` (the files [dependency-rules.md](../../references/dependency-rules.md) names), skipping `node_modules/`, `vendor/`, build output, virtualenvs and test code. Name the lockfile that covers each manifest, and note workspaces (`workspaces`, `pnpm-workspace.yaml`, `[tool.uv.workspace]`, Cargo `[workspace]`). An ecosystem with no manifest is not present, not a gap.

### Step 2 — Manifest and lockfile checks

Run from the repository root and include the output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-dependencies.sh" --maturity <target> --pinning <exact|minor> [--registry URL]... [--deny SPDX,...] [--waived ID,...] .
```

It checks SEC-D1–D6 and SEC-D10 and prints `FAIL`, `PASS`, `N/A`, `NOTE` and `INFO` lines. Then read what the script cannot judge: for each SEC-D5 source, whether the contract should declare the registry or the dependency should move to it; for SEC-D3, whether the lockfile or the manifest is the stale one (`git log -1 --format=%cs -- <file>` on each).

### Step 3 — Vulnerability scan

First show the plan, which runs nothing:

```bash
bash "$PLUGIN_ROOT/scripts/run-vuln-scan.sh" --dry-run --maturity <target> [--image NAME]... [--image-tar FILE]... .
```

Each `PLAN` line is marked `offline` or `network`. Run the offline plan (the same command without `--dry-run`, with `--threshold`, `--max-age` and `--waived` from the contract) and include its output verbatim. It applies SEC-D7–D9.

- **trivy missing**, or SEC-D8 failing on database age: say so, and give the operator the command for the runbook (`trivy image --download-db-only` refreshes the database; installing trivy is theirs). Do not install or refresh anything yourself.
- **Network scanners.** Only when the operator wants the extra coverage, show the `--allow-network` dry run, say what each `network` line sends and to whom, and ask. Run it only on a yes in this session.
- **Recorded output.** A scan the operator ran elsewhere (CI, another machine) is rated with `--from FORMAT:FILE[@LOCKFILE]`, for trivy, trivy-version, osv, npm-audit and pip-audit JSON.

For each High, name the direct dependency that pulls the vulnerable package in (from the lockfile) and the smallest upgrade that fixes it.

### Step 4 — Waivers

Read each scanner ignore entry and each `waivers` entry of the contract. A waiver needs an ADR in `adr_dir` that names the advisory and a `review_by` date that has not passed. A waiver whose ADR is missing, or whose `review_by` has passed, does not count: rate the entry as unwaived and say why. An expired waiver is never silently renewed; recommend that the operator review it.

### Step 5 — Report

```
dependency-check: <weak|moderate|strong> — <N> High, <N> Medium, <N> Low
Contract: <path, or "enterprise defaults (no contract)">   Ecosystems: <list>   Not present: <list>
Scan: <scanners and database date, or "unmeasured: <why>">

<SEV>  <file>:<line>  SEC-Dn  <finding>
       Scenario: <what goes wrong, concretely>
       Fix: <one line>
...
Other observations (unrated, not counted above):
- <file>:<line>  <observation>

Script output: <check-dependencies and run-vuln-scan output, verbatim>
Recommended next: <runbook items for the operator: database refresh, upgrades, waiver ADRs>
```

## What this skill does not do

- Install, upgrade or remove dependencies, run `npm audit fix`, or open upgrade pull requests.
- Refresh a vulnerability database, pull an image or call a registry.
- Test a running application (headers, injection, fuzzing): that is live security testing, planned for `ascent-security` 0.3.0 and always operator-run.
