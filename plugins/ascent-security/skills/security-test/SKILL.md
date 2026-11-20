---
name: security-test
description: >-
  Use when asked "test the running app for security", "is our beta
  hardened?", "check headers, verbs and traversal on the live site", "do our
  endpoints need sign-in?", "is the AI endpoint injectable or unlimited?",
  "rate our ZAP, nuclei or dalfox report", or before a first production
  deploy. Writes the runbook for live checks the operator runs against a
  local or beta target (SEC-L1–L8), and the scanner commands in pinned
  containers, then rates the results and the reports (SEC-L9, SEC-L10).
  Never sends a request to anything but the test fixture on 127.0.0.1.
version: 0.4.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# security-test

The live check of the `ascent-security` plugin. It answers what no file can: how does the running application answer a hostile request? The operator sends the requests; Claude writes the runbook and reads what came back.

Shared sources:
- [live-rules.md](../../references/live-rules.md): SEC-L1–L10, the probes, the results file and the endpoint list
- [contract-template.yml](../../references/contract-template.yml): the `security:` section of `.ascent/contract.yml`
- The `threat-model` skill: the entry points this check tests

## Rules

- **The operator runs every request.** Claude never runs `run-live-checks.sh`, ZAP, nuclei or dalfox against a target; the script refuses anything but loopback when it runs inside Claude Code. Claude writes the runbook, and reads the results file and reports the operator commits.
- **Local or beta, never production by default.** A target named `prod` or `production`, or marked `prod: yes`, runs only when the contract says `allow_prod: yes`, and the runbook says so in a ⚠ line.
- **Disposable data for writes, a budget for AI.** `--allow-writes` sends unauthenticated writes that change data if the endpoint fails to check them; use it only where the data can be thrown away. `--allow-ai` sends requests a model may answer and bill. Ask before putting either in the runbook.
- **No credentials anywhere.** The checks are unauthenticated: never put a token, cookie or password in the runbook, the contract or a command. The results file holds no response body.
- **Evidence or it is not a finding.** Each finding cites the results or report `file:line`, its rule id (SEC-L1–L10), a concrete failure scenario and a fix. Script `FAIL` lines are findings at the severity they print; include the output verbatim.
- **Fresh evidence.** Rate only results and reports dated within `max_age_days`; older ones are SEC-L10, and their findings are not carried over.
- **Rate only with the severity table.** A concern that matches no row goes under **Other observations (unrated)**.
- **Scripts.** The scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`.

## Severity

Every live and threat-model finding carries one of these severities. The `security-auditor` agent and the three scripts use the same table.

<!-- live-severity:start -->
| Finding | Severity |
|---|---|
| A write endpoint that requires sign-in accepted a request without it (SEC-L4) | High |
| A traversal payload returned a system file (SEC-L3) | High |
| An AI endpoint followed an injected instruction (SEC-L7) | High |
| A secret, a git file or an env file served (SEC-L6) | High |
| A scanner finding rated Critical or High (SEC-L9) | High |
| A missing Content-Security-Policy, nosniff, frame protection, or HSTS on https (SEC-L1) | Medium |
| A TRACE that echoes the request (SEC-L2) | Medium |
| An oversized body accepted, or answered with a 5xx or nothing (SEC-L5) | Medium |
| A stack trace served (SEC-L6) | Medium |
| An AI burst neither gated nor rate-limited, or answered with a 5xx (SEC-L8) | Medium |
| A scanner finding rated Medium (SEC-L9) | Medium |
| No threat model, or one without its tables or the STRIDE method (SEC-T1) | Medium |
| An endpoint that is not an entry point, or an entry point with no threat (SEC-T2) | Medium |
| An open threat (SEC-T3) | Medium |
| A missing Referrer-Policy or Permissions-Policy (SEC-L1) | Low |
| TRACE or CONNECT accepted without an echo (SEC-L2) | Low |
| A version banner (SEC-L6) | Low |
| A scanner finding rated Low (SEC-L9) | Low |
| Results absent, stale, for another target or URL, or with a needed probe skipped (SEC-L10) | Low |
| A mitigation that names no file, an accepted threat without its ADR, or an unknown STRIDE letter or status (SEC-T3) | Low |
| A threat model not reviewed by a person within review_max_age_days (SEC-T4) | Low |
| A live target missing from the contract ("unmeasured") | Low |
| A finding covered by a waiver ADR | Info |
<!-- live-severity:end -->

**Rating:** **strong**: no High and no Medium. **moderate**: no High, one or more Medium. **weak**: one or more High.

## Steps

### Step 0 — Load or propose the contract

Read `.ascent/contract.yml`, or `.claude/contract.yml` where ASCENT-named files are not allowed, and use its `security:` section: `endpoints`, `live` (`targets`, `allow_prod`, `results_dir`, `max_age_days`, `max_body_bytes`, `scan_threshold`), `threat_model`, `adr_dir` and `waivers`.

If `endpoints` or `live` is missing, **detect, don't ask.** Propose the endpoints from the routes in the code (Express, Fastify, Flask, FastAPI, Django, Go `http.HandleFunc`, Spring mappings, an OpenAPI file), each with its methods, whether it requires sign-in (a guard or middleware on the route), whether it writes, and whether it calls a model; propose `targets` from `.env.example` base URLs, Compose ports and the README. Mark each detected value `# detected: <path:line>` and each guess `# guess`. Show the proposal once and ask the operator to confirm it. Write nothing: the operator commits the file. Until it is confirmed, each target the contract lacks is a Low "unmeasured" finding.

Every `endpoints` entry becomes one `--endpoint 'METHODS PATH AUTH FLAGS'` (`'GET,DELETE /api/items/{id} required write'`), passed to all three scripts.

### Step 1 — Check the threat model first

Run the threat-model check with the same endpoints and include its output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-threat-model.sh" --adr-dir <adr_dir> --maturity <target> [--endpoint '...']... <threat_model.path>
```

The live checks test the entry points the model names. If SEC-T1 or SEC-T2 fails, say which endpoints the model misses and offer the `threat-model` skill; the live runbook can still be written.

### Step 2 — Show the plan

Show what the checks would send, which sends nothing:

```bash
bash "$PLUGIN_ROOT/scripts/run-live-checks.sh" --target <name> --url <url> [--allow-host HOST]... [--endpoint '...']... [--allow-writes] [--allow-ai] --dry-run
```

Explain each probe in one line, and say what `--allow-writes` and `--allow-ai` add and what they risk. Ask the operator which target to use and whether to allow writes and AI calls for it.

### Step 3 — Write the runbook

Write the runbook the operator runs, to the runbook standard (pre-flight, numbered steps with **Expect** and **Stop if**, post-flight, rollback; `ascent-ops` `runbook-check` checks it). It holds, in order:

1. **Pre-flight:** the target is up (`curl -s -o /dev/null -w '%{http_code}' <url>/`), it is the target named (not production unless allowed), and, with `--allow-writes`, its data is disposable.
2. **The live checks**, writing `<results_dir>/<YYYY-MM-DD>-<target>.tsv`:
   ```bash
   bash <plugin>/scripts/run-live-checks.sh --target <name> --url <url> --allow-host <host> --endpoint '...' [--allow-writes] [--allow-ai] [--max-body <bytes>] --out <results_dir>/<date>-<target>.tsv
   ```
3. **The scanners, in pinned containers** (Podman or Docker), writing to `<results_dir>/reports/`. A target on the host's loopback is `host.containers.internal` (Podman) or `host.docker.internal` (Docker) from inside a container. Baseline (passive) ZAP only; an active scan is a separate decision:
   ```bash
   podman run --rm -v "$PWD/<results_dir>/reports:/zap/wrk:rw" docker.io/zaproxy/zap-stable:2.17.0 zap-baseline.py -t <url> -J <date>-<target>-zap.json -I
   podman run --rm -v "$PWD/<results_dir>/reports:/out:rw" docker.io/projectdiscovery/nuclei:v3.11.1 -u <url> -severity low,medium,high,critical -jsonl -o /out/<date>-<target>-nuclei.jsonl -no-interactsh -disable-update-check -timeout 10
   podman run --rm -v "$PWD/<results_dir>/reports:/out:rw" docker.io/hahwul/dalfox:v3.3.0 scan <url> -f jsonl -o /out/<date>-<target>-dalfox.jsonl
   ```
4. **Post-flight:** the results file opens with `# ascent-live-results 1`, holds no token or password (`grep -Ei 'bearer|password=|secret=' <file>` prints nothing), and the target still answers. Stop any server the runbook started.
5. **Commit** the results and reports on a branch, through the delivery loop. Claude never commits them.

### Step 4 — Rate the results

Once the operator has committed the results, run the check and include its output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-live-results.sh" --target <name> --url <url> --maturity <target> --max-age <max_age_days> --threshold <scan_threshold> [--endpoint '...']... [--waived ID,...] [--zap FILE] [--nuclei FILE] [--dalfox FILE] <results_dir>
```

It applies SEC-L1–L10. Then read what the script cannot judge: for each SEC-L4, which handler lacks the guard (`file:line`); for SEC-L1, where the headers should be set (the proxy, the framework's middleware); for each SEC-L9 alert, whether it is a real finding or a scanner false positive, and say why. A waiver needs an ADR in `adr_dir` that names the id (`SEC-L4:/api/items/{id}`, a ZAP `pluginid`, a nuclei `template-id`, `dalfox:<param>`) and a `review_by` date that has not passed.

### Step 5 — Report

```
security-test: <weak|moderate|strong> — <N> High, <N> Medium, <N> Low
Contract: <path, or "no contract: unmeasured">   Target: <name> <url>   Results: <file, date>
Scanners: <ZAP, nuclei, dalfox reports and their dates, or "none">

<SEV>  <file>:<line>  SEC-Lk  <finding>
       Scenario: <what an attacker does, concretely>
       Fix: <one line, with the file to change>
...
Other observations (unrated, not counted above):
- <file>:<line>  <observation>

Script output: <check-threat-model and check-live-results output, verbatim>
Recommended next: <the runbook, if not yet run; fixes; waiver ADRs; the threat-model skill when SEC-T fails>
```

Also name any plugin in `references/plugin-signals.md` whose signal this repository shows and whose skills are not available in this session, with its reason. The file is [plugin-signals.md](../../references/plugin-signals.md).

## What this skill does not do

- Send any request to a target other than the fixture on 127.0.0.1, run a scanner, or start or stop the application.
- Test with credentials, brute-force sign-in, or load-test (load tests belong to `ascent-quality`).
- Run an active ZAP scan, a fuzzer or an exploit; those are separate operator decisions.
- Commit results or reports, or deploy fixes.
