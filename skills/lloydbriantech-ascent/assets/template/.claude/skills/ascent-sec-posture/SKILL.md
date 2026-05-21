---
name: ascent-sec-posture
description: >-
  Security posture summary for <<PROJECT_TITLE>>. Produces a current-stance
  snapshot: severity-classified findings, coverage assessment across security
  surfaces, and gap identification. Computed fresh each invocation.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-sec-posture

Summarizes the project's current security stance across all security-relevant surfaces. While [ascent-security-audit](../ascent-security-audit/SKILL.md) enumerates specific point-in-time findings, sec-posture produces an aggregate view: how many surfaces are covered, what severity distribution exists, and where coverage gaps remain.

This is a sibling skill to security-audit. Neither invokes the other — they share security-relevant project sources as data. security-audit enumerates; sec-posture summarizes. The posture is computed fresh on each invocation. Drift detection (comparing posture snapshots over time) is deferred to v0.4.x when a storage mechanism is in place.

**Data sources:** sec-posture reads the same security-relevant files that security-audit reads: `.gitignore` (env-file scope), `backend/` and `frontend/` source files (credential patterns), `docker-compose.yml` and `docker-compose.prod.yml` (container privilege), `backend/Dockerfile` (build-time security), and `nginx/nginx.prod.conf` (security headers). Additionally, it reads `.env.example` (declared secrets inventory) and `docs/architecture/decisions/INDEX.md` (for security-related ADRs).

## When this skill engages

- Before a stakeholder or compliance review
- When a developer asks "what's our security posture?" or "how secure is this project?"
- As a periodic summary (recommended: per-phase or quarterly)
- After security-audit flags findings — posture contextualizes individual findings

## Inputs

- **`.gitignore`** — env-file scope assessment
- **`backend/`, `frontend/` source files** — credential pattern coverage
- **`docker-compose.yml`, `docker-compose.prod.yml`, `backend/Dockerfile`** — container security
- **`nginx/nginx.prod.conf`** (optional) — header coverage
- **`.env.example`** — declared secrets inventory
- **`docs/architecture/decisions/INDEX.md`** — security-related ADRs

## Outputs

- **Posture summary** — coverage percentage, severity distribution, gap list
- **Summary line** — "sec-posture: [strong | moderate | weak] — N/M surfaces assessed"

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Scan security surfaces

**Action:** Check each security surface for presence and assessability:

| Surface | Source file(s) | Assessable when |
|---|---|---|
| Env-file scope | `.gitignore` | .gitignore exists |
| Credential hygiene | `backend/`, `frontend/` source | Source directories exist |
| Container security | `docker-compose*.yml`, Dockerfiles | Compose or Dockerfile exists |
| Network security | `nginx/nginx.prod.conf` | nginx config exists |
| Secret inventory | `.env.example` | .env.example exists |

Report: "[N]/5 security surfaces assessable."

### Step 2 — Classify findings by severity

**Action:** For each assessable surface, run the same checks security-audit uses (Steps 1-5 logic) and classify:

- **High severity:** .env not gitignored, hardcoded credentials detected, privileged containers
- **Medium severity:** missing nginx security headers, http:// in production configs
- **Low severity:** .env.example missing (no secrets inventory documented)

### Step 3 — Identify coverage gaps

**Action:** Report surfaces that cannot be assessed because the source file doesn't exist. Example: "nginx security headers: not assessed (no nginx/nginx.prod.conf)."

Coverage gaps are informational, not failures — a project without nginx legitimately has no nginx security surface.

### Step 4 — Produce posture summary

**Action:** Aggregate into a posture rating:

- **Strong:** 0 high-severity findings, 0-1 medium, all assessable surfaces clean
- **Moderate:** 0 high-severity, 2+ medium, or 1+ coverage gaps in critical surfaces
- **Weak:** any high-severity finding

Report:
```
sec-posture: [strong | moderate | weak] — N/M surfaces assessed
  High: [count]  Medium: [count]  Low: [count]
  Coverage gaps: [list or "none"]
```

## Examples

### Example 1 — Strong posture

```
sec-posture: strong — 5/5 surfaces assessed
  High: 0  Medium: 0  Low: 0
  Coverage gaps: none
```

### Example 2 — Posture with gaps

```
sec-posture: moderate — 4/5 surfaces assessed
  High: 0  Medium: 1 (missing X-XSS-Protection header)  Low: 0
  Coverage gaps: secret inventory (no .env.example)
```

## Anti-patterns

### Anti-pattern 1 — Confusing posture with compliance

sec-posture reports current security stance, not compliance with a specific framework (SOC 2, HIPAA, PCI-DSS). **What to do instead:** use posture as input to compliance assessments, not as a substitute. Compliance requires documented controls, audit trails, and third-party verification — none of which this skill provides.
