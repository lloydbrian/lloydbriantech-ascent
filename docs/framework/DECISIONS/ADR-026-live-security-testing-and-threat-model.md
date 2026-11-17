# ADR-026: Live security testing and the threat model in ascent-security 0.3.0: SEC-L1–L10, SEC-T1–T4, operator-run probes and pinned scanners

**Status:** Accepted
**Date:** 2026-11-17 (America/New_York)
**Decider:** lloydbriantech

## Context

[ADR-016](ADR-016-dependency-checks-in-ascent-security.md) decision 8 named live security testing and the threat model as `ascent-security` 0.3.0, and listed the candidates from the operator's earlier red and blue test platform: response headers, verb tampering, path traversal, unauthenticated writes, 413 on oversized requests, information disclosure, a prompt-injection canary and an AI burst, ZAP, dalfox and nuclei, a self-check against a deliberately vulnerable app, and an endpoint list in the contract. The registry has carried "threat model" and "security testing (live, operator-run)" as planned domains since v0.4.8.

Everything ASCENT checked until now reads files. A live check sends requests to a running application, and some of them would change data or call a paid model if the application failed to stop them. A read of the test platform (2026-11-17, read-only, approved by the operator) also showed what not to copy: deletes without a guard, no protection against a production target, raw responses kept in results, an accepted-risks list that was never read, a traversal match on `localhost` that found its own URL, and no threat model.

The operator approved four decisions on 2026-11-17: (a) live checks run against local and beta targets only, production refused unless the contract opts in; (b) the operator runs the scanners in pinned containers and the plugin only reads their reports; (c) the threat model uses STRIDE; (d) Claude may read the test platform for reuse, read-only.

## Decision

1. **Two hand-written skills.** `security-test` writes the runbook for the live checks and the scanners, then rates the results; `threat-model` drafts and updates `docs/security/THREAT-MODEL.md` and checks it. Both pre-approve only `Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)` (T4b). The agent gains checks 9 (threat model) and 10 (committed live results), by reading.
2. **Fourteen rules**, defined in [live-rules.md](../../../plugins/ascent-security/references/live-rules.md) and rated only from the `live-severity` table in `security-test`, copied into `security-auditor` (T5):
   - SEC-L1 headers, L2 TRACE and CONNECT, L3 traversal, L4 unauthenticated writes, L5 oversized bodies, L6 disclosure (secrets, git and env files, stack traces, version banners), L7 the prompt-injection canary, L8 the AI burst, L9 ZAP, nuclei and dalfox reports, L10 results present, fresh, for the right target and URL, and complete.
   - SEC-T1 the model's shape and the STRIDE method, T2 every endpoint an entry point and every entry point threatened, T3 every threat mitigated in a named file or accepted under an existing ADR, T4 reviewed by a person within `review_max_age_days`.
3. **The operator sends every request.** `run-live-checks.sh` is the operator's: it sends no credential, refuses a URL that holds one, refuses hosts outside the allow-list (loopback is always allowed), refuses a target named `prod` or `production` without `--allow-prod`, and inside Claude Code (`CLAUDECODE` set) refuses anything but loopback. Writes (`--allow-writes`) and model calls (`--allow-ai`) are opt-in, and probes left out are recorded as `skipped`, which SEC-L10 reports when the endpoints need them. `--dry-run` prints the plan and sends nothing.
4. **Results hold no response.** The results file records each request's probe, method, path, status and what was matched (`leak=1`, `secret`, `trace`, `canary=1`), never a body, a header value other than a version banner cut to 60 characters, or a credential. `check-live-results.sh` masks `user:password@` in anything it prints from a report.
5. **The canary cannot be faked by an echo.** It asks for "the word ASCENT followed by the result of 7 times 6" and looks for `ASCENT 42`: an endpoint that only reflects its input never contains the answer.
6. **Scanners in pinned containers, run by the operator:** `zaproxy/zap-stable:2.17.0` (baseline, passive), `projectdiscovery/nuclei:v3.11.1` and `hahwul/dalfox:v3.3.0`, tags checked on Docker Hub on 2026-11-17. The plugin reads ZAP's JSON, nuclei's JSONL and dalfox's v3 JSONL. A finding below `scan_threshold` is a NOTE count; Critical rates High; dalfox's verified (V) findings are High, and its informational (I) lines are not findings.
7. **The threat model is a file the project owns.** Claude writes only that file, with surgical edits, shows the rows first, and never fills `reviewed_on` or `reviewed_by`: a model nobody reviewed fails SEC-T4. Ids are `EP-<n>` and `TH-<n>`, so they are never read as rule ids (T13.10).
8. **The contract's `security:` section gains** `endpoints` (path, methods, auth, flags), `live` (`targets`, `allow_prod`, `results_dir`, `max_age_days`, `max_body_bytes`, `scan_threshold`) and `threat_model` (`path`, `review_max_age_days`). Waivers take live ids (`SEC-L4:/api/items/{id}`, a ZAP `pluginid`, a nuclei `template-id`, `dalfox:<param>`).
9. **Tested against a real server.** `test-run-live-checks.sh` starts a small Python server on 127.0.0.1 in three modes (hardened, vulnerable, rate-limited) that stops itself after 300 seconds, and runs the script against it inside and outside Claude Code. `test-live-rules.sh` keeps the skills, the scripts, the table, the contract template and the agent in step. The read-only trial (2026-11-17) ran `check-threat-model.sh` on `regimedesk`, `sports-tennis-ptc-scoring` and `lloydbriantech-test-platform` (none has a model: SEC-T1 Medium each), drafted a STRIDE model for a copy of `regimedesk` (5 entry points, 7 threats: T1 and T2 pass, one open threat is SEC-T3 Medium, the unreviewed fields fail SEC-T4, and a NOTE names the uncovered E category), and ran the live checks against that copy on 127.0.0.1, stopped in the same step: 33 results, two Low SEC-L1 findings (no Referrer-Policy or Permissions-Policy), everything else passing. It led to one calibration: write endpoints that need no sign-in still need the oversized body, so SEC-L5 skipped for them is now unmeasured and SEC-L10, not N/A.

## Alternatives considered

- **Claude runs the live checks.** Rejected. A probe can change data or bill a model; the operator boundary puts every request to a real target in a runbook the operator reads and runs.
- **Scanners installed on the host.** Rejected. Versions drift and installs differ by machine; a pinned image gives the same scanner everywhere.
- **An active ZAP scan by default.** Rejected. It sends attack payloads to every form; it stays a separate operator decision.
- **Authenticated checks.** Rejected for 0.3.0. They need a credential in the runbook and in the process; the unauthenticated checks find the gaps that matter most (writes without sign-in) without one.
- **A free-form threat model.** Rejected. Without tables, SEC-T2 and SEC-T3 cannot be checked, and a model that is never checked goes stale.
- **PASTA or attack trees instead of STRIDE.** Rejected (decision c). STRIDE is per entry point, short, and fits a table.

## Consequences

- `ascent-security` 0.3.0 ships seven components: three generated skills, the hand-written `dependency-check`, `security-test` and `threat-model`, and the agent. The two planned domains become released.
- Security testing (live) and the threat model move from Gap to Partial in the pillars: the checks exist, and each project's evidence depends on the operator running the runbook and a person reviewing the model.
- The agent cannot run the live checks; with no committed results it reports them as not checked.
- **(uncertain)** Not exercised before release: the three scanner images against a real target, an https target (HSTS), and the skills' full flow on a repository whose contract lists endpoints. The rater is tested on recorded reports in each scanner's documented format.

## Cost implications

| | Built |
|---|---|
| Plugin lines (scripts, skills, reference, agent) | about 1,100 |
| Test lines | about 900, plus 14 fixture files and the test server |
| Negative controls | 84, in two groups (`ascent-security-live`, `ascent-security-threat`) |

- **CI:** two more mutant groups.
- **Recurring:** move the three image tags when the scanners release, and refresh the recorded reports when a scanner changes its output.
- **Runtime:** bash, awk and curl for the operator's run; Python 3 for the tests; Podman or Docker for the scanners.
