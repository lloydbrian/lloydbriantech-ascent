# audience-mapping

> The canonical persona→entry-point mapping for ASCENT documentation. [PRINCIPLES.md §14](../../../docs/framework/PRINCIPLES.md#14-persona-segmented-documentation) is the authoritative principle this mapping serves.

ASCENT documentation is segmented by audience. This module names each persona, defines what they need from the docs, and prescribes their entry point. When a doc lands without a clear audience, the question is "which persona reads this?" If the answer is "more than one," the doc is too broad — split it.

The persona definitions below are the canonical resource. The README's persona tables summarize and link here; this module is where the mapping lives.

## The five personas

### Architect

**Who:** Designs systems, makes binding decisions, writes ADRs, shapes the framework's invariants.

**Needs:** Understand the framework's mental model before opening any file. Reach decisions and their rationale fast. Trace any architectural choice back to its ADR.

**Entry point:** [`README.md`](../../../README.md) → [`docs/framework/ARCHITECTURE.md`](../../../docs/framework/ARCHITECTURE.md) → [`docs/framework/DECISIONS/INDEX.md`](../../../docs/framework/DECISIONS/INDEX.md)

**Path depth:** 2–3 clicks from any architect concern to the canonical answer.

**Doesn't need:** Operator runbooks, contributor PR mechanics, learner walkthroughs.

### Developer

**Who:** Implements features, writes tests, integrates services, owns the code paths.

**Needs:** Backend layering rules. Observability hooks (per [observability-contract.md](observability-contract.md)). Test conventions. The lifecycle a feature traverses (per [feature-lifecycle.md](feature-lifecycle.md)).

**Entry point:** `README.md` → [`docs/framework/PHILOSOPHY.md`](../../../docs/framework/PHILOSOPHY.md) → [`references/role-developer.md`](role-developer.md) (lands in Chunk 5 of Phase 1)

**Path depth:** 3 clicks max.

**Doesn't need:** ADR archaeology, persona theory, deploy-pipeline mechanics.

### Operator

**Who:** Runs the deployed system, monitors dashboards, responds to alerts, executes runbooks.

**Needs:** The make-target catalog (`make help`). Dashboard URLs. Runbooks for the top 10 incident classes. Healthcheck definitions and what they actually mean.

**Entry point:** `README.md` "Quick start" → `docs/operations/` (lands per project scaffolding; the framework's meta-repo doesn't have this directory because it has no operational surface)

**Path depth:** 1–2 clicks — operators are usually under time pressure.

**Doesn't need:** Implementation details, ADR rationale, framework philosophy.

### Contributor

**Who:** Submits PRs to the framework or to a scaffolded project. Follows repo conventions.

**Needs:** Contribution conventions (PR shape, commit format, ADR template, branch protocol). CHANGELOG conventions. The bar for contribution quality.

**Entry point:** [`CONTRIBUTING.md`](../../../CONTRIBUTING.md)

**Path depth:** 1–2 clicks. Contributors want to ship the change, not study the framework.

**Doesn't need:** End-user docs, operator runbooks, learner intro.

### Learner

**Who:** New to ASCENT. Building mental models. Considering adoption.

**Needs:** Why the framework exists. What it provides. How a working project looks. Cost of adoption. Where the framework is going.

**Entry point:** `README.md` → `PHILOSOPHY.md` → [`docs/framework/ROADMAP.md`](../../../docs/framework/ROADMAP.md)

**Path depth:** 2–3 clicks — learners read in depth but lose patience past 3.

**Doesn't need:** Per-role technical detail, contribution mechanics, runbooks.

## Mapping invariants

These hold across all personas:

1. **One primary persona per doc.** Cross-references suit the originating audience.
2. **The persona's entry point is always reachable from `README.md`.** No persona is buried.
3. **Path depth bounded at 3 clicks.** Per [doc-architecture.md](doc-architecture.md).
4. **Doc voice matches the primary persona.** An Architect doc reads differently than a Learner doc. See [writing-style.md](writing-style.md).
5. **Persona-purity is enforceable.** If a doc mixes two personas, audit it against this mapping and split it.

## Cross-persona docs

A few docs serve all personas as flat reference (`CHANGELOG.md`, `LICENSE` files, the ADR `INDEX.md`). These are exempt from the one-primary-persona rule — they're reference catalogs, not narrative.

The framework's reference modules (this directory) are also cross-persona — they're consumed by the skill at runtime when any role engages, not by a specific human reader.

## Adding a new persona

If a new persona surfaces — Researcher wanting to study ASCENT as a framework, Compliance wanting auditable trails, Educator using ASCENT in coursework — this module updates first. The README, role modules, and project-embedded skills then update their cross-references to match.

Adding a persona without updating this module risks audience drift: docs accumulate that don't trace to a named reader. That's the doc-theater failure mode `doc-architecture.md` warns against.

## What this doc doesn't cover

- Per-persona detail (what each role does day-to-day) — that lives in the role-`*` modules (Chunk 5 of Phase 1)
- Structural rules for the doc graph (depth, cross-link direction) — that lives in `doc-architecture.md`
- Voice for each persona's docs — that lives in `writing-style.md`

Together, audience-mapping (who reads), doc-architecture (how docs connect), and writing-style (how docs sound) form ASCENT's documentation discipline.
