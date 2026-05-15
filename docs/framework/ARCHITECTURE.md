# ASCENT Framework Architecture

How the framework is built. This document describes the four-layer architecture of the framework itself — not the architecture of projects scaffolded by it. For project-level architecture, see the architect role's reference modules.

---

## The four layers

ASCENT is a four-layer system. Each layer has a single responsibility and a clean boundary.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  LAYER 4 — Scaffolded Projects (one per project, user-owned)    │
│  ──────────────────────────────────────────────────────────     │
│   .ascent-meta.json    .claude/skills/ascent-*    docs/  ...     │
│                                                                  │
│   The output of running the framework on a project.              │
│   Lives in the user's repos, not in this repo.                   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ scaffold / enhance / migrate
                              │
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  LAYER 3 — Template Repo (lloydbriantech-ascent-starter)        │
│  ──────────────────────────────────────────────────────────     │
│   A pre-applied Day-0 scaffold as a GitHub template repo.        │
│   Users gh repo create --template for instant working stack.     │
│   Generated from Layer 2 by CI on every framework tag.           │
│   Force-pushed; never edited directly.                           │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ tools/build-starter.sh
                              │
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  LAYER 2 — Parent Skill (lloydbriantech-ascent)                 │
│  ──────────────────────────────────────────────────────────     │
│   SKILL.md   references/   assets/template/   scripts/           │
│                                                                  │
│   The active source of truth. Routes user intent to roles,       │
│   loads reference modules, performs scaffold/enhance/migrate.    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ built and maintained in
                              │
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│  LAYER 1 — Meta-Repository (lloydbrian/lloydbriantech-ascent)   │
│  ──────────────────────────────────────────────────────────     │
│   README.md, CLAUDE.md, CHANGELOG, docs/, skills/, tools/, tests/│
│                                                                  │
│   The repo you're reading. Contains the framework's source,      │
│   documentation, ADRs, tooling, and tests.                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Layer 1 — Meta-Repository

This repository (`lloydbrian/lloydbriantech-ascent`). The source of truth for everything.

Contains:

- Framework documentation (`docs/framework/`)
- Framework ADRs (`docs/framework/DECISIONS/`)
- The parent skill source (`skills/lloydbriantech-ascent/`)
- Build, test, and packaging tools (`tools/`)
- Eval scenarios (`tests/`)
- Repository hygiene (CI workflows, issue templates, editor config)

The meta-repository **applies ASCENT to itself** — Makefile-as-operator-vocabulary, ADR discipline, persona-segmented docs, dual licensing, phase-gated delivery.

### Layer 2 — Parent Skill

The `lloydbriantech-ascent` skill, which lives at `skills/lloydbriantech-ascent/` inside Layer 1. When installed, it's symlinked into `~/.claude/skills/`.

The skill is one Claude skill — not nine. It routes by user intent to one of nine role modules at runtime. This is the consequence of [ADR-001](DECISIONS/ADR-001-single-parent-skill.md) — having nine separate skills produces trigger collisions when the user describes a task that could plausibly land in multiple roles.

Internal structure:

```
skills/lloydbriantech-ascent/
├── SKILL.md                       # Frontmatter + role-routing logic
├── references/                    # Loaded into context as needed
│   ├── role-delivery-lead.md
│   ├── role-architect.md
│   ├── role-ui-ux-designer.md
│   ├── role-developer.md
│   ├── role-data-engineer.md
│   ├── role-ai-engineer.md
│   ├── role-tester.md
│   ├── role-devops.md
│   ├── role-cybersecurity.md
│   ├── ASCENT-INVARIANTS.md       # The 14 principles
│   ├── MAKE-NAMING.md             # The naming convention
│   ├── SLUG-CONVENTIONS.md        # Slug taxonomy
│   ├── PHASE-PROTOCOL.md          # Phase-gated delivery
│   ├── ENV-DISCIPLINE.md          # .env handling
│   ├── ADR-TEMPLATE.md            # The canonical ADR format
│   ├── feature-lifecycle.md       # How features traverse roles
│   ├── observability-contract.md  # What every service emits
│   ├── writing-style.md           # Doc voice/tense/anti-patterns
│   ├── doc-architecture.md        # Persona navigation
│   ├── audience-mapping.md        # Persona → doc mapping
│   └── external-services-integration.md  # Vendor patterns
├── assets/template/               # Files copied + slug-substituted into projects
│   └── (the substantive baseline content)
└── scripts/
    ├── scaffold.py                # Performs scaffold mode
    ├── bootstrap.py               # Personalizes a clone of the starter
    ├── enhance.py                 # Performs enhance mode
    └── migrate.py                 # Performs migrate mode
```

### Layer 3 — Template Repo

The `lloydbrian/lloydbriantech-ascent-starter` repository — a separate GitHub repo marked as a GitHub Template. Users `gh repo create --template` from it to get a 5-second working scaffold.

This layer is **generated**, not authored. The CI workflow `release.yml` runs `tools/build-starter.sh` on every framework tag, which:

1. Takes the parent skill's `assets/template/` directory
2. Resolves all slug placeholders to the default `ascent-starter` slug
3. Force-pushes the result to the starter repo with a matching tag

The starter repo is never edited directly. Direct edits would be lost on the next release. The pattern is identical to how generated artifacts are handled in any mature build system — you don't edit `dist/`, you edit `src/`.

### Layer 4 — Scaffolded Projects

User-owned repositories that ASCENT has scaffolded. Each one contains:

- `.ascent-meta.json` at the project root marking it as an ASCENT project
- `.claude/skills/ascent-*/` directories — the project-embedded skills
- The full project tree per the architect role's defaults
- Any project-level ADRs the user has added

These projects are independent. They don't pull from the framework at runtime. The framework's role ends after scaffolding — from that point forward, the project is the user's, and they can run `lloydbriantech-ascent enhance` to add to it, run `migrate` to upgrade it, or stop using the framework entirely.

---

## Cross-cutting concerns

### Versioning

Lockstep across layers:

- Layer 1 — git tag on the meta-repo (`v0.3.0`)
- Layer 2 — `version:` field in `SKILL.md` frontmatter (`0.3.0`)
- Layer 3 — git tag on the starter repo (`v0.3.0`), force-pushed by CI
- Layer 4 — `framework_version` field in `.ascent-meta.json`

Mismatches are CI failures.

### Mode detection

The skill (Layer 2) detects which mode to operate in by reading the target directory:

| Condition | Mode | Behavior |
|---|---|---|
| No `.ascent-meta.json` present | `scaffold` | Greenfield creation; interview + full project tree |
| `.ascent-meta.json` present | `enhance` | Read existing state; additive changes only |
| User invokes with `--migrate` | `migrate` | Bring non-ASCENT project to ASCENT standards |
| Directory contains `ascent-starter` slug and `.ascent-meta.json` is a placeholder | `bootstrap` | User cloned the starter; perform interview + slug replacement |

### Slug derivation

User provides one slug; framework derives the rest:

```
INPUT:  lawn-care-app

DERIVED:
  PROJECT_SLUG_UPPER       LAWN_CARE_APP
  PROJECT_TITLE            Lawn Care App
  PROJECT_PKG              lawn-care-app
  PROJECT_LABEL            lawn-care-app
  CONTAINER_DEV            lawn-care-app-dev
  CONTAINER_PROD           lawn-care-app-prod
  IMAGE_DEV                lawn-care-app:dev
  IMAGE_PROD               lawn-care-app:prod
  INSIDE_CONTAINER_MARKER  LAWN_CARE_APP_INSIDE_CONTAINER
```

See [ADR-004](DECISIONS/ADR-004-slug-conventions.md) for the derivation rules.

### Modify-not-overwrite

When the skill (Layer 2) writes to a scaffolded project (Layer 4) in `enhance` or `migrate` mode, it never overwrites whole files. It performs surgical edits using `str_replace`-style operations. This is the contract that allows multi-mode operation to coexist with user customization.

See [ADR-002](DECISIONS/ADR-002-modify-not-overwrite.md) for the rationale.

### Dogfooding

Layer 1 (this repo) applies ASCENT to itself wherever applicable. The Makefile uses the SDLC-sectioned help convention. The CHANGELOG follows Keep a Changelog. The licensing is dual MIT/Apache-2.0. The ADRs use the canonical template. The CI workflows mirror what the framework would generate in a scaffolded project.

The exceptions are deliberate: Layer 1 doesn't have a backend or a frontend, so the architect role's full output doesn't apply. The dogfooded portion is what's relevant to a meta-repo: discipline, conventions, decisions.

---

## What the framework is not

### Not a runtime

Scaffolded projects do not import a framework library. The framework's "output" is *files*, and those files are independent of the framework after creation. This is intentional. A framework with a runtime would couple every scaffolded project to the framework's release cadence; ASCENT scaffolds projects that survive the framework's deletion.

### Not a build system

The Makefile structure ASCENT generates is operator vocabulary, not a build system. It delegates to language-native build tools (npm, vite, etc.) where needed. The framework doesn't compete with `webpack`, `gradle`, `cargo`, or `make` itself.

### Not a deploy system

The infra targets in `make/infra.mk` are convenient wrappers around AWS CLI calls. They are not a deploy abstraction layer. ASCENT doesn't invent its own deploy model; it provides consistent operator vocabulary for the deploy model AWS already offers.

### Not a service mesh

ASCENT is for projects with one or a small handful of services. Service-to-service communication at larger scale needs different tooling (Linkerd, Istio, Consul). The framework's networking patterns are simple by design.

---

## Reading further

| Topic | Where |
|---|---|
| Why one parent skill instead of six | [ADR-001](DECISIONS/ADR-001-single-parent-skill.md) |
| Why modify-not-overwrite | [ADR-002](DECISIONS/ADR-002-modify-not-overwrite.md) |
| Why `.ascent-meta.json` at project root | [ADR-003](DECISIONS/ADR-003-ascent-meta-marker.md) |
| How slugs are derived | [ADR-004](DECISIONS/ADR-004-slug-conventions.md) |
| Why the naming conventions are what they are | [ADR-005](DECISIONS/ADR-005-skill-naming.md) |
| Why dual MIT/Apache-2.0 licensing | [ADR-006](DECISIONS/ADR-006-dual-licensing.md) |
| Why pair the skill with a template repo | [ADR-007](DECISIONS/ADR-007-template-repo-pairing.md) |
| What's planned for future phases | [`ROADMAP.md`](ROADMAP.md) |
