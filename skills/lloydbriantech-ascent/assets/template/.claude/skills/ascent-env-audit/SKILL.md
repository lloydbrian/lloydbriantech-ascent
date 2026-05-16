---
name: ascent-env-audit
description: >-
  Verifies that <<PROJECT_TITLE>> follows ENV-DISCIPLINE: .env is
  gitignored and dockerignored, .env.example has empty defaults only
  (no REPLACE_ME), every environment variable read in code appears in
  .env.example, and no secrets are committed or baked into images.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-env-audit

Validates <<PROJECT_TITLE>>'s environment variable discipline against the ENV-DISCIPLINE contract. Catches the deployment-incident-in-waiting: committed secrets, fake placeholders that get accidentally deployed, and env vars that code reads but .env.example doesn't declare.

## When this skill engages

- Before a commit that touches .env.example, Dockerfile, or docker-compose files
- As a component of [ascent-self-audit](../ascent-self-audit/SKILL.md)'s comprehensive check
- After adding a new environment variable to the code
- When a security review flags secret-handling concerns

## Inputs

- The project's root directory (reads .env.example, .gitignore, .dockerignore, Dockerfiles, source code)
- No user input required — the audit is autonomous

## Outputs

- A checklist report: each ENV-DISCIPLINE rule marked PASS or FAIL
- For each FAIL: the specific violation, the file/line, and the fix action
- Categories: gitignore (is .env excluded?), dockerignore (is .env excluded from images?), schema-match (does .env.example match code reads?), no-placeholders (no REPLACE_ME patterns), no-committed-secrets

## Operational logic

The skill validates five rules: (1) `.env` appears in `.gitignore`, (2) `.env` appears in `.dockerignore`, (3) `.env.example` exists and contains only empty-value entries (regex check against the REPLACE_ME detection pattern from ENV-DISCIPLINE.md), (4) every `process.env[...]` read in source code has a corresponding entry in `.env.example`, (5) no Dockerfile contains `COPY .env` and git history doesn't contain a committed `.env` file. The full heuristics for source-code env-var extraction and false-positive suppression land in Phase 3.

## Examples

Examples land in Phase 3. Each example will show a specific ENV-DISCIPLINE violation, the audit's output, and the corrective action.

## Anti-patterns

The primary failure mode is **treating .env.example as documentation rather than schema** — adding helpful default values ("3000", "info") that make the file look like a config template rather than the empty-defaults schema ENV-DISCIPLINE requires. The audit must fail on ANY non-empty value in .env.example, not just obvious `REPLACE_ME` patterns.
