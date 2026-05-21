# INTENT-MAP — Project-embedded skill routing

Maps user intent shapes to the appropriate `ascent-*` skill for <<PROJECT_TITLE>>. When a user describes what they want, this map determines which skill engages. All 28 skills are implemented as of ASCENT v0.4.0.

---

## Intent → Skill mapping

| Intent shape | Skill | Cadence |
|---|---|---|
| "Is my project ASCENT-compliant?" / "check the 15 principles" / "invariant audit" | [ascent-self-audit](ascent-self-audit/SKILL.md) | Per-commit or weekly |
| "Is my backend layered correctly?" / "check for layering violations" | [ascent-layering-check](ascent-layering-check/SKILL.md) | Per-commit |
| "Check my .env" / "audit environment variables" / "any secrets committed?" | [ascent-env-audit](ascent-env-audit/SKILL.md) | Per-commit |
| "Is my service observable?" / "check logging" / "verify healthchecks" | [ascent-observability-check](ascent-observability-check/SKILL.md) | Per-deploy |
| "Where are we?" / "what's left in this phase?" / "status" | [ascent-delivery-status](ascent-delivery-status/SKILL.md) | Daily |
| "New feature: X" / "I want to add Y" / "intake this request" | [ascent-feature-intake](ascent-feature-intake/SKILL.md) | Per-feature |
| "What did we do yesterday?" / "standup" / "recent activity" | [ascent-standup](ascent-standup/SKILL.md) | Daily |
| "Write an ADR for X" / "document this decision" | [ascent-adr-write](ascent-adr-write/SKILL.md) | Per-decision |
| "Create docs for X" / "I need a doc about Y" | [ascent-doc-stub](ascent-doc-stub/SKILL.md) | Per-feature |
| "Add a make target for X" / "I need a command to do Y" | [ascent-make-target](ascent-make-target/SKILL.md) | Per-feature |
| "Is the database configured correctly?" / "check data health" | [ascent-data-health](ascent-data-health/SKILL.md) | Per-schema-change |
| "Are the docs fresh?" / "check documentation" / "any stale TODOs?" | [ascent-doc-sweep](ascent-doc-sweep/SKILL.md) | Monthly or per-phase |
| "Are dependencies healthy?" / "check for unpinned versions" | [ascent-dependency-health](ascent-dependency-health/SKILL.md) | Per-dependency-change |
| "Do our ADRs conform?" / "check ADR structure" | [ascent-adr-conformance](ascent-adr-conformance/SKILL.md) | Per-ADR-change |
| "Is the skill collection healthy?" / "check skill integrity" | [ascent-skills-doctor](ascent-skills-doctor/SKILL.md) | Per-skill-change |
| "Capture this session" / "reflect" / "end of session" | [ascent-reflect](ascent-reflect/SKILL.md) | End-of-session |
| "Write a handoff" / "document project state for someone else" | [ascent-handoff](ascent-handoff/SKILL.md) | Per-handoff |
| "Walk me through this project" / "where do I start?" / "onboard me" | [ascent-onboard](ascent-onboard/SKILL.md) | Per-onboarding |
| "What should I fix before committing?" / "quality gate" / "ready to commit?" | [ascent-qa](ascent-qa/SKILL.md) | Weekly or per-phase |
| "Are we ready to release?" / "can I tag this?" | [ascent-release-readiness](ascent-release-readiness/SKILL.md) | Pre-release |
| "What security issues exist?" / "enumerate security findings" / "check security baseline" | [ascent-security-audit](ascent-security-audit/SKILL.md) | Per-phase or pre-deploy |
| "What's our security stance?" / "current security posture" / "security overview" | [ascent-sec-posture](ascent-sec-posture/SKILL.md) | Per-phase or quarterly |
| "Are we tracking costs?" / "check cost discipline" | [ascent-cost-posture](ascent-cost-posture/SKILL.md) | Per-infra-change |
| "Is this project still active?" / "are we stalling?" | [ascent-vitality](ascent-vitality/SKILL.md) | Monthly or per-phase |
| "Composite project stance" / "how are we across data, deps, docs, ADRs?" / "weekly health review" | [ascent-health](ascent-health/SKILL.md) | Weekly |
| "Check AI eval coverage" / "validate eval scenarios" | [ascent-ai-evals](ascent-ai-evals/SKILL.md) | Per-prompt-change |
| "Audit the design system" / "check design tokens" | [ascent-design-system-audit](ascent-design-system-audit/SKILL.md) | Per-design-change |
| "Are all personas covered?" / "check persona entry points" | [ascent-persona-coverage](ascent-persona-coverage/SKILL.md) | Per-doc-restructure |

## Skill categories

**Foundation (structural enforcement, read-only):**

- `ascent-self-audit` — umbrella: composes 3 sub-checks + 12 direct invariant checks
- `ascent-layering-check` — component: routes → controllers → services → storage
- `ascent-env-audit` — component: .env discipline
- `ascent-observability-check` — component: emission contract

**Delivery (phase tracking and workflow):**

- `ascent-delivery-status` — reporting: phase state + §15 session context
- `ascent-feature-intake` — intake: decomposes requests into testable criteria
- `ascent-standup` — reporting: recent activity summary

**Authoring (write-capable, produce artifacts):**

- `ascent-adr-write` — produces ADR files + INDEX.md updates
- `ascent-doc-stub` — produces persona-targeted doc skeletons
- `ascent-make-target` — proposes + creates make targets in .mk files

**Health checks (specialized, read-only):**

- `ascent-data-health` — data tier: WAL, FK, migrations
- `ascent-doc-sweep` — docs: provenance, orphans, stale markers
- `ascent-dependency-health` — deps: pinned versions, engines, traceability
- `ascent-adr-conformance` — ADRs: sections, INDEX sync, supersession
- `ascent-skills-doctor` — skills: frontmatter, INTENT-MAP sync, cross-refs

**Lifecycle (session and developer lifecycle):**

- `ascent-reflect` — end-of-session capture to §15 artifacts
- `ascent-handoff` — progressive-depth HANDOFF.md for project transfer
- `ascent-onboard` — read-only "first hour" walkthrough

**Quality gates (composite, read-only):**

- `ascent-qa` — surface-level quality sweep with conditional recommendations
- `ascent-release-readiness` — pre-release shipping discipline validation

**Security and cost (conditional):**

- `ascent-security-audit` — point-in-time: 5 static security checks
- `ascent-sec-posture` — current-stance summary across security surfaces
- `ascent-cost-posture` — cloud-generic cost discipline checks
- `ascent-vitality` — project activity/momentum signals

**Advanced conditional:**

- `ascent-health` — composite stance summarizer at 1:4 fan-in
- `ascent-ai-evals` — eval scenario structure + prompt-test coverage
- `ascent-design-system-audit` — token consistency + hardcoded value detection
- `ascent-persona-coverage` — persona entry-point + depth validation

## Cadence guide

| Cadence | Skills | When to run |
|---|---|---|
| **Per-commit** | ascent-self-audit, ascent-layering-check, ascent-env-audit | Before committing; integrate into pre-commit hook or CI |
| **Daily** | ascent-delivery-status, ascent-standup | Morning standup; "where are we?" |
| **Per-feature** | ascent-feature-intake, ascent-make-target, ascent-doc-stub | When a new feature enters; when new operations needed |
| **Per-decision** | ascent-adr-write | When an architectural choice is made |
| **Per-deploy** | ascent-observability-check, ascent-security-audit | Before staging/production deploy |
| **End-of-session** | ascent-reflect | Before closing the conversation or context-switching |
| **Per-handoff** | ascent-handoff | When transferring project to another developer |
| **Per-onboarding** | ascent-onboard | When a new developer joins the project |
| **Weekly** | ascent-qa, ascent-health | Periodic quality and health sweep |
| **Monthly / per-phase** | ascent-doc-sweep, ascent-vitality, ascent-sec-posture | Periodic freshness and momentum checks |
| **Pre-release** | ascent-release-readiness | Before tagging a release |
| **Per-change** | ascent-data-health, ascent-dependency-health, ascent-adr-conformance, ascent-skills-doctor, ascent-cost-posture, ascent-ai-evals, ascent-design-system-audit, ascent-persona-coverage | When the relevant subsystem changes |
