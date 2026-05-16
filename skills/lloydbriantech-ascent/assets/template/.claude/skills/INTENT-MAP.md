# INTENT-MAP — Project-embedded skill routing

Maps user intent shapes to the appropriate `ascent-*` skill for <<PROJECT_TITLE>>. When a user describes what they want, this map determines which skill engages.

The 9 baseline skills ship with the project scaffold. Additional skills (5 remaining baseline + 8 conditional) arrive in Phase 3 of the ASCENT framework.

---

## Intent → Skill mapping

| Intent shape | Skill | Cadence |
|---|---|---|
| "Is my project ASCENT-compliant?" / "audit the project" / "check invariants" | [ascent-self-audit](ascent-self-audit/SKILL.md) | Per-commit or weekly |
| "Where are we?" / "what's left in this phase?" / "status" | [ascent-delivery-status](ascent-delivery-status/SKILL.md) | Daily |
| "Write an ADR for X" / "document this decision" / "record this architecture choice" | [ascent-adr-write](ascent-adr-write/SKILL.md) | Per-decision |
| "Create docs for X" / "I need a doc about Y" / "generate documentation" | [ascent-doc-stub](ascent-doc-stub/SKILL.md) | Per-feature |
| "Add a make target for X" / "I need a command to do Y" | [ascent-make-target](ascent-make-target/SKILL.md) | Per-feature |
| "New feature: X" / "I want to add Y" / "intake this request" | [ascent-feature-intake](ascent-feature-intake/SKILL.md) | Per-feature |
| "Is my service observable?" / "check logging" / "verify healthchecks" | [ascent-observability-check](ascent-observability-check/SKILL.md) | Per-deploy or per-service-change |
| "Check my .env" / "audit environment variables" / "any secrets committed?" | [ascent-env-audit](ascent-env-audit/SKILL.md) | Per-commit |
| "Is my backend layered correctly?" / "check for layering violations" | [ascent-layering-check](ascent-layering-check/SKILL.md) | Per-commit |

## Skill categories

**Structural enforcement (read-only, audit/check):**

- `ascent-self-audit` — umbrella: composes all checks
- `ascent-layering-check` — component: routes→controllers→services→storage
- `ascent-env-audit` — component: .env discipline
- `ascent-observability-check` — component: emission contract
- `ascent-delivery-status` — reporting: phase state + next actions

**Authoring assistance (write-capable):**

- `ascent-adr-write` — produces ADR files + INDEX.md updates
- `ascent-doc-stub` — produces persona-targeted doc skeletons
- `ascent-make-target` — proposes + creates make targets in .mk files
- `ascent-feature-intake` — produces intake artifacts in PHASE-PLAN

## Cadence guide

| Cadence | Skills | When to run |
|---|---|---|
| **Per-commit** | ascent-self-audit, ascent-layering-check, ascent-env-audit | Before committing; integrate into pre-commit hook or CI |
| **Daily** | ascent-delivery-status | Morning standup; "where are we?" |
| **Per-feature** | ascent-feature-intake, ascent-make-target, ascent-doc-stub | When a new feature enters; when new operations needed |
| **Per-decision** | ascent-adr-write | When an architectural choice is made |
| **Per-deploy** | ascent-observability-check | Before staging/production deploy |

## Phase 3 additions

The following skills are deferred to Phase 3 of the ASCENT framework (not yet scaffolded):

- **Remaining baseline (5):** ascent-reflect, ascent-standup, ascent-handoff, ascent-onboard, ascent-health
- **Specialized checks (7):** ascent-data-health, ascent-doc-sweep, ascent-dependency-health, ascent-qa, ascent-adr-conformance, ascent-release-readiness, ascent-skills-doctor
- **Conditional (7):** ascent-ai-evals, ascent-cost-posture, ascent-sec-posture, ascent-security-audit, ascent-design-system-audit, ascent-persona-coverage, ascent-vitality

The full intent-pattern table (covering all skills) lands in Phase 3's INTENT-MAP.md expansion.
