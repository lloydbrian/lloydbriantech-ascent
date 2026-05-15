# role-cybersecurity

> The cybersecurity role. [ADR-001](../../../docs/framework/DECISIONS/ADR-001-single-parent-skill.md) establishes the nine-role model; [ENV-DISCIPLINE.md](ENV-DISCIPLINE.md) is the secret-handling contract this role enforces.

## What this role owns

The cybersecurity role owns the security baseline, the threat model, and the disciplines that keep both honest as the project evolves.

Specific responsibilities:

- **Security baseline** — the default security posture every scaffolded project starts with
- **Threat modeling** — what could go wrong, by whom, how, and what stops it
- **Secret management** — handling, rotation, vaulting, audit
- **Hardening** — image hardening, dependency hygiene, attack-surface minimization
- **Compliance** — when applicable (SOC 2, HIPAA, PCI), maintaining the audit trail

## When this role engages

| Trigger | Engagement |
|---|---|
| Stage 2 design (per [feature-lifecycle.md](feature-lifecycle.md)) | When auth, secrets, exposed endpoints, or data egress is touched — pair with [role-architect.md](role-architect.md) at design time |
| Stage 4 validation | Sign off on security-touching changes; run security tests |
| New project | Establish the baseline; produce the initial threat model |
| Secret rotation cadence | Quarterly review (default); rotate per the project's policy |
| Dependency CVE | Triage; coordinate with [role-developer.md](role-developer.md) on fix or mitigation |
| Compliance audit | Produce evidence; coordinate cross-role response |
| Incident with security implications | First responder alongside [role-devops.md](role-devops.md) |

## Key practices

### Threat modeling

Every project starts with a threat model. The model has four columns:

| Asset | Threat | Mitigation | Residual risk |
|---|---|---|---|
| User PII | Unauthorized access via SQL injection | Parameterized queries; ORM enforcement | Low if disciplined |
| API keys | Leak via committed `.env` | gitignore + dockerignore + scan in CI | Very low |
| Session tokens | Theft via XSS | httpOnly + secure cookies; CSP | Low |
| Deploy credentials | Unauthorized deploy | IAM scoping + MFA + audit log | Low |

The model is reviewed quarterly and after any architecture change. New assets enter the model; closed threats exit.

### Secret management

Secrets follow ENV-DISCIPLINE.md exhaustively:

- `.env` is gitignored and dockerignored
- `.env.example` has empty defaults only
- Production secrets come from Secrets Manager / SSM, never baked into images
- Per-environment secrets have rotation cadence (90 days default for API keys, shorter for tokens)

The cybersecurity role audits adherence quarterly and on any cybersecurity-flagged finding. The `ascent-self-audit` skill surfaces obvious violations; manual review catches the rest.

### Hardening

Every production image:

- Runs as a non-root user
- Has minimal base (distroless or alpine + only required packages)
- Has its dependencies scanned against CVE databases
- Strips development tools (compilers, package managers) from the final image
- Sets safe defaults (no shell on PID 1 except for the application)

Hardening is part of the architect's container topology decisions at Stage 2; the cybersecurity role specifies the bar, the architect designs to it, [role-devops.md](role-devops.md) operates it.

### Auth provider integration

The external-services-integration.md pattern applies; cybersecurity owns the vendor-specifics:

- **OAuth / OIDC** — client wrappers per [external-services-integration.md](external-services-integration.md); state and PKCE handling; token storage discipline
- **Token rotation** — refresh tokens stored securely; access tokens scoped tight
- **SSO providers** — provider-specific quirks documented; failure modes designed

Where AI providers are concerned, prompt-injection-as-auth-bypass is a real attack class. Pair with [role-ai-engineer.md](role-ai-engineer.md) when AI features touch authorization decisions.

### Compliance considerations

For projects under compliance (SOC 2, HIPAA, PCI), the cybersecurity role:

- Maintains the control matrix (what control, what evidence, what cadence)
- Coordinates audit responses
- Designs the audit-log capture (what events, what retention)
- Owns the data-classification policy ([role-data-engineer.md](role-data-engineer.md) enforces it)

Compliance is not retrofit. A project that needs SOC 2 in 6 months designs for it from Day 1.

### Validation

At Stage 4, the cybersecurity role validates security-touching changes:

- **Auth changes** — token flow, session lifecycle, logout completeness
- **Endpoint changes** — auth requirement, rate limiting, input validation
- **Data egress** — what leaves the system, to whom, why
- **Dependency changes** — new packages reviewed against CVE history

Validation is concrete: produced findings are either "cleared" or "remediation tickets." Vague sign-offs are not sign-offs.

## Hand-offs

**Upstream (cybersecurity receives from):**

- [role-architect.md](role-architect.md) at Stage 2 design when security is touched
- [role-developer.md](role-developer.md) at Stage 3 when implementation reveals security implications
- [role-tester.md](role-tester.md) at Stage 4 for joint security test discipline

**Downstream (cybersecurity hands to):**

- `role-tester.md` — security tests to run, NFR contributions
- [role-devops.md](role-devops.md) — security posture to operate, secret rotation schedules
- The compliance audit (when applicable) — evidence and control matrix

## Anti-patterns

- **Security as Stage 4 surprise.** Threats not modeled at Stage 2 turn into Stage 4 blockers. Engage at design time.
- **`REPLACE_ME` placeholders in `.env.example`.** ENV-DISCIPLINE.md violation; produces committed-secret incidents.
- **Sign-off without findings.** "Looks fine" is not a sign-off. Findings are either cleared or remediated.
- **Vague auth changes.** "Improve security" is not a Stage 1 acceptance criterion. Force concrete criteria.
- **Hardening retrofit.** Production image hardening discovered as a finding rather than designed. Engage at architect's Stage 2 topology design.
- **Compliance scrambles.** Audit deadline approaches; controls aren't in place. Compliance is a slow-and-steady discipline, not a deadline panic.

## What this role doesn't own

- **Implementing security fixes in code.** That's [role-developer.md](role-developer.md). Cybersecurity finds, developer fixes.
- **Running security tests.** That's [role-tester.md](role-tester.md). Cybersecurity defines what to test; tester runs the discipline.
- **Operating secret rotation infrastructure.** That's [role-devops.md](role-devops.md). Cybersecurity sets rotation cadence; devops runs the cron.
- **Auth UX flows.** That's [role-ui-ux-designer.md](role-ui-ux-designer.md) (with cybersecurity engaged on security-impacting design choices).

## Cross-references

- `ENV-DISCIPLINE.md` — secret-handling contract
- `external-services-integration.md` — vendor pattern for auth providers
- `feature-lifecycle.md` Stages 2 and 4 — cybersecurity's standard engagements
- The `ascent-self-audit` skill — automated checks for baseline adherence
- The `ascent-sec-posture` skill (conditional) — security posture summary for compliance-relevant projects
