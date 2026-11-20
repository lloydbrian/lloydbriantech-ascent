# ascent-security

Security checks for any repository. The checks cover `.env` discipline, hardcoded credentials (including short ones such as PINs), container privilege, nginx security headers, production URLs and dynamic code execution (`eval`, `new Function`), dependencies (lockfiles, pinning, sources, licences and an offline vulnerability scan of packages and local images), a STRIDE threat model, and live checks of a running application that the operator runs. This plugin is part of the [ASCENT framework](../../README.md), and you don't need an ASCENT project to use it.

| Component | Type | Use it when you ask |
|---|---|---|
| `env-audit` | skill | "check my .env", "audit environment variables", "any secrets committed?" |
| `security-audit` | skill | "what security issues exist?", "check security baseline", or before a deploy |
| `sec-posture` | skill | "what's our security stance?", "security overview" |
| `dependency-check` | skill | "are our dependencies safe?", "check for vulnerable packages", "are we pinned and locked?", "scan our images for CVEs" |
| `threat-model` | skill | "write our threat model", "what could go wrong at each endpoint?", "which threats are still open?" |
| `security-test` | skill | "test the running app for security", "is our beta hardened?", "rate our ZAP, nuclei or dalfox report" |
| `security-auditor` | agent (read-only) | an independent security review of a repo or change, e.g. from a delivery loop or PR review |

## Install

Claude Code CLI, or the Claude Code extension in VS Code:

```
/plugin marketplace add lloydbrian/lloydbriantech-ascent
/plugin install ascent-security@lloydbriantech-ascent
```

From a local clone, use the clone's path instead of `lloydbrian/lloydbriantech-ascent`.

Cowork: Customize → Plugins → Add marketplace → `lloydbrian/lloydbriantech-ascent`.

Skills are called as `/ascent-security:env-audit`, `/ascent-security:security-audit`, `/ascent-security:sec-posture`, `/ascent-security:dependency-check`, `/ascent-security:threat-model` and `/ascent-security:security-test`. Claude also loads them automatically when your request matches their description.

To turn the plugin on for everyone working in a repository, add it to that repository's `.claude/settings.json` under `enabledPlugins`.

## Privacy and safety

- The checks only read, with one exception: `threat-model` writes `docs/security/THREAT-MODEL.md`, after showing you the rows. The skills pre-approve Read, Grep and Glob (plus `git ls-files` and `git log` for `env-audit`, `dependency-check`, `threat-model` and `security-test`). Claude still asks before using any other tool.
- **You run the live checks.** `security-test` writes a runbook; you run `run-live-checks.sh` and the scanners against a local or beta target, and commit the results. The script sends no credential and stores no response body, refuses hosts not on the contract's list and production unless the contract allows it, and inside Claude Code refuses anything but loopback. Writes that would change data (`--allow-writes`) and requests a model would answer (`--allow-ai`) are opt-in.
- `dependency-check` never installs, resolves or updates anything, and never refreshes a vulnerability database. Its scan runs trivy with flags that keep it offline. Scanners that send package names to a third party (osv-scanner, `npm audit`, pip-audit) run only after you have seen the `--dry-run` plan and agreed. Registry credentials in `.npmrc` or URLs are masked.
- The agent's tools are limited to Read, Grep and Glob. It cannot edit files or run commands.
- Findings cite `file:line` and the rule name, never the matched value or line. Detection is pattern-based: it misses some secrets (under 4 characters, split across lines or binary) and can flag test fixtures, so confirm each finding.
- Fixes are given as advice in text. The skills and the agent never rotate keys, deploy or run git; the operator acts on findings.

## Where `.env` files are

`scripts/check-env.sh` is a bash check a project can run in its own CI, at no token cost, and the check `ascent-governance` runs first for every launch. It reads file names, `.dockerignore`, `git ls-files` and `git check-ignore`; it never opens a `.env` file, so it cannot print a value.

| Rule | Severity | What it checks |
|---|---|---|
| `SEC-E1` | High | no `.env` file is tracked by git (committed or staged) |
| `SEC-E2` | High | every `.env` file that exists is ignored by git |
| `SEC-E3` | Medium | every `.dockerignore` excludes `.env`, and a repository with a Dockerfile has a `.dockerignore` |

A `.env` file is any file named `.env` or `.env.<name>`, in any folder; `.env.example`, `.env.sample` and `.env.template` are not. It checks where the files are, not what is in them or what the history holds: `env-audit` reads those.

## Dependency checks

`dependency-check` applies ten rules, `SEC-D1`–`SEC-D10` ([dependency-rules.md](references/dependency-rules.md)), against the `security:` section of `.ascent/contract.yml` ([contract-template.yml](references/contract-template.yml)):

| Script | Rules | What it needs |
|---|---|---|
| `scripts/check-dependencies.sh` | SEC-D1–D6, SEC-D10: lockfile present, covering and tracked; pinning; lockfile in step; engine constraint; unexpected sources; denied licences; scanner ignore entries without a waiver | bash, awk, git |
| `scripts/run-vuln-scan.sh` | SEC-D7–D9: advisories in dependencies and local images, database age | trivy for the offline scan; `--allow-network` for osv-scanner, `npm audit` and pip-audit |

npm and Python get every manifest rule; Go and Cargo get the lockfile and source rules. Refresh trivy's database yourself (`trivy image --download-db-only`): the skill reports a database older than `scan_max_age_days` and never updates it. See [ADR-016](../../docs/framework/DECISIONS/ADR-016-dependency-checks-in-ascent-security.md).

## Live checks and the threat model

`security-test` and `threat-model` apply `SEC-L1`–`SEC-L10` and `SEC-T1`–`SEC-T4` ([live-rules.md](references/live-rules.md)) against `security.endpoints`, `security.live` and `security.threat_model` in the contract:

| Script | Rules | Who runs it |
|---|---|---|
| `scripts/run-live-checks.sh` | sends the probes: headers, TRACE and CONNECT, path traversal, disclosure, and with opt-in unauthenticated writes, an oversized and a malformed body, a prompt-injection canary and an AI burst | you, against a local or beta target |
| `scripts/check-live-results.sh` | SEC-L1–L10: rates the results file and the ZAP (JSON), nuclei (JSONL) and dalfox (v3 JSONL) reports | Claude, read-only |
| `scripts/check-threat-model.sh` | SEC-T1–T4: the model is complete, every endpoint is an entry point with threats, every threat is mitigated in a file or accepted in an ADR, and a person reviewed it recently | Claude, read-only |

The scanners run in pinned containers from the runbook: `zaproxy/zap-stable:2.17.0` (baseline), `projectdiscovery/nuclei:v3.11.1` and `hahwul/dalfox:v3.3.0`. See [ADR-026](../../docs/framework/DECISIONS/ADR-026-live-security-testing-and-threat-model.md).

## How this plugin is built

The plugin is **hybrid**. `env-audit`, `security-audit` and `sec-posture` are **generated** by `make plugins` from the template skills in `skills/lloydbriantech-ascent/assets/template/.claude/skills/ascent-{env-audit,security-audit,sec-posture}`: to change one, edit that source and run `make plugins`. `dependency-check`, `threat-model`, `security-test`, their scripts, references, the agent and the manifests are written by hand in this directory; a generated file carries a `<!-- GENERATED by make plugins` marker, a hand-written one does not. `make test-plugins` fails if a generated file has drifted from its source, if the `dep-severity` or `live-severity` table in a skill and the agent differ, or if any file in the plugin changed without a `plugin.json` version bump (recorded in `make/plugins.lock`). Behavior tests and fixtures are in `tests/plugins/ascent-security/`. See [ADR-009](../../docs/framework/DECISIONS/ADR-009-plugins-generated-from-template-skills.md) and [ADR-016](../../docs/framework/DECISIONS/ADR-016-dependency-checks-in-ascent-security.md).
