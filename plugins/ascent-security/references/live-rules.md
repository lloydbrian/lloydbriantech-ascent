# Live security testing and the threat model

`ascent-security` 0.3.0 adds two kinds of evidence a repository cannot show by itself: how a running application answers hostile requests, and which threats each entry point faces ([ADR-026](../../../docs/framework/DECISIONS/ADR-026-live-security-testing-and-threat-model.md)).

- **Live checks are the operator's.** `run-live-checks.sh` sends the requests, from a runbook `security-test` writes, against a local or beta target the contract allows. Claude never runs it against anything but the test fixture on 127.0.0.1, and the script refuses other targets when it runs inside Claude Code.
- **Claude reads the results.** The script writes no response body, header value (except a server banner, cut to 60 characters) or credential: only status codes and what it matched. `check-live-results.sh` rates the file it writes, and the reports the operator recorded (ZAP JSON, nuclei JSONL, dalfox v3 JSONL), with SEC-L1–L10.
- **The threat model is drafted by Claude and owned by the project.** `threat-model` writes `docs/security/THREAT-MODEL.md` with surgical edits; `check-threat-model.sh` checks it with SEC-T1–T4.

A results file shows what the target answered when the operator ran the checks. It does not show that the target was the one the contract names, or that it is unchanged since: the date, the target's name and its URL in the file are the guard.

## The endpoint list

`security.endpoints` in the contract lists what an attacker can reach. Each entry is passed to the script as one `--endpoint` value, four fields separated by spaces:

```
--endpoint 'METHODS PATH AUTH FLAGS'
--endpoint 'GET,DELETE /api/items/{id} required write'
--endpoint 'POST /api/chat required ai'
--endpoint 'GET /api/catalog none -'
```

| Field | Values |
|---|---|
| `METHODS` | comma-separated HTTP methods the endpoint serves |
| `PATH` | the path from the base URL; a parameter is `{name}` or `:name` |
| `AUTH` | `required` or `none` |
| `FLAGS` | comma-separated `write` (changes data), `ai` (calls a model), or `-` |

## The checks the script runs

All requests are unauthenticated: the script never sends a credential, so none can leak. A parameter is filled with `ascent-probe`.

| Probe | Requests | Recorded | Needs |
|---|---|---|---|
| `headers` | `GET /` | the security headers present and missing, and a version-like `Server`, `X-Powered-By` or `X-AspNet-Version` value | — |
| `verb` | `TRACE` and `CONNECT` on `/` and every endpoint path | the status, and `echo=1` when a TRACE body echoes the request | — |
| `traversal` | `GET` on every endpoint with a parameter, with six payloads in it: `../etc/passwd`, `..%2fetc%2fpasswd`, `....//etc/passwd`, `%2e%2e%2fetc%2fpasswd`, `../../../etc/passwd`, `..%252fetc%252fpasswd` | the status, and `leak=1` when the body holds a passwd line (`root:x:0:0:` or `daemon:x:`) or `[boot loader]` | — |
| `disclosure` | `GET` on `/.env`, `/.git/config`, `/debug`, `/api/debug`, `/api/config`, `/api/env`, `/actuator/env`, `/server-status` and a path that cannot exist | the status, and what the body matched: `secret` (a `password`, `secret`, `api_key`, `token` or `database_url` key with a value), `git` (`[core]`), `env` (`NAME=value` lines), `trace` (a stack trace) | — |
| `unauth-write` | each write method of each `required` write endpoint, with `{}` | the status | `--allow-writes` |
| `oversize` | `POST` of `--max-body` plus 100 KB (default 1 MB) to the first write endpoint, from a file | the status | `--allow-writes` |
| `malformed` | `POST` of `{"a":` to the first write endpoint | the status, and `trace=1` for a stack trace | `--allow-writes` |
| `canary` | `POST` to each `ai` endpoint asking for the word ASCENT followed by the result of 7 times 6 | the status, and `canary=1` when the answer holds `ASCENT 42` (an endpoint that only echoes its input cannot) | `--allow-ai` |
| `burst` | 10 `POST` requests with `{}` to the first `ai` endpoint, back to back | the count of each status | `--allow-ai` |

`--allow-writes` sends requests that would change data if the endpoint failed to check them: use it only against a target whose data is disposable. `--allow-ai` sends requests that a model may answer and bill. Without them those probes are recorded as `skipped`, and the checks they feed are unmeasured.

## Where the script runs

- The target's host must be on the allow-list (`--allow-host`, from the hosts of `security.live.targets`). `localhost`, `127.0.0.1` and `::1` are always allowed.
- A target named `prod` or `production`, or one marked `prod: yes` in the contract, is refused unless `--allow-prod` is given, which the contract allows only with `security.live.allow_prod: yes`.
- Inside Claude Code (the `CLAUDECODE` variable is set) only loopback targets run.
- `--dry-run` prints one `PLAN` line per request and sends nothing.

## The results file

One file per run, in `security.live.results_dir` (default `docs/security/live/`), named `YYYY-MM-DD-<target>.tsv`. The operator commits it. It opens with `#` lines, then one tab-separated row per request:

```
# ascent-live-results 1
# target	beta
# url	https://beta.example.com
# date	2026-11-20
# script	0.3.0
probe	method	path	status	detail
headers	GET	/	200	missing=content-security-policy;banner=nginx/1.25.3
verb	TRACE	/	405	-
traversal	GET	/api/items/..%2fetc%2fpasswd	404	-
unauth-write	DELETE	/api/items/ascent-probe	401	-
burst	POST	/api/chat	-	200=3;429=7
```

A status of `000` means no answer (timeout or connection refused).

## The threat model

`docs/security/THREAT-MODEL.md` (`security.threat_model.path`) opens with a two-column table, then two tables:

```markdown
# Threat model: orders

| Field | Value |
|---|---|
| reviewed_on | 2026-11-20 |
| reviewed_by | Jane Doe |
| method | STRIDE |

## Entry points

| Id | Entry point | Trust boundary | Auth |
|---|---|---|---|
| EP-1 | GET,DELETE /api/items/{id} | internet → api | required |

## Threats

| Id | Entry point | STRIDE | Threat | Mitigation | Status |
|---|---|---|---|---|---|
| TH-1 | EP-1 | E | A user deletes another user's item | Ownership check in `src/items/delete.ts` | mitigated |
| TH-2 | EP-1 | D | Unbounded listing exhausts the database | — | accepted (ADR-012) |
```

- **Ids** are `EP-<n>` for entry points and `TH-<n>` for threats. A threat names its entry points by id, comma-separated, or `all`.
- **STRIDE** is one letter: S spoofing, T tampering, R repudiation, I information disclosure, D denial of service, E elevation of privilege.
- **Status** is `mitigated` (the mitigation names a file in the repository, in backticks), `accepted (ADR-NNN)` (the ADR exists in `security.adr_dir`), or `open`.
- `reviewed_by` is the person who reviewed it. Claude drafts the model but never fills in `reviewed_on` or `reviewed_by`.
- **An AI application** (SEC-T5) records each model input as an entry point whose trust boundary names the model (`user → api → model`), or writes it `model input: <what>`: the user's text, retrieved documents, tool results. Its threats name, in the Threat cell, `prompt injection`, `sensitive information disclosure` (or `sensitive data disclosure`), `excessive agency` and `unbounded consumption`, each mitigated or accepted. The checker cannot see which inputs an application has; the threat-model skill asks.

## Red-team results

`check-redteam.sh` reads one AI application's `redteam_results` folder (default `evidence/<name>/redteam/`), and the newest run in it, by the time the run records:

| Tool | Files | When it ran | A category | An attack succeeded |
|---|---|---|---|---|
| garak | `<prefix>.report.jsonl`, `<prefix>.hitlog.jsonl` | the `init` row's `start_time` | a probe's module (`promptinject` in `promptinject.HijackHateHumans`); per `eval` row, `fails` of `total_evaluated` | a `hitlog` row |
| Promptfoo | `promptfoo redteam run -o <file>.json` | `results.timestamp` | `testCase.metadata.pluginId` | `success` is `false` |

The formats are `ascent-ai`'s [evidence-formats.md](../../ascent-ai/references/evidence-formats.md) records, checked against real files. A successful attack's id, for a waiver, is `garak:<probe>` or `promptfoo:<pluginId>`. Prompt-injection and data-leak categories are Critical at every tier: garak `promptinject`, `latentinjection`, `dan`, `leakreplay` and `xss`; Promptfoo `indirect-prompt-injection` and `pii` (`pii:direct` and the other `pii:` plugins). Other categories are High at tier 3, scaled by the application's AI risk tier as `ascent-ai` scales its rules.

## Rules

Severities come from the `live-severity` table in `security-test`, copied into `security-auditor`.

| Id | Checks | Reads |
|---|---|---|
| SEC-L1 | Security headers: `Content-Security-Policy`, `X-Content-Type-Options: nosniff`, frame protection (`X-Frame-Options` or a CSP `frame-ancestors`), `Strict-Transport-Security` on https, `Referrer-Policy`, `Permissions-Policy` | `headers` |
| SEC-L2 | TRACE and CONNECT are refused (not 2xx); a TRACE that echoes the request is cross-site tracing | `verb` |
| SEC-L3 | No traversal payload returns a system file | `traversal` |
| SEC-L4 | No write endpoint that requires sign-in accepts a request without it (2xx) | `unauth-write` |
| SEC-L5 | An oversized body gets 413 or 400, not 2xx, 5xx or no answer | `oversize` |
| SEC-L6 | No secret, git or env file, or stack trace is served, and no version banner | `headers`, `disclosure`, `malformed` |
| SEC-L7 | No AI endpoint follows an instruction to repeat the canary | `canary` |
| SEC-L8 | A burst to an AI endpoint is gated (401, 403) or rate-limited (429), with no 5xx | `burst` |
| SEC-L9 | ZAP, nuclei and dalfox report no finding at or above the threshold | the reports |
| SEC-L10 | A results file exists for the target, no older than `max_age_days`, for the target's URL, with every probe measured | the results file |
| SEC-T1 | The threat model exists, with its field table, both tables and the STRIDE method | the model |
| SEC-T2 | Every endpoint in the contract is an entry point, and every entry point has a threat | the model, `--endpoint` |
| SEC-T3 | Every threat is mitigated (the file exists) or accepted (the ADR exists); none is open | the model |
| SEC-T4 | The model was reviewed by a person within `review_max_age_days` | the model |
| SEC-T5 | With an AI application (`--ai`): an entry point for a model input, and threats for prompt injection, sensitive information disclosure, excessive agency and unbounded consumption, each mitigated or accepted | the model |
| SEC-R1 | Each AI application has a red-team result in a known format, no older than `redteam.max_age_days` | the application's `redteam_results` |
| SEC-R2 | No red-team category's attack success (successful attacks / attacks) is above `redteam.max_attack_success` | the newest run |
| SEC-R3 | Every successful attack in the newest run is waived by an ADR whose `review_by` has not passed | the newest run |

A scanner finding or a live finding whose id (a ZAP `pluginid`, a nuclei `template-id`, or a rule id with its path, `SEC-L4:/api/items/{id}`) is listed under a waiver ADR is Info. At prototype maturity every finding is a NOTE.
