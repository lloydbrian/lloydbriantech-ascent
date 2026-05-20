# lloydbriantech-ascent

> An opinionated engineering framework that takes a project from idea to running stack in under two minutes, then keeps it disciplined as it grows.

**Status:** Phase 0 — Foundation · **Version:** 0.1.0-alpha · **License:** MIT OR Apache-2.0

---

## What ASCENT is

ASCENT (the **A**rchitecture and **S**oftware **C**onvention for **E**ngineering, **N**inth-level **T**rust) is a framework for building production-grade software projects with deliberate engineering discipline baked in from Day 0. It pairs:

1. **A Claude skill** (`lloydbriantech-ascent`) that scaffolds, enhances, and migrates projects through nine engineering roles
2. **A template repository** (`lloydbriantech-ascent-starter`) that ships a working stack you can clone in seconds
3. **A set of project-embedded skills** (`ascent-*`) that keep a scaffolded project mature, honest, and ahead of industry norms

ASCENT does not invent new patterns. It codifies hard-won ones — containerization-first development, make-as-operator-vocabulary, label-based scoping, ADR discipline, phase-gated delivery, persona-segmented documentation — into a framework where every project starts with these properties and keeps them.

## Why ASCENT exists

Most engineering frameworks optimize for Day 0 (the scaffold). ASCENT optimizes for **Day 0 through Day 1000** — the long arc where projects accumulate decisions, drift from intent, lose documentation freshness, and silently degrade. The framework is built on the observation that most software quality problems are not problems of skill — they are problems of consistency under fatigue, handoff, and time pressure.

See [`docs/framework/PHILOSOPHY.md`](docs/framework/PHILOSOPHY.md) for the full rationale.

## Quick start

### Option A — Clone the starter (fastest path to a running stack)

```bash
gh repo create lloydbrian/my-new-project \
  --template lloydbrian/lloydbriantech-ascent-starter \
  --private

cd my-new-project

# In Claude Code:
# "Bootstrap this as my-new-project"
# The skill personalizes slugs, applies your option choices, writes .ascent-meta.json

make dev-up
# → http://localhost:3001/healthz responding ✓
```

Total time from `gh repo create` to running dev stack: typically under two minutes.

### Option B — Skill-only (full customization at scaffold time)

```bash
mkdir my-new-project && cd my-new-project

# In Claude Code:
# "Use lloydbriantech-ascent to scaffold this as my-new-project"
# Six-question interview, then full project tree is generated

make dev-up
```

### Installing the skill itself

```bash
gh repo clone lloydbrian/lloydbriantech-ascent ~/Developer/repositories/lloydbriantech-ascent
cd ~/Developer/repositories/lloydbriantech-ascent
make install
# → Symlinks skills/lloydbriantech-ascent/ into ~/.claude/skills/
```

Run `make uninstall` to remove the symlink. `make help` shows the full operator vocabulary.

## The nine roles

The parent skill routes user intent into one of nine engineering roles. Each role owns a non-overlapping slice of the project lifecycle:

| Role | Owns |
|---|---|
| **delivery-lead** | Phase plans, requirements decomposition, risk register, dependencies, gate criteria, status synthesis |
| **architect** | Skeleton, ADRs, container topology, framework docs, Make framework, observability contract |
| **ui-ux-designer** | Design system, theming, page layouts, visual specs, interaction patterns, accessibility-as-design |
| **developer** | Backend implementation, frontend implementation, agent task modules, integration patterns |
| **data-engineer** | Schema design, indexing, query optimization, migration safety, data quality |
| **ai-engineer** | Prompt engineering, eval harnesses, model abstraction, agentic patterns, safety guardrails |
| **tester** | All test disciplines, quality gates, NFR catalog, traceability, validation |
| **devops** | Infra, CI/CD, AWS, distribution, observability collection, release engineering |
| **cybersecurity** | Security baseline, threat modeling, secrets, hardening, compliance |

## The three modes

| Mode | When it engages | What it does |
|---|---|---|
| **scaffold** | No `.ascent-meta.json` present | Greenfield creation — full project tree, working dev stack on Day 1 |
| **enhance** | `.ascent-meta.json` present | Additive changes — new features, ADRs, components, endpoints, infra targets |
| **migrate** | Explicit `--migrate` flag | Bring an existing non-ASCENT (or older-ASCENT) project up to current standards |

## Project-embedded skills

Every scaffolded project ships with **14 baseline** project-embedded skills plus **up to 8 conditional** skills based on architect interview answers. All prefixed `ascent-`, invoked via `/ascent-<name>`:

**Baseline (always scaffolded):**

`ascent-reflect` · `ascent-standup` · `ascent-handoff` · `ascent-onboard` · `ascent-health` · `ascent-delivery-status` · `ascent-self-audit` · `ascent-data-health` · `ascent-doc-sweep` · `ascent-dependency-health` · `ascent-qa` · `ascent-adr-conformance` · `ascent-release-readiness` · `ascent-skills-doctor`

**Conditional:**

`ascent-ai-evals` · `ascent-cost-posture` · `ascent-observability-check` · `ascent-sec-posture` · `ascent-security-audit` · `ascent-design-system-audit` · `ascent-persona-coverage` · `ascent-vitality`

See [`docs/framework/ARCHITECTURE.md`](docs/framework/ARCHITECTURE.md) for the intent/cadence taxonomy.

## Documentation by persona

ASCENT documentation is segmented by reader. The canonical persona→entry-point mapping lives in [`skills/lloydbriantech-ascent/references/audience-mapping.md`](skills/lloydbriantech-ascent/references/audience-mapping.md). Brief summary:

| Persona | Needs | Entry point |
|---|---|---|
| **Architect** | Mental model, decisions, rationale | `ARCHITECTURE.md` → `DECISIONS/INDEX.md` |
| **Developer** | Backend layering, observability hooks, test conventions | `PHILOSOPHY.md` → `role-developer.md` |
| **Operator** | Make-target catalog, runbooks, healthcheck semantics | `make help` (lands per scaffolded project) |
| **Contributor** | PR conventions, commit format, ADR template, contribution bar | `CONTRIBUTING.md` |
| **Learner** | Why ASCENT, what it provides, where it's heading | `PHILOSOPHY.md` → `ROADMAP.md` |

See `audience-mapping.md` for full per-persona detail — what each doesn't need, path-depth bounds, and how to add new personas.

## Documentation map

| If you want to... | Read |
|---|---|
| Understand the framework's design rationale | [`docs/framework/PHILOSOPHY.md`](docs/framework/PHILOSOPHY.md) |
| See the architectural invariants enumerated | [`docs/framework/PRINCIPLES.md`](docs/framework/PRINCIPLES.md) |
| Know what ASCENT is and isn't for | [`docs/framework/SCOPE.md`](docs/framework/SCOPE.md) |
| See where the framework is heading | [`docs/framework/ROADMAP.md`](docs/framework/ROADMAP.md) |
| Understand the framework's own architecture | [`docs/framework/ARCHITECTURE.md`](docs/framework/ARCHITECTURE.md) |
| Read the framework's architectural decisions | [`docs/framework/DECISIONS/INDEX.md`](docs/framework/DECISIONS/INDEX.md) |
| Contribute to the framework | [`CONTRIBUTING.md`](CONTRIBUTING.md) |
| See what changed between versions | [`CHANGELOG.md`](CHANGELOG.md) |

## Status

ASCENT is currently at **Phase 0 — Foundation**, alpha. The meta-repository foundation (this) is the first deliverable. The roadmap calls for v1.0 once all of the following are true:

- Parent skill ships scaffold/enhance/migrate modes across all nine roles
- Template repo successfully spawns a working project in under two minutes
- Three eval scenarios pass in CI on every commit
- At least one personal project has been scaffolded from ASCENT, run through a phase gate, and shipped to production

See [`docs/framework/ROADMAP.md`](docs/framework/ROADMAP.md) for the phase plan.

## Contributing

ASCENT is currently a single-author framework (Lloyd D., `lloydbriantech`). Contributions, suggestions, and bug reports are welcome via [GitHub issues](https://github.com/lloydbrian/lloydbriantech-ascent/issues). See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the contribution model, versioning approach, and review bar.

## License

Dual-licensed under either of:

- Apache License, Version 2.0 ([`LICENSE-APACHE`](LICENSE-APACHE) or <http://www.apache.org/licenses/LICENSE-2.0>)
- MIT License ([`LICENSE-MIT`](LICENSE-MIT) or <http://opensource.org/licenses/MIT>)

at your option. See [`LICENSE`](LICENSE) for the formal statement.

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in this work by you shall be dual-licensed as above, without any additional terms or conditions.

---

*ASCENT is a `lloydbriantech` engineering framework. Built with discipline, in the open.*
