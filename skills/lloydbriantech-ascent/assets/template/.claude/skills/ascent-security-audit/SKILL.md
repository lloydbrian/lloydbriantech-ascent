---
name: ascent-security-audit
description: >-
  Point-in-time security baseline check for <<PROJECT_TITLE>>. Static
  analysis of 5 security surfaces: env-file scope, hardcoded credentials,
  container privilege, nginx security headers, and production URL schemes.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-security-audit

Point-in-time security check that enumerates specific findings across 5 security surfaces. Each finding is independently actionable — a developer can fix one without understanding the others. This is static file-based analysis; runtime security assessment (CVE scanning, SBOM generation, OWASP ZAP) is deferred to v0.4.x.

This is a sibling skill to [ascent-sec-posture](../ascent-sec-posture/SKILL.md). security-audit enumerates point-in-time findings; sec-posture summarizes the project's overall security stance. Neither invokes the other — they share security-relevant project sources as data. For the §5 env-discipline check that [ascent-self-audit](../ascent-self-audit/SKILL.md) includes, see that skill's Step 2 (which delegates to [ascent-env-audit](../ascent-env-audit/SKILL.md)). This skill checks broader security surfaces beyond env discipline.

## When this skill engages

- Before a deploy or release to verify security baseline
- When a developer asks "are there security issues?"
- After adding new infrastructure (Docker, nginx, env vars)
- As a periodic security sweep (recommended: per-phase or before production)

## Inputs

- **`.gitignore`** — must list `.env`
- **`backend/`, `frontend/` source files** — scanned for credential patterns
- **`docker-compose.yml`, `docker-compose.prod.yml`** — container privilege checks
- **`backend/Dockerfile`** — scanned for credential leaks and privilege escalation
- **`nginx/nginx.prod.conf`** (optional) — security header validation

## Outputs

- **Per-check report** — each of the 5 checks marked PASS, FAIL, or WARNING with findings
- **Summary line** — "security-audit: N/5 checks passing"

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Env-file scope

**Condition:** `.gitignore` exists and contains `.env` (or a pattern matching `.env`).

**Action on PASS:** Report "Env-file scope — PASS. .env is gitignored."

**Action on FAIL:** Report "Env-file scope — FAIL. .env is not in .gitignore — secrets may be committed."

### Step 2 — Hardcoded credentials

**Condition:** Scan all files under `backend/` and `frontend/` (excluding `node_modules/`, `dist/`, `.git/`) for credential patterns: `API_KEY=`, `SECRET=`, `PASSWORD=`, `TOKEN=`, `aws_access_key_id`, `aws_secret_access_key`, and base64-encoded strings in assignment context (e.g., `key = "dGVzdA=="`).

**Action on PASS:** Report "Hardcoded credentials — PASS. No credential patterns detected."

**Action on WARNING:** List each finding with file:line. "Hardcoded credentials — WARNING. [N] potential credential(s) found. Verify these are not real secrets." False positives are possible (test fixtures, documentation examples).

### Step 3 — Container privilege

**Condition:** Scan `docker-compose.yml`, `docker-compose.prod.yml`, and all Dockerfiles for `privileged: true`, `--cap-add`, `SYS_ADMIN`, `SYS_PTRACE`.

**Action on PASS:** Report "Container privilege — PASS. No privileged containers or capability escalation."

**Action on FAIL:** Report each finding. "Container privilege — FAIL. [file] uses privileged mode — this breaks container isolation (§1)."

### Step 4 — Nginx security headers

**Condition:** `nginx/nginx.prod.conf` exists.

**Action on PASS (file exists):** Verify the 4 baseline headers are present: `X-Content-Type-Options`, `X-Frame-Options`, `X-XSS-Protection`, `Referrer-Policy`. Report each missing header.

**Action on SKIP (no nginx config):** Report "Nginx security headers — SKIP (no nginx/nginx.prod.conf)."

### Step 5 — Production URL schemes

**Condition:** Scan production-facing files (`docker-compose.prod.yml`, `nginx.prod.conf`, `.env.example`) for `http://` URLs.

Exclude: `http://localhost`, `http://127.0.0.1`, `http://backend` (internal service references).

**Action on PASS:** Report "Production URLs — PASS. No unencrypted external URLs."

**Action on WARNING:** List each finding. "Production URLs — WARNING. [file:line] uses http:// — verify this is intentional."

### Step 6 — Aggregate and report

**Action:** Collect results from Steps 1-5. Report summary with each finding.

## Examples

### Example 1 — Clean project

**Skill output:**
```
ascent-security-audit: 5/5 checks passing
  Env-file scope         PASS (.env gitignored)
  Hardcoded credentials  PASS (no patterns detected)
  Container privilege    PASS (no escalation)
  Nginx security headers PASS (4/4 headers present)
  Production URLs        PASS (no unencrypted external URLs)
```

### Example 2 — Committed .env detected

**Skill output:**
```
ascent-security-audit: 4/5 checks passing (1 failure)
  Env-file scope         FAIL — .env not in .gitignore
  ...
```

## Anti-patterns

### Anti-pattern 1 — Treating security-audit as exhaustive

This skill checks 5 static surfaces. It does not detect runtime vulnerabilities, dependency CVEs, or network-level exposure. **What to do instead:** complement with `npm audit` (dependency CVEs), runtime penetration testing, and infrastructure security reviews. security-audit catches configuration-level mistakes, not all security issues.
