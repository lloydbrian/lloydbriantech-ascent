# ASCENT Scope

What ASCENT is for, what it isn't for, and how to leave the framework if it stops serving you. Seasoned engineers respect frameworks that know their limits more than they respect frameworks that claim universality.

---

## What ASCENT is for

ASCENT is built for a specific shape of project. If your project has these characteristics, the framework will pay back the up-front investment many times over:

| Characteristic | What it looks like |
|---|---|
| **Long-lived** | Expected to run for years, not weeks |
| **Multi-stakeholder** | Has, or will have, more than one engineer touching it |
| **Service-shaped** | A backend (or backend + frontend + maybe agent) deployed as containers |
| **Production-relevant** | Will actually face real users at some point — not a throwaway prototype |
| **Engineering-discipline-valued** | The owner cares about ADRs, conventions, and the long arc, not just speed |
| **Modest-to-medium scale** | One service or a small handful of services — not a large microservices fleet |

The framework's invariants pay off most when the project's lifespan is long enough to encounter handoff, drift, and accumulated debt.

## Project shapes that fit well

These are the project shapes ASCENT was specifically designed around:

- **Internal tools** at a company — dashboards, admin UIs, operational tools
- **Side projects with longevity intent** — projects the author plans to maintain for years
- **Small SaaS products** — single-tenant or early multi-tenant, single backend service
- **Agentic applications** — AI-driven systems with one or more autonomous agents
- **Educational and training platforms** — content-heavy applications with structured progression
- **Family / community tooling** — applications used by a small known group over time

The OpenClaw codebase that informed ASCENT is roughly in this shape. The lawn-care-app mentioned in the mature `make/` reference is another.

## Project shapes that don't fit

ASCENT is explicitly **not** the right framework for these:

| Shape | Why ASCENT doesn't fit | What to use instead |
|---|---|---|
| **Mobile apps (iOS/Android native)** | Containerization-first doesn't apply; the build/test/distribute pipeline is fundamentally different | Native mobile framework tooling (Xcode, Android Studio); platform-specific CI |
| **Browser extensions** | Different distribution model, different security model, different testing model | Manifest V3 templates; browser-specific tooling |
| **Libraries / SDKs** | The output is a package, not a deployed service; many ASCENT invariants are irrelevant | Language-native publishing tooling; conventions like `cargo`, `npm publish`, `pip` |
| **CLI tools** | Single-binary distribution; no service to run; no UI | Language-native CLI scaffolds; `cobra` (Go), `click` (Python), `clap` (Rust) |
| **ML training infrastructure** | Workload shape is batch, not request/response; tooling needs (GPU scheduling, dataset versioning, experiment tracking) are specialized | MLflow, Weights & Biases, Kubeflow, project-specific scaffolds |
| **Data pipelines / ETL** | Workload is scheduled batch with different reliability and observability concerns | Airflow, Prefect, Dagster scaffolds |
| **Large microservices fleets** | ASCENT optimizes for one or a small handful of services; coordination overhead at fleet scale needs different tooling | Service-mesh tooling, polyrepo orchestration, internal developer platforms |
| **Static sites / marketing pages** | Containerization is overkill; the framework's machinery exceeds the project's complexity | Astro, Next.js static export, Hugo, Jekyll |
| **One-off scripts and notebooks** | Short-lived, low-stakes; ASCENT's discipline costs more than the project is worth | Plain Python script; Jupyter; ad-hoc tooling |
| **Throwaway prototypes** | Optimization-for-Day-1000 returns nothing if Day 1000 never comes | Whatever's fastest; come back to ASCENT if the prototype gets adopted |

## Project shapes that partially fit

These are gray-area cases where ASCENT *might* fit with adaptation:

| Shape | Considerations |
|---|---|
| **Monorepos with multiple services** | Each service can be an ASCENT project; the monorepo wrapper is a separate concern. Possibly worth a framework extension in the future. |
| **Hybrid services with significant frontend** | ASCENT's frontend story is React+Vite. If you need React Native, Svelte, Vue, or Flutter, the ui-ux-designer and developer roles need adaptation. |
| **Projects with significant data engineering** | The data-engineer role is in scope, but heavyweight ETL pipelines may exceed what's reasonable. |
| **Projects facing strict compliance regimes** (HIPAA, PCI-DSS, SOC 2) | The cybersecurity role covers OWASP-level baselines but not compliance certification preparation. ASCENT helps but doesn't suffice. |
| **Projects with stringent latency requirements** (sub-millisecond) | The tester role's performance discipline is in scope, but extreme performance engineering may exceed what the framework supports. |

For gray-area cases, the answer is "try it on a small slice and see." ASCENT is opinionated but not all-or-nothing — using the architect role for ADR discipline without using the tester role for load testing is perfectly fine.

## The size limit

ASCENT was designed for projects in the range of:

- 1 to ~50 engineers touching the codebase
- 1 backend service plus optionally 1 frontend and 1 agent
- Hundreds of thousands of lines of code, not tens of millions
- Single-region deployment to start, multi-region as a later addition

Past these scales, the framework's machinery becomes overhead. Large engineering organizations have internal developer platforms that supersede general-purpose frameworks; ASCENT is not trying to compete with those.

## Leaving the framework

If ASCENT stops serving your project, here is the exit:

### Soft exit — stop using new features

ASCENT is not adhesive. You can stop running `lloydbriantech-ascent enhance` and stop invoking the `ascent-*` skills, and the project continues working. The Makefile, the directory structure, the ADRs — these remain useful artifacts regardless of whether the framework is "active."

This is the right exit for projects that have outgrown the framework but still benefit from the existing structure.

### Hard exit — remove the framework

If you want ASCENT completely out of the project:

1. Delete `.ascent-meta.json`
2. Delete `.claude/skills/ascent-*/` directories (the project-embedded skills)
3. Delete `.claude/commands/ascent-*.md` files (the matching slash commands)
4. Delete `.claude/skills/INTENT-MAP.md`
5. (Optional) Remove the `lloydbriantech-ascent` reference in CLAUDE.md
6. (Optional) Reorganize `docs/` if the persona-segmented structure no longer fits

The project remains a fully-functional codebase. Nothing the framework added is locked to the framework. The architectural patterns (layering, ADRs, Makefile structure, containerization) are common-practice patterns that survive removal of the framework that introduced them.

There is no ASCENT runtime dependency. There is no ASCENT library. There is no telemetry. The framework's exit cost is zero except for the time it takes to delete the marker files.

This is deliberate. A framework that locks you in is a framework whose authors don't trust the framework's own value proposition.

## When to migrate to ASCENT from a non-ASCENT project

If you have an existing project that wasn't built with ASCENT and you're wondering whether to migrate:

**Migrate if** the project has accumulated the problems ASCENT solves — inconsistent operator vocabulary, decisions whose rationale was lost, documentation that doesn't reflect reality, new contributors who can't onboard, multiple log formats, no clear release readiness gate.

**Don't migrate if** the project works well as-is and the existing engineering hygiene is solid. ASCENT's value is in the discipline it codifies; if you already have that discipline expressed in different conventions, the migration churn isn't worth it.

The `migrate` mode of the parent skill handles the mechanical work of bringing an existing project up to ASCENT conventions. It is non-destructive — it preserves existing code and structure where possible, adds the framework's artifacts alongside, and lets you delete what you no longer need on your own schedule.

---

## On framework imperialism

There is a temptation, when building a framework, to evangelize. "Every project should use ASCENT." This is unwise. Frameworks that try to be universal end up being mediocre at everything. ASCENT's strength is its opinion, and its opinion fits a specific shape of project.

If your project doesn't fit the shape, find a framework that does — or build your project without one. The author would rather see a project succeed without ASCENT than fail with it.

The framework is not the goal. The goal is good software, built by engineers who can sleep at night because the system they shipped is one they understand and can defend. ASCENT is one path to that. Many other paths exist.
