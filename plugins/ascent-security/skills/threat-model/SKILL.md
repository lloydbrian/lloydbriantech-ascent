---
name: threat-model
description: >-
  Use when asked "write our threat model", "what could go wrong at each
  endpoint?", "STRIDE this service", "is our threat model current?", "which
  threats are still open?", or before a first production deploy or a change
  that adds an endpoint. Drafts or updates docs/security/THREAT-MODEL.md
  from the repository with STRIDE: entry points, trust boundaries and the
  threats to each, with a mitigation in code or an accepted ADR, and checks
  it (SEC-T1–T4). Writes only that file, with surgical edits; a person
  reviews and dates it.
version: 0.3.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# threat-model

The design-time half of `ascent-security`'s security testing. It records, for each way into the system, what an attacker could try and what stops them, so the live checks (`security-test`) and reviewers test the right things.

Shared sources:
- [live-rules.md](../../references/live-rules.md): the threat model's format and SEC-T1–T4
- [contract-template.yml](../../references/contract-template.yml): `security.endpoints`, `security.threat_model`, `security.adr_dir`
- The severity table in the `security-test` skill (`live-severity`), which rates every SEC-T finding

## Rules

- **Write one file only.** This skill writes `security.threat_model.path` (default `docs/security/THREAT-MODEL.md`) and nothing else, with surgical edits: never rewrite rows a person has written, and never delete a threat. A threat that no longer applies is marked `accepted (ADR-NNN)` or removed by the person who owns it. Show the proposed rows before writing them; never commit.
- **A person reviews it.** Never fill in `reviewed_on` or `reviewed_by`; leave them `YYYY-MM-DD` and `—` in a new draft, and say that SEC-T4 fails until a person reviews it.
- **Evidence for every mitigation.** A threat is `mitigated` only when the mitigation names, in backticks, the repository file that implements it, and that file does. Otherwise it is `open`. Never mark a threat mitigated because the code probably handles it.
- **Accepted means an ADR.** `accepted (ADR-NNN)` only when an ADR in `security.adr_dir` records the decision; draft the ADR's context for the operator if none exists, never write it.
- **No secrets or personal data** in the model: name files and settings, never values.
- **Rate only with the severity table** in `security-test`. A concern that matches no row goes under **Other observations (unrated)**.
- **Scripts.** The scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`.

## Steps

### Step 0 — Load the contract

Read `.ascent/contract.yml` (or `.claude/contract.yml`): `security.endpoints`, `security.threat_model` (`path`, `review_max_age_days`), `security.adr_dir` and `security.maturity_target`. If `endpoints` is missing, propose it as `security-test` Step 0 does (detect, don't ask) and use the proposal, marked as unconfirmed.

### Step 1 — Map the entry points and boundaries

From the code, list every way in: each endpoint (method and path), each queue or webhook consumer, each scheduled job that reads outside input, each file upload, and each call out to a model or third party whose answer the system trusts. For each, name the trust boundary it crosses (`internet → api`, `api → database`, `api → model provider`) and whether it requires sign-in, with the `file:line` of the route and its guard. Every `security.endpoints` entry must become an entry point (SEC-T2).

### Step 2 — Find the threats, STRIDE by entry point

For each entry point, go through the six STRIDE categories and keep only the threats that apply to it:

| Letter | Category | Ask |
|---|---|---|
| S | Spoofing | Can someone act as another user or service? (sessions, tokens, webhook signatures) |
| T | Tampering | Can input change data or code it should not? (validation, mass assignment, path traversal, injection) |
| R | Repudiation | Can a user deny an action that matters? (audit log for writes and deletes) |
| I | Information disclosure | Can a response, an error or a log leak what it should not? (other users' data, secrets, stack traces, prompt contents) |
| D | Denial of service | Can a request exhaust something? (unbounded queries, body size, model spend, rate limits) |
| E | Elevation of privilege | Can a user reach what their role should not? (object ownership, admin routes, prompt injection into tools) |

For each threat, find the mitigation in the code and cite its file. When there is none, the threat is `open`, with a one-line fix. Keep threats concrete: "A user deletes another user's item through `DELETE /api/items/{id}`", not "authorisation issues".

### Step 3 — Draft or update the model

Show the operator the proposed model, or for an existing one, only the rows to add or change. On their yes, write it in the format of [live-rules.md](../../references/live-rules.md#the-threat-model): the field table (`reviewed_on`, `reviewed_by`, `method: STRIDE`), `## Entry points` (Id, Entry point, Trust boundary, Auth) and `## Threats` (Id, Entry point, STRIDE, Threat, Mitigation, Status). Ids are `EP-<n>` and `TH-<n>`; keep existing ids and number new rows after the last one.

### Step 4 — Check it

Run the check and include its output verbatim:

```bash
bash "$PLUGIN_ROOT/scripts/check-threat-model.sh" --adr-dir <adr_dir> --max-age <review_max_age_days> --maturity <target> [--endpoint '...']... <path>
```

It applies SEC-T1–T4, and a NOTE names the STRIDE categories no threat covers: say for each whether it truly does not apply.

### Step 5 — Report

```
threat-model: <weak|moderate|strong> — <N> High, <N> Medium, <N> Low
Model: <path>   Entry points: <N>   Threats: <N> (<N> mitigated, <N> accepted, <N> open)

<SEV>  <file>:<line>  SEC-Tk  <finding>
       Scenario: <what an attacker does, concretely>
       Fix: <one line>
...
Other observations (unrated, not counted above):
- <file>:<line>  <observation>

Script output: <check-threat-model output, verbatim>
Recommended next: <a person reviews and dates the model; fixes for open threats; ADRs for accepted ones; security-test for the live checks>
```

## What this skill does not do

- Review or date the model in a person's name, or accept a risk.
- Write ADRs, code fixes or any file other than the threat model.
- Test the running application: that is `security-test`, which the operator runs.
