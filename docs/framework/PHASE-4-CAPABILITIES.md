# Phase 4 Capabilities — Prompt content and START-HERE.md v1

The companion document to PHASE-4-PLAN.md. Holds v1 drafts of the user-facing content that scaffold.py renders and that ASCENT projects ship with.

**Scope:** Six capability prompts (one per capability identified in PHASE-4-PLAN.md §5.1) and the v1 content of START-HERE.md.tmpl that ships into every ASCENT project. Both are v1 — refinable via plan-amendment discipline per PHASE-4-PLAN.md §6.3.

**Input:** PHASE-4-PLAN.md design decisions (Q1-Q6 plus the two-quality-checkpoints framing), the prompt-definition structure from §5.4 (9 fields per capability), and the developer-facing voice principles from §6.4.

---

## §1 — Companion overview

### 1.1 Purpose of this document

PHASE-4-PLAN.md is the design authority for Phase 4. It captures decisions, dependencies, exit criteria, and the cluster plan. This companion document holds the user-facing content that lives downstream of the plan's decisions:

- **Capability prompts (§2-§7).** The actual text scaffold.py renders when asking the developer about each capability. Each capability section drafts the 9-field prompt definition as v1 user-facing copy.
- **START-HERE.md content (§8).** The v1 content of the START-HERE.md template that lives at the root of every ASCENT project. Tells the developer what was scaffolded, what capabilities are active, and how to proceed from zero to customer-ready deployment.
- **Schema file lifecycle discipline (§9).** The generic operational discipline for the six authority schema files that ship with conditional capabilities. Schema files are the canonical record of the developer's domain choices; this section establishes how they're used, maintained, and audited.

The split honors the object-oriented documents principle: design decisions live in the plan; user-facing content lives in the companion. Each file does one job.

### 1.2 Relationship to scaffold.py and START-HERE.md.tmpl

Per PHASE-4-PLAN.md §5.4, scaffold.py's CAPABILITY_PROMPTS data structure is the canonical mapping authority. This companion document is the v1 *content* that fills that structure.

The flow:

1. This companion document drafts v1 content per capability.
2. Cluster 1 implements scaffold.py with CAPABILITY_PROMPTS populated from this content.
3. Cluster 3 implements START-HERE.md.tmpl with content drafted in §8 below, with conditional sections adapted to capability state.
4. Refinements (informed by Phase 7's first production project) land via plan-amendment discipline — amendments appended to the end of this document, never rewriting the v1 text.

The v1 text remains as durable record of original design intent. Future versions accumulate as appendices.

### 1.3 Voice principles applied here

All capability prompts and START-HERE.md content honor:

- **Concrete over abstract.** Specific examples ("AWS Lambda, GCP Cloud Run, fly.io") rather than generic categories ("cloud infrastructure").
- **Second-person.** Direct address to the developer ("Will this project deploy to...?"), not third-person observer voice.
- **Skill-value framing, not feature framing.** Describe what the developer gets (the skill's runtime value), not just what the framework provides. "Catches drift before your bill does" rather than "implements cost-discipline auditing."
- **Default-explicit.** Defaults appear in square brackets where they exist (`[n]` for capability questions; values like `[podman]` for non-capability questions). Pressing Enter accepts the default.
- **Conservative on framework-internal language.** Avoid skill names in question text where possible — frame around the project, not around the skill. "Will this project have AI features?" not "Do you want ascent-ai-evals?" The skill mapping is internal; the developer's mental model is project-shaped.

These principles apply to every prompt and every paragraph of START-HERE.md content below.

### 1.4 POV vocabulary

This companion document inherits PHASE-4-PLAN.md's POV vocabulary (per plan §1.2.1) and applies it consistently:

- **Meta-repo-POV** — concerns that live in `lloydbrian/lloydbriantech-ascent`, the framework's repository. In this companion: the CAPABILITY_PROMPTS structure (scaffold.py), the template asset path (assets/template/START-HERE.md.tmpl), and the implementation work in Cluster 3.
- **ASCENT-project-POV** — concerns that live in a project produced by `python3 scaffold.py`. In this companion: the rendered prompt text the developer reads, the final START-HERE.md content the developer interacts with, the experience of Day 0 in a freshly-scaffolded project.

Most content in this companion is the *user-facing rendering* of content destined for ASCENT projects — so it's ASCENT-project-POV content authored from the Meta-repo-POV. That's the inherent dual-POV nature of capability prompts and START-HERE.md content: they're written in the meta-repo as templates (Meta-repo-POV at authoring time) but they exist to be consumed by developers in their ASCENT projects (ASCENT-project-POV at consumption time).

POV labels appear in this companion where they help disambiguate; otherwise the discipline stays silent (per plan §1.2.1's "where the POV is unambiguous, the discipline stays silent" principle).

A minor asymmetry inherited from the plan: "meta-repo" is anchored on the physical artifact (the repository itself). "ASCENT project" is anchored on the conceptual identity — the actual ASCENT project that the developer produced and is now working in.

### 1.5 What this document is NOT

- **Not the implementation.** The actual scaffold.py code lives in `scripts/scaffold.py` (Cluster 1). The actual START-HERE.md.tmpl template lives in `assets/template/START-HERE.md.tmpl` (Cluster 3). This document is the v1 source content those implementations read.
- **Not a contract.** v1 means refinable. Phase 7's first production project will be the first real reader of this content; their feedback drives refinement.
- **Not a static doc.** When refinements land, they append to this file (per discipline) as v1.1, v1.2, etc. The v1 baseline stays visible as durable record.

---

## §2 — has_ai_features

The first conditional capability. Enables the ascent-ai-evals skill when the developer's project involves LLM calls, prompt templates, or evaluation needs. When enabled, the scaffolder also generates `docs/ai/AI-CONFIG.md` as the canonical authority schema file for AI configuration.

The AI-CONFIG.md file is the developer's project's LLM and prompt configuration authority — not the framework's. ASCENT does not prescribe LLM choices, prompt content, or eval criteria; the developer chooses which LLM provider to use, what prompts to write, and what evaluation standards their project holds itself to. The schema file is the canonical record of those choices.

### 2.1 Prompt definition (v1)

The 9-field structure that scaffold.py's CAPABILITY_PROMPTS reads:

| Field | Value |
|---|---|
| `id` | `has_ai_features` |
| `question` | "Will this project have AI-augmented features (LLM calls, prompt templates, evaluation needs)?" |
| `examples` | See §2.2 |
| `default` | `False` |
| `enables_skill` | `["ascent-ai-evals"]` |
| `enables_schema` | `"docs/ai/AI-CONFIG.md"` |
| `skill_value` | See §2.3 |
| `why_it_helps` | See §2.4 |
| `runtime_signal` | See §2.5 |

### 2.2 Examples (rendered in the prompt)

- a feature that calls Claude, OpenAI, or other LLM APIs
- a prompt-engineering layer with multiple prompt templates
- a vector search system using embeddings
- an agent loop that orchestrates multiple LLM calls
- a chat interface with conversation history

If yes, this enables: `ascent-ai-evals` and generates `docs/ai/AI-CONFIG.md` as your AI configuration authority.

### 2.3 Skill value (what ascent-ai-evals does)

Validates eval scenario structure and prompt-test coverage. Reads `docs/ai/AI-CONFIG.md` as the canonical record of which prompts your project uses, what evaluation criteria they're held to, and what variant or A/B test configurations are active. Surfaces gaps when prompts exist without corresponding evals, when evals are stale relative to prompt changes, or when prompts diverge from what AI-CONFIG.md declares.

### 2.4 Why it helps

Prompt-based features fail in non-obvious ways. Small wording changes can shift model behavior dramatically — a prompt that worked at high accuracy may drop substantially after seemingly minor edits. Without eval scenarios that track prompt behavior over time, you discover these regressions in production, not before.

`ascent-ai-evals` catches the gap. The AI-CONFIG.md file is your project's canonical record of which prompts exist and what they're supposed to do; the skill checks that your actual codebase matches that record.

**When to enable:** This capability becomes useful when your project actually has AI features to audit — typically when prompt templates exist or LLM calls are wired up. Enabling it before prompts exist means the skill has nothing to evaluate; the report will be empty until prompt files exist. The framework's `enhance.py` script lets you toggle this capability later when AI features are introduced.

### 2.5 What you'll see at runtime (abstract template)

When you run `make qa-ai-evals` or it runs in CI, you'll get a coverage report:

```
ascent-ai-evals report
======================

Reading AI configuration: docs/ai/AI-CONFIG.md
Prompts declared in AI-CONFIG.md: <N>
Prompts found in codebase: <M>

Drift detected:

  Prompts in codebase missing from AI-CONFIG.md:
    prompts/<path>:<line>  not declared in AI-CONFIG.md
    
  Prompts in AI-CONFIG.md missing from codebase:
    declared prompt name  no corresponding file found

  Evals stale (prompt changed after last eval run):
    prompts/<path>  last eval run <date>; prompt changed <date>

  Evals missing for declared prompts:
    declared prompt name  no eval scenario found

Recommended action: reconcile drift between AI-CONFIG.md and codebase; write evals for newly declared prompts; re-run stale evals to verify behavior hasn't drifted.
```

### 2.5.1 Sample concrete output (illustrative — your data will differ)

**This is a sample output for illustration only.** The actual report you see depends on your project's real data, AI-CONFIG.md declarations, prompt files, and eval state. Below shows the structure and types of information the report contains, using fictional placeholder data.

```
ascent-ai-evals report
======================

Reading AI configuration: docs/ai/AI-CONFIG.md
Prompts declared in AI-CONFIG.md: 5
Prompts found in codebase: 4

Drift detected:

  Prompts in codebase missing from AI-CONFIG.md:
    prompts/extract-entities.md:1  not declared in AI-CONFIG.md
    
  Prompts in AI-CONFIG.md missing from codebase:
    "classify-intent-v2"  no corresponding file found

  Evals stale (prompt changed after last eval run):
    prompts/summarize-call.md  last eval run 2026-04-12;
                                prompt changed 2026-05-08

  Evals missing for declared prompts:
    "extract-entities"  no eval scenario found
    "summarize-call-v3"  no eval scenario found

Recommended action: declare extract-entities in AI-CONFIG.md or remove from codebase; create classify-intent-v2 prompt file or remove declaration; re-run summarize-call eval to verify behavior; write evals for extract-entities and summarize-call-v3.
```

### 2.6 Rendered prompt example

What the developer sees in their terminal:

```
Will this project have AI-augmented features (LLM calls, prompt 
templates, evaluation needs)?

  Examples: a feature that calls Claude/OpenAI APIs; a prompt-
  engineering layer with multiple templates; a vector search 
  system using embeddings; an agent loop orchestrating multiple 
  LLM calls; a chat interface with conversation history.

  If yes, this enables: ascent-ai-evals
  And generates: docs/ai/AI-CONFIG.md (your AI configuration 
  authority schema)

    What it does
      Validates eval scenario structure and prompt-test coverage. 
      Reads AI-CONFIG.md as the canonical record of your prompts 
      and what they're held to. Surfaces gaps when codebase 
      diverges from declared configuration.

    Why it helps
      Prompt-based features fail in non-obvious ways. AI-CONFIG.md 
      is your project's canonical record of which prompts exist 
      and what they're supposed to do; ascent-ai-evals catches 
      drift between that record and your codebase.

    What you'll see at runtime
      A coverage report comparing AI-CONFIG.md declarations 
      against your codebase, flagging missing prompts, stale 
      evals, and undeclared prompts.

has_ai_features? [n]: 
```

---

## §3 — has_design_system

The second conditional capability. Enables the ascent-design-system-audit skill when the developer's project uses formal design tokens, a shared component library, or a brand system. When enabled, the scaffolder also generates `docs/design/COLOR-SCHEMA.md` as the canonical authority schema file for design tokens and component conventions.

The COLOR-SCHEMA.md file is the developer's project's color design authority — not the framework's. ASCENT does not prescribe color design choices; the developer chooses their color palette, design tokens, and component library. The schema file is the canonical record of the developer's choices.

### 3.1 Prompt definition (v1)

The 9-field structure that scaffold.py's CAPABILITY_PROMPTS reads:

| Field | Value |
|---|---|
| `id` | `has_design_system` |
| `question` | "Will this project have a formal design system (design tokens, shared component library, brand system)?" |
| `examples` | See §3.2 |
| `default` | `False` |
| `enables_skill` | `["ascent-design-system-audit"]` |
| `enables_schema` | `"docs/design/COLOR-SCHEMA.md"` |
| `skill_value` | See §3.3 |
| `why_it_helps` | See §3.4 |
| `runtime_signal` | See §3.5 |

### 3.2 Examples (rendered in the prompt)

- Material-UI customization with tokens.css
- a corporate brand system with tokens.json
- Tailwind with custom config and shared utilities
- design-tokens.json workflow tied to Figma
- a shared component library in your monorepo with a separate package

If yes, this enables: `ascent-design-system-audit` and generates `docs/design/COLOR-SCHEMA.md` as your design authority schema.

### 3.3 Skill value (what ascent-design-system-audit does)

Audits design tokens and component usage for drift. Reads `docs/design/COLOR-SCHEMA.md` as the canonical record of what color tokens are defined, what their canonical names are, and which shared components are part of your library. Detects hardcoded color values where the schema expects token references, component instances that bypass the shared library, and token-naming inconsistencies that diverge from COLOR-SCHEMA.md's canonical names.

### 3.4 Why it helps

Design systems decay silently. A developer hardcodes a color value where the design system expects a token reference. The project's `docs/design/COLOR-SCHEMA.md` defines the canonical token names; the code should reference those tokens, not hardcode values. When the design team updates a token's value in COLOR-SCHEMA.md, the code referencing the token updates automatically; hardcoded values do not. The decay was invisible at the time of each individual edit.

`ascent-design-system-audit` catches drift early. The COLOR-SCHEMA.md file is your project's canonical record of what design vocabulary exists; the skill checks that your codebase honors that vocabulary rather than diverging from it.

**When to enable:** This capability becomes useful when your project actually has a design system to audit — typically when design tokens are declared, when a shared component library exists, or when brand colors and naming conventions are established. Enabling it before any design tokens exist means the skill has nothing to compare against; the report will be empty until COLOR-SCHEMA.md has populated content and the codebase has token references. The framework's `enhance.py` script lets you toggle this capability later when a design system emerges.

### 3.5 What you'll see at runtime (abstract template)

When you run `make qa-design-system-audit` or it runs in CI, you'll get a drift report:

```
ascent-design-system-audit report
=================================

Reading design schema: docs/design/COLOR-SCHEMA.md
Tokens defined: <N>
Components defined: <M>

Files scanned: <K>

Drift detected:

  Hardcoded values (should reference tokens per COLOR-SCHEMA.md):
    <file>:<line>  hardcoded value → expected token reference

  Components bypassing shared library (defined in COLOR-SCHEMA.md):
    <file>:<line>  inline component → import shared component

  Token references not in COLOR-SCHEMA.md:
    <token name>  used in <N> files (not defined in schema)
    Either: define in COLOR-SCHEMA.md, or refactor to a known token

Recommended action: refactor hardcoded values; replace inline 
components with shared ones; reconcile undefined token references.
```

### 3.5.1 Sample concrete output (illustrative — your data will differ)

**This is a sample output for illustration only.** The actual report you see depends on your project's real data, COLOR-SCHEMA.md declarations, codebase files, and design conventions.

```
ascent-design-system-audit report
=================================

Reading design schema: docs/design/COLOR-SCHEMA.md
Tokens defined: 32 (12 colors, 8 typography, 12 spacing)
Components defined: 18

Files scanned: 84

Drift detected:

  Hardcoded values (should reference tokens per COLOR-SCHEMA.md):
    components/Button.tsx:42  hex color value → expected --color-primary
    components/Card.tsx:18    hex color value → expected --color-danger
    pages/Dashboard.tsx:67    rgb() value → expected --color-primary

  Components bypassing shared library (defined in COLOR-SCHEMA.md):
    pages/Settings.tsx:24     inline <button> → import Button component

  Token references not in COLOR-SCHEMA.md:
    --color-undefined-primary  used in 3 files (not defined in schema)
    Either: define in COLOR-SCHEMA.md, or refactor to use --color-primary

Recommended action: refactor 3 hardcoded color references to use token references; replace 1 inline button with Button component; reconcile --color-undefined-primary (define in COLOR-SCHEMA.md or refactor to use --color-primary).
```

### 3.6 Rendered prompt example

```
Will this project have a formal design system (design tokens, 
shared component library, brand system)?

  Examples: Material-UI customization with tokens.css; a corporate 
  brand system with tokens.json; Tailwind with custom config and 
  shared utilities; design-tokens.json workflow tied to Figma; a 
  shared component library in a monorepo.

  If yes, this enables: ascent-design-system-audit
  And generates: docs/design/COLOR-SCHEMA.md (your design 
  authority schema)

    What it does
      Audits design tokens and component usage for drift. Reads 
      COLOR-SCHEMA.md as the canonical record of what color tokens 
      and components your project uses. Detects hardcoded values, 
      component bypasses, and token-naming inconsistencies.

    Why it helps
      Design systems decay silently. COLOR-SCHEMA.md is your 
      project's canonical record of design vocabulary; the skill 
      checks that your codebase honors that vocabulary rather 
      than diverging from it.

    What you'll see at runtime
      A drift report listing specific files and lines with 
      hardcoded values, component bypasses, and naming 
      inconsistencies — each with the canonical replacement from 
      COLOR-SCHEMA.md.

has_design_system? [n]: 
```

---

## §4 — has_personas

The third conditional capability. Enables the ascent-persona-coverage skill when the developer's project documents named personas. When enabled, the scaffolder also generates `docs/personas/PERSONAS.md` as the canonical authority schema file for persona definitions and entry points.

The PERSONAS.md file is the developer's project's persona definition authority — not the framework's. ASCENT does not prescribe personas; the developer defines their own personas based on their project's audience and needs. The framework's own personas (Architect, Developer, Operator, Contributor, Learner) are for *framework users*; the developer's project may have entirely different personas (Sales Rep, Compliance Officer, End User, etc.). The schema file is the canonical record of the developer's project-specific persona choices.

### 4.1 Prompt definition (v1)

The 9-field structure that scaffold.py's CAPABILITY_PROMPTS reads:

| Field | Value |
|---|---|
| `id` | `has_personas` |
| `question` | "Will this project document named personas (with their needs, entry points, and what they don't need)?" |
| `examples` | See §4.2 |
| `default` | `False` |
| `enables_skill` | `["ascent-persona-coverage"]` |
| `enables_schema` | `"docs/personas/PERSONAS.md"` |
| `skill_value` | See §4.3 |
| `why_it_helps` | See §4.4 |
| `runtime_signal` | See §4.5 |

### 4.2 Examples (rendered in the prompt)

- a SaaS product with documented personas (Admin, End User, Auditor) and persona-specific entry points
- a B2B platform with named customer roles (Sales, Operations, Finance) that each see different dashboards
- an internal tool with role-based documentation (Tier 1 Support, Tier 2 Support, Engineering)
- a public-facing product with persona-driven onboarding flows (First-time User, Returning User, Power User)
- documentation that explicitly addresses different reader audiences

If yes, this enables: `ascent-persona-coverage` and generates `docs/personas/PERSONAS.md` as your persona authority schema.

### 4.3 Skill value (what ascent-persona-coverage does)

Audits documentation and project structure for persona coverage gaps. Reads `docs/personas/PERSONAS.md` as the canonical record of your project's personas, their needs, their entry points, and what they don't need. Detects documentation that doesn't trace to a named persona (orphan docs), personas declared in PERSONAS.md without corresponding entry points, and entry-point references that don't match declared personas.

### 4.4 Why it helps

Persona-segmented documentation decays without discipline. New docs get added that target "the user" generically rather than a specific persona. Personas get added without their entry points being created. Entry-point references in code or links go stale when personas are renamed or retired. Without an audit, these gaps compound — documentation that was carefully persona-segmented at launch becomes generic noise over time.

`ascent-persona-coverage` catches the gap. The PERSONAS.md file is your project's canonical record of who reads your docs and what they need; the skill checks that your documentation honors that audience structure rather than drifting into generic addressing.

**When to enable:** This capability becomes useful when your project actually documents personas — typically when persona-specific entry-point docs exist, when persona-based onboarding flows are designed, or when documentation explicitly addresses different audiences. Enabling it before any persona-specific documentation exists means the skill has nothing to audit; the report will be empty until PERSONAS.md is populated and docs explicitly target named personas. The framework's `enhance.py` script lets you toggle this capability later when persona-segmented documentation emerges.

### 4.5 What you'll see at runtime (abstract template)

```
ascent-persona-coverage report
==============================

Reading persona authority: docs/personas/PERSONAS.md
Personas declared in PERSONAS.md: <N>
Entry points declared: <M>
Docs scanned: <K>

Coverage gaps:

  Personas in PERSONAS.md without entry points:
    <persona name>  no corresponding entry-point doc

  Entry points referenced but persona not declared:
    <doc path>  references "<persona>" not in PERSONAS.md

  Docs not traceable to a persona:
    <doc path>  no persona explicitly addressed

  Entry-point links broken:
    <doc path>  link to <target> is broken

Recommended action: create missing entry-point docs; reconcile references to undeclared personas; explicitly address each doc to a named persona or move to cross-persona section.
```

### 4.5.1 Sample concrete output (illustrative — your data will differ)

**This is a sample output for illustration only.**

```
ascent-persona-coverage report
==============================

Reading persona authority: docs/personas/PERSONAS.md
Personas declared in PERSONAS.md: 4 (End User, Admin, Auditor, Integration Partner)
Entry points declared: 4
Docs scanned: 47

Coverage gaps:

  Personas in PERSONAS.md without entry points:
    "Integration Partner"  no corresponding entry-point doc

  Entry points referenced but persona not declared:
    docs/user-guide/index.md  references "Power User" not in PERSONAS.md

  Docs not traceable to a persona:
    docs/internals/api-reference.md  no persona explicitly addressed
    docs/troubleshooting.md          no persona explicitly addressed

  Entry-point links broken:
    docs/admin/setup.md  link to /admin/onboarding is broken

Recommended action: create entry-point doc for Integration Partner; reconcile "Power User" reference (either add to PERSONAS.md or update reference); explicitly address api-reference.md to its intended persona (likely Integration Partner); fix broken link in admin/setup.md; explicitly address troubleshooting.md to its intended persona (likely Admin or End User).
```

### 4.6 Rendered prompt example

```
Will this project document named personas (with their needs, 
entry points, and what they don't need)?

  Examples: a SaaS product with documented personas (Admin, End 
  User, Auditor); a B2B platform with named customer roles; an 
  internal tool with role-based docs; a public product with 
  persona-driven onboarding; documentation addressing different 
  reader audiences.

  If yes, this enables: ascent-persona-coverage
  And generates: docs/personas/PERSONAS.md (your persona authority 
  schema)

    What it does
      Audits documentation and project structure for persona 
      coverage gaps. Reads PERSONAS.md as the canonical record 
      of who reads your docs. Detects orphan docs, missing entry 
      points, and broken persona references.

    Why it helps
      Persona-segmented documentation decays without discipline.
      PERSONAS.md is your project's canonical record of audience 
      structure; the skill checks that your documentation honors 
      that structure.

    What you'll see at runtime
      A coverage report flagging personas without entry points, 
      orphan docs, broken references — each with what to do to 
      restore coverage.

has_personas? [n]: 
```

---

## §5 — cloud_deployed

The fourth conditional capability. Enables the ascent-cost-posture skill when the developer's project deploys to cloud infrastructure with ongoing operational costs. When enabled, the scaffolder also generates `docs/infra/COST-SCHEMA.md` as the canonical authority schema file for cloud cost discipline.

The COST-SCHEMA.md file is the developer's project's cloud cost discipline authority — not the framework's. ASCENT does not prescribe specific cloud providers, resource configurations, or cost thresholds; the developer chooses where to deploy and what cost discipline to maintain. The schema file is the canonical record of the developer's cost-tracking choices.

### 5.1 Prompt definition (v1)

The 9-field structure that scaffold.py's CAPABILITY_PROMPTS reads:

| Field | Value |
|---|---|
| `id` | `cloud_deployed` |
| `question` | "Will this project deploy to cloud infrastructure with ongoing operational costs?" |
| `examples` | See §5.2 |
| `default` | `False` |
| `enables_skill` | `["ascent-cost-posture"]` |
| `enables_schema` | `"docs/infra/COST-SCHEMA.md"` |
| `skill_value` | See §5.3 |
| `why_it_helps` | See §5.4 |
| `runtime_signal` | See §5.5 |

### 5.2 Examples (rendered in the prompt)

- AWS Lambda functions with on-demand pricing
- GCP Cloud Run services with usage-based costs
- fly.io applications with persistent volumes
- Render or Railway deployments with continuous costs
- AWS ECS, EKS, or Fargate workloads
- Kubernetes hosted on managed services (EKS, GKE, AKS)
- Self-managed infrastructure on cloud VMs

Local-only Docker development or self-hosted-on-a-laptop deployments don't count.

If yes, this enables: `ascent-cost-posture` and generates `docs/infra/COST-SCHEMA.md` as your cloud cost discipline authority schema.

### 5.3 Skill value (what ascent-cost-posture does)

Audits Infrastructure-as-Code files and operational documentation for cost discipline. Reads `docs/infra/COST-SCHEMA.md` as the canonical record of declared cloud resources, expected cost ranges, retention policies, and sizing justifications. Detects resources deployed without declared cost expectations, retention policies that aren't documented, sandbox or testing resources that have outlived their purpose, and resource sizing that hasn't been justified in ADRs.

### 5.4 Why it helps

Cloud projects accumulate cost drift silently. Instances scale up under load and don't scale back. Logs pile up under unbounded retention. Sandbox resources outlive their purpose by months. Storage buckets grow unbounded because no retention policy was set. Each individual scaling event or test resource feels insignificant, but the cumulative effect is silent cost growth that surfaces only when someone notices the bill.

`ascent-cost-posture` catches drift early. The COST-SCHEMA.md file is your project's canonical record of what cloud resources exist and what cost discipline applies to them; the skill checks that your deployed infrastructure honors that discipline rather than silently diverging from it.

**When to enable:** This capability becomes useful when your project has actual cloud infrastructure to audit — typically when you're writing IaC files (Terraform, Pulumi, CloudFormation) or about to deploy. Enabling it before you have cloud resources to audit means the skill has nothing to compare against; the report will be empty until cloud resources exist. The framework's `enhance.py` script lets you toggle this capability later when cloud deployment becomes relevant.

### 5.5 What you'll see at runtime (abstract template)

```
ascent-cost-posture report
==========================

Reading cost schema: docs/infra/COST-SCHEMA.md
Resources declared in COST-SCHEMA.md: <N>
IaC files scanned: <K>

Posture assessment:

  Resources without declared retention policies:
    <resource type>:<resource name>  retention not in COST-SCHEMA.md

  Resources without sizing justification:
    <resource type>:<resource name>  no sizing ADR referenced

  Sandbox or testing resources past expected lifetime:
    <resource type>:<resource name>  expected end-of-life <date>; currently active

  Undeclared resources in IaC:
    <resource type>:<resource name>  not in COST-SCHEMA.md

Cumulative stance: <Strong | Partial | Moderate | Weak>

Recommended action: document retention for undocumented resources; write sizing ADRs for unjustified resources; retire stale sandbox resources; declare undeclared resources in COST-SCHEMA.md.
```

### 5.5.1 Sample concrete output (illustrative — your data will differ)

**This is a sample output for illustration only.**

```
ascent-cost-posture report
==========================

Reading cost schema: docs/infra/COST-SCHEMA.md
Resources declared in COST-SCHEMA.md: 14
IaC files scanned: 8 (terraform/)

Posture assessment:

  Resources without declared retention policies:
    s3:logs-bucket                retention not in COST-SCHEMA.md
    cloudwatch:debug-logs         retention not in COST-SCHEMA.md
    
  Resources without sizing justification:
    rds:primary-db                no sizing ADR referenced
    
  Sandbox or testing resources past expected lifetime:
    ec2:test-instance-jun2025     expected end-of-life 2025-09-30;
                                    currently active

  Undeclared resources in IaC:
    lambda:webhook-processor      not in COST-SCHEMA.md
    elasticache:session-cache     not in COST-SCHEMA.md

Cumulative stance: Moderate
  (2 retention gaps, 1 sizing gap, 1 stale sandbox, 2 undeclared resources)

Recommended action: document retention policy for s3:logs-bucket and cloudwatch:debug-logs in COST-SCHEMA.md; write or reference sizing ADR for rds:primary-db; retire ec2:test-instance-jun2025 (11 months past expected end-of-life); declare lambda:webhook-processor and elasticache:session-cache in COST-SCHEMA.md.
```

### 5.6 Rendered prompt example

```
Will this project deploy to cloud infrastructure with ongoing 
operational costs?

  Examples: AWS Lambda, GCP Cloud Run, fly.io, Render, AWS ECS, 
  Kubernetes hosted on EKS/GKE/AKS, self-managed infrastructure 
  on cloud VMs. Local-only Docker development or self-hosted-on-
  a-laptop deployments don't count.

  Note: This setting is for projects with active cloud 
  infrastructure. If you're planning cloud deployment but haven't 
  deployed yet, set this to no for now. Toggle to yes via 
  `python3 enhance.py` when you actually have cloud resources to 
  audit (typically when your first IaC files are written or your 
  first cloud deploy is imminent).

  For service equivalents across providers, see the framework's 
  cloud-component-mapping.md reference module.

  If yes, this enables: ascent-cost-posture
  And generates: docs/infra/COST-SCHEMA.md (your cloud cost 
  discipline authority schema)

    What it does
      Audits Infrastructure-as-Code files and operational 
      documentation for cost discipline. Reads COST-SCHEMA.md 
      as canonical record of declared resources, retention 
      policies, and sizing. Detects resources without retention, 
      stale sandbox resources, undeclared infrastructure.

    Why it helps
      Cloud projects accumulate cost drift silently — instances 
      scale up and don't scale back; logs pile up under unbounded 
      retention; sandbox resources outlive their purpose. 
      COST-SCHEMA.md is your project's canonical record of cost 
      discipline; the skill catches drift before your bill does.

    What you'll see at runtime
      A posture report with point-in-time drift findings plus a 
      cumulative stance rating (Strong / Partial / Moderate / 
      Weak) across your declared resources.

cloud_deployed? [n]: 
```

---

## §6 — production_critical

The fifth conditional capability. Enables both ascent-security-audit AND ascent-sec-posture when the developer's project will be deployed to production with security-critical concerns. These two skills are enumerate/summarize siblings per patterns.md — they travel together. When enabled, the scaffolder also generates `docs/security/SECURITY-BASELINE.md` as the canonical authority schema file for security baselines.

The SECURITY-BASELINE.md file is the developer's project's security baseline authority — not the framework's. ASCENT does not prescribe security policies, threat models, or specific controls; the developer defines the security posture appropriate for their project. The schema file is the canonical record of the developer's security baseline choices.

### 6.1 Prompt definition (v1)

The 9-field structure that scaffold.py's CAPABILITY_PROMPTS reads:

| Field | Value |
|---|---|
| `id` | `production_critical` |
| `question` | "Will this project be deployed to production with security-critical concerns?" |
| `examples` | See §6.2 |
| `default` | `False` |
| `enables_skill` | `["ascent-security-audit", "ascent-sec-posture"]` |
| `enables_schema` | `"docs/security/SECURITY-BASELINE.md"` |
| `skill_value` | See §6.3 |
| `why_it_helps` | See §6.4 |
| `runtime_signal` | See §6.5 |

Note: This capability enables two skills as enumerate/summarize siblings per patterns.md. `ascent-security-audit` enumerates point-in-time security findings; `ascent-sec-posture` summarizes the overall security stance. They share the same authority schema file (SECURITY-BASELINE.md) and travel together — when production_critical is true, both ship.

### 6.2 Examples (rendered in the prompt)

- a customer-facing SaaS handling personal data
- a B2B platform processing financial transactions
- a healthcare application subject to HIPAA or similar regulations
- an internal tool with authentication and authorization
- a system handling payment card data (PCI compliance)
- any service exposing public APIs that could be exploited

For projects in early development, prototyping, or research where security audit isn't yet a concern, set this to false. You can toggle to true via `python3 enhance.py` when security audit becomes relevant.

If yes, this enables: `ascent-security-audit` AND `ascent-sec-posture` (enumerate/summarize sibling pair) and generates `docs/security/SECURITY-BASELINE.md` as your security baseline authority schema.

### 6.3 Skill value (what the two skills do)

**ascent-security-audit (enumerate):**

Performs point-in-time security audit across the project. Reads `docs/security/SECURITY-BASELINE.md` as the canonical record of declared security baselines, threat assumptions, and specific controls. Detects gaps between declared baselines and actual implementation: missing security headers, weak credential practices, environment variable exposure, unaudited dependencies, overly permissive access patterns, and other point-in-time security findings.

The skill enumerates findings — specific issues, with file paths, line numbers, and remediation guidance.

**ascent-sec-posture (summarize):**

Provides a summary stance assessment of the project's overall security posture. Reads the same SECURITY-BASELINE.md as authority. Combines findings from ascent-security-audit with project-state signals (presence of security tooling, frequency of audits, age of declared baselines) to produce a cumulative stance: Strong / Partial / Moderate / Weak.

The skill summarizes — overall position, trend, and recommended focus areas — rather than enumerating individual findings.

### 6.4 Why it helps

Security debt accumulates silently. A new endpoint is added without proper authentication. An environment variable is deployed without rotation policy. A dependency receives a CVE that nobody notices because audits aren't running. Each individual oversight feels small, but the cumulative effect is silent security degradation that surfaces only during an incident.

**When to enable:** This capability becomes useful when your project is about to ship to production, when you're handling user data or financial transactions, or when external stakeholders (customers, auditors, regulators) require demonstrated security posture. Enabling it before you have production code or deployed infrastructure means the skills have limited surface to audit — both will run cleanly but won't find much. The framework's `enhance.py` script lets you toggle this capability when the time is right.

The two skills together provide both depth and breadth. `ascent-security-audit` catches specific issues; `ascent-sec-posture` ensures you know the overall security health of the project. The SECURITY-BASELINE.md file is your project's canonical record of what security baselines apply; the skills check that your actual posture honors those baselines.

### 6.5 What you'll see at runtime (abstract template)

When you run `make qa-security-audit` or `make qa-sec-posture`, you get two distinct outputs:

**ascent-security-audit (enumerate):**

```
ascent-security-audit report
============================

Reading security baseline: docs/security/SECURITY-BASELINE.md
Baselines declared: <N>
Files scanned: <K>

Point-in-time findings:

  Authentication and authorization:
    <file>:<line>  <finding> (severity: <H/M/L>)

  Environment and secrets:
    <file>:<line>  <finding> (severity: <H/M/L>)

  Headers and response security:
    <file>:<line>  <finding> (severity: <H/M/L>)

  Dependencies and CVEs:
    <package>  <finding> (severity: <H/M/L>)

  Other:
    <file>:<line>  <finding> (severity: <H/M/L>)

Recommended action: address high-severity findings first; review medium and low severity findings against SECURITY-BASELINE.md to determine if they're in scope.
```

**ascent-sec-posture (summarize):**

```
ascent-sec-posture report
=========================

Reading security baseline: docs/security/SECURITY-BASELINE.md
Last security-audit run: <date>
Baselines declared: <N>

Cumulative stance: <Strong | Partial | Moderate | Weak>

Stance breakdown:
  Authentication: <stance with brief justification>
  Authorization: <stance with brief justification>
  Secrets management: <stance with brief justification>
  Headers and response: <stance with brief justification>
  Dependencies: <stance with brief justification>

Trend: <Improving | Steady | Degrading>
  (based on comparison with previous run)

Focus areas: <one or two recommended priorities>

For specific findings, run ascent-security-audit.
```

### 6.5.1 Sample concrete output (illustrative — your data will differ)

**These are sample outputs for illustration only.**

**ascent-security-audit:**

```
ascent-security-audit report
============================

Reading security baseline: docs/security/SECURITY-BASELINE.md
Baselines declared: 12 (8 mandatory, 4 conditional)
Files scanned: 142

Point-in-time findings:

  Authentication and authorization:
    routes/admin.js:14    missing auth middleware on /admin route (severity: H)
    routes/user.js:42     authorization check after data fetch (race condition risk; severity: M)

  Environment and secrets:
    src/config.js:18      .env file referenced but not in .gitignore (severity: H)
    src/db.js:8           DATABASE_URL hardcoded fallback string (severity: M)

  Headers and response security:
    middleware/cors.js:5  CORS wildcard origin in production code (severity: H)
    routes/api.js:33      missing rate-limit on public endpoint (severity: M)

  Dependencies and CVEs:
    express@4.17.1        known CVE-2024-XXXX (severity: M)
    lodash@4.17.20        known CVE-2025-XXXX (severity: L)

Recommended action: address 3 high-severity findings immediately (admin route auth, .env exposure, CORS wildcard); schedule remediation for 4 medium findings; update lodash to latest patch version for low-severity CVE.
```

**ascent-sec-posture:**

```
ascent-sec-posture report
=========================

Reading security baseline: docs/security/SECURITY-BASELINE.md
Last security-audit run: 2026-05-18
Baselines declared: 12 (8 mandatory, 4 conditional)

Cumulative stance: Moderate

Stance breakdown:
  Authentication:    Partial (admin route gap; otherwise compliant)
  Authorization:     Partial (race condition pattern detected)
  Secrets management: Weak (.env exposure risk; hardcoded fallback)
  Headers/response:  Weak (CORS wildcard; rate-limit gaps)
  Dependencies:      Partial (2 known CVEs awaiting remediation)

Trend: Degrading
  (3 new findings since previous run; 2 unresolved from last run)

Focus areas:
  1. Secrets management — close .env exposure risk before next deploy
  2. Headers/response — eliminate CORS wildcard from production code

For specific findings, run ascent-security-audit.
```

### 6.6 Rendered prompt example

```
Will this project be deployed to production with security-critical 
concerns?

  Examples: a customer-facing SaaS handling personal data; a B2B 
  platform processing transactions; a healthcare app subject to 
  HIPAA; an internal tool with auth; a system handling payment 
  data; any service exposing public APIs.

  Note: For projects in early development, prototyping, or research 
  where security audit isn't yet a concern, set this to no. Toggle 
  to yes via `python3 enhance.py` when security audit becomes 
  relevant (typically before first production deploy or when 
  handling user data).

  If yes, this enables: ascent-security-audit AND ascent-sec-posture
  And generates: docs/security/SECURITY-BASELINE.md (your security 
  baseline authority schema)

    What it does
      Two skills working together. ascent-security-audit enumerates 
      point-in-time security findings (specific issues, file paths, 
      severities). ascent-sec-posture summarizes the overall stance 
      (Strong / Partial / Moderate / Weak) across security dimensions.
      Both read SECURITY-BASELINE.md as the canonical record of 
      security baselines.

    Why it helps
      Security debt accumulates silently. SECURITY-BASELINE.md is 
      your project's canonical record of what security baselines 
      apply; the skills check that your actual posture honors 
      those baselines. The two skills together give you both depth 
      (specific issues) and breadth (overall stance).

    What you'll see at runtime
      Two reports: an enumeration of point-in-time findings with 
      severities and remediation guidance, plus a stance assessment 
      with trend analysis and recommended focus areas.

production_critical? [n]: 
```

---

## §7 — track_vitality

The sixth and final conditional capability. Enables the ascent-vitality skill when the developer's project benefits from ongoing activity and momentum tracking. When enabled, the scaffolder also generates `docs/delivery/VITALITY-METRICS.md` as the canonical authority schema file for project vitality signals.

The VITALITY-METRICS.md file is the developer's project's activity and momentum tracking authority — not the framework's. ASCENT does not prescribe specific metrics, cadences, or thresholds; the developer chooses which signals matter for their project's vitality. The schema file is the canonical record of the developer's vitality-tracking choices.

### 7.1 Prompt definition (v1)

The 9-field structure that scaffold.py's CAPABILITY_PROMPTS reads:

| Field | Value |
|---|---|
| `id` | `track_vitality` |
| `question` | "Will this project benefit from tracking ongoing activity and momentum signals (commits, work-item churn, CHANGELOG freshness)?" |
| `examples` | See §7.2 |
| `default` | `False` |
| `enables_skill` | `["ascent-vitality"]` |
| `enables_schema` | `"docs/delivery/VITALITY-METRICS.md"` |
| `skill_value` | See §7.3 |
| `why_it_helps` | See §7.4 |
| `runtime_signal` | See §7.5 |

### 7.2 Examples (rendered in the prompt)

- a long-running product where team capacity and momentum matter over months or years
- an open-source project where contributor activity signals project health to potential adopters
- a maintained internal tool where staleness indicates abandonment risk
- a startup product where shipping velocity is a leading indicator of company health
- a research codebase where commit cadence signals active investigation vs. dormancy
- any project where "is this still alive?" is a real question someone might ask

For one-off projects, scripts, or short-term experiments where vitality tracking adds noise rather than signal, set this to false. You can toggle to true via `python3 enhance.py` when the project's duration or stakes change.

If yes, this enables: `ascent-vitality` and generates `docs/delivery/VITALITY-METRICS.md` as your activity-and-momentum tracking authority schema.

### 7.3 Skill value (what ascent-vitality does)

Tracks project vitality signals over time. Reads `docs/delivery/VITALITY-METRICS.md` as the canonical record of which signals the project tracks, their target cadences, and their staleness thresholds. Computes current vitality across declared signals: commit frequency, CHANGELOG entry freshness, work-item churn (opened vs. closed), dependency update cadence, and other signals the project declares as meaningful.

The skill provides a vitality assessment — Active / Steady / Slowing / Dormant — based on how current measurements compare against the project's declared baselines in VITALITY-METRICS.md.

### 7.4 Why it helps

Project vitality is hard to assess at a glance. A repo with 500 stars and no commits in 18 months looks vibrant on the homepage but is functionally abandoned. A repo with 50 stars and weekly commits is alive in ways that matter. Without explicit tracking, vitality assessment relies on subjective impressions — "feels active" or "feels stale."

**When to enable:** This capability becomes useful when your project has enough history to track trends — typically after a few months of active development. Enabling it on Day 0 of a fresh project means the skill has limited history to assess; vitality signals start meaningful around the 30-90 day mark. The framework's `enhance.py` script lets you toggle this capability when enough project history accumulates.

`ascent-vitality` makes vitality assessment mechanical. The VITALITY-METRICS.md file is your project's canonical record of what vitality means for this project specifically; the skill checks current signals against that definition rather than against generic baselines.

### 7.5 What you'll see at runtime (abstract template)

```
ascent-vitality report
======================

Reading vitality metrics: docs/delivery/VITALITY-METRICS.md
Signals tracked: <N>
Measurement window: <window>

Current vitality: <Active | Steady | Slowing | Dormant>

Signal breakdown:
  Commit frequency:      <signal status with brief data>
  CHANGELOG freshness:   <signal status with brief data>
  Work-item churn:       <signal status with brief data>
  Dependency updates:    <signal status with brief data>
  <other declared signal>: <signal status with brief data>

Trend: <Improving | Steady | Slowing | Dormant>
  (based on comparison with prior measurement)

Threshold breaches: <count>
  <signal>: current <value> below threshold <value>

Recommended action: <one or two recommended focus areas based on breaches and trends, or "vitality is healthy across declared signals">
```

### 7.5.1 Sample concrete output (illustrative — your data will differ)

**This is a sample output for illustration only.**

```
ascent-vitality report
======================

Reading vitality metrics: docs/delivery/VITALITY-METRICS.md
Signals tracked: 5
Measurement window: rolling 30 days

Current vitality: Slowing

Signal breakdown:
  Commit frequency:      3 commits/week (threshold: 5+/week)
                          Status: below threshold
  CHANGELOG freshness:   last entry 22 days ago (threshold: 14 days)
                          Status: stale
  Work-item churn:       4 opened, 1 closed (ratio threshold: 1:1)
                          Status: opening faster than closing
  Dependency updates:    last update 8 days ago (threshold: 14 days)
                          Status: healthy
  ADR cadence:           last ADR 47 days ago (threshold: monthly)
                          Status: due for review

Trend: Slowing
  (commit frequency dropped from 6.5/week to 3/week over last 30 days)

Threshold breaches: 4
  Commit frequency below threshold
  CHANGELOG entry stale
  Work-item churn imbalanced
  ADR cadence overdue

Recommended action: address work-item backlog (closing rate has fallen behind opening rate); refresh CHANGELOG with recent work; schedule ADR review cycle for accumulated decisions.
```

### 7.6 Rendered prompt example

```
Will this project benefit from tracking ongoing activity and 
momentum signals (commits, work-item churn, CHANGELOG freshness)?

  Examples: a long-running product where team capacity matters; 
  an open-source project where contributor activity signals health; 
  a maintained internal tool where staleness indicates abandonment 
  risk; a startup product where shipping velocity is a leading 
  indicator; a research codebase where commit cadence matters; any 
  project where "is this still alive?" is a real question.

  Note: For one-off projects, scripts, or short-term experiments 
  where vitality tracking adds noise rather than signal, set this 
  to no. Toggle to yes via `python3 enhance.py` when the project's 
  duration or stakes change. Vitality signals start meaningful 
  around the 30-90 day mark of active development.

  If yes, this enables: ascent-vitality
  And generates: docs/delivery/VITALITY-METRICS.md (your activity-
  and-momentum tracking authority schema)

    What it does
      Tracks project vitality signals over time. Reads 
      VITALITY-METRICS.md as the canonical record of signals, 
      cadences, and thresholds. Computes current vitality 
      (Active / Steady / Slowing / Dormant) based on commit 
      frequency, CHANGELOG freshness, work-item churn, and other 
      declared signals.

    Why it helps
      Project vitality is hard to assess at a glance. 
      VITALITY-METRICS.md is your project's canonical record of 
      what vitality means for this project; the skill checks 
      current signals against that definition rather than against 
      generic baselines.

    What you'll see at runtime
      A vitality report with current state, signal breakdown, 
      trend analysis, threshold breaches, and recommended focus 
      areas based on what the project declared as meaningful.

track_vitality? [n]: 
```

---

## §8 — START-HERE.md v1 content

The v1 content of `assets/template/START-HERE.md.tmpl`. This file ships at the root of every ASCENT project (`./<project-name>/START-HERE.md`) and is the developer's first substantive contact with their scaffolded project.

The voice and structure here are direct, second-person, and action-oriented — matching §1.3's voice principles. The document tells the developer what was scaffolded, what capabilities are active, what to do first, and how to proceed from zero to customer-ready deployment. It does NOT include a "capabilities you did not enable" section — keeping the document forward-looking rather than focused on paths not taken.

### 8.1 Document structure

START-HERE.md has 7 sections:

1. Welcome and orientation
2. What was scaffolded (universal foundation)
3. Capabilities you enabled (conditional, populated based on `.ascent-scaffold.yaml`)
4. Your first 30 minutes (action-oriented onboarding)
5. Building toward production (forward-looking guidance with industry-standard product phases)
6. Where to learn more (links to deeper documentation)
7. When you hit blockers (troubleshooting and support)

Sections 2, 4, 5, 6, 7 are universal — every ASCENT project sees the same content (modulo project name substitution).

Section 3 is conditional — the content varies based on which capabilities are enabled in `.ascent-scaffold.yaml`. Each enabled capability gets a paragraph describing what was added and what the developer can do with it.

### 8.2 START-HERE.md v1 template content

Below is the full v1 content of `assets/template/START-HERE.md.tmpl`. Placeholders use `<<PROJECT_NAME>>` and similar conventions per the existing template-asset substitution mechanism (Phase 2 established these). Conditional sections use `[If capability: true]` ... `[End of conditional section]` markers; Cluster 3 implements the actual templating syntax.

```markdown
# Welcome to <<PROJECT_NAME>>

Your ASCENT project is scaffolded and ready. This document is your zero-to-hero guide — what you got, what's available, and how to build toward customer-ready deployment.

ASCENT projects ship with an engineering framework that supports confident AI-assisted software development. The framework is opinionated about discipline (declared-before-use, audit-drift, session-resumption) but not about your specific design, prompt, persona, or security choices. You make those decisions; the framework records them as canonical state and audits them over time.

## What was scaffolded

Your project ships with the following on Day 0:

**Foundation (universal across all ASCENT projects):**

- 21 baseline skills under `.claude/skills/` for code audit, authoring assistance, lifecycle management, and quality gates
- Backend (Express + SQLite-WAL) + Frontend (React + Vite) + nginx reverse proxy, containerized via Docker Compose
- SDLC-sectioned make vocabulary (run `make help` to explore the operator vocabulary)
- Session resumption protocol — `make session-resume` verifies Claude can ground its responses in your project's state
- 7 architectural decision records (ADRs) capturing baseline framework decisions, plus a template for your project-specific ADRs
- 16 framework principles enforced via project validators (qa-skill-frontmatter, qa-links, qa-template-placeholders, qa-claimed-vs-actual)
- INTENT-MAP.md routing developer intents to the right skill
- CLAUDE.md as your project's entry-point document for Claude

**Project-level configuration:**

- `.ascent-meta.json` — your project's identity and current phase
- `.ascent-scaffold.yaml` — capability state and framework version
- README.md, CHANGELOG.md, ROADMAP.md — project documentation shells you populate as the project evolves
- Makefile + `make/*.mk` files — the operator vocabulary
- docker-compose.yml — your development stack

## Capabilities you enabled

[CONDITIONAL SECTION — populated based on `.ascent-scaffold.yaml`. The scaffolder generates only the paragraphs for capabilities set to `true`. If no capabilities are enabled, this entire section is omitted.]

[If has_ai_features: true]

**AI-augmented features (`has_ai_features`)**

You enabled this because your project involves LLM calls, prompt templates, or evaluation needs. The framework added:

- `ascent-ai-evals` skill at `.claude/skills/ascent-ai-evals/` for prompt-test coverage auditing
- `docs/ai/AI-CONFIG.md` as your LLM and prompt configuration authority — declare your prompts, eval criteria, and model choices here as your project grows

Run `make qa-ai-evals` whenever you add or change prompts to catch coverage gaps.

[If has_design_system: true]

**Formal design system (`has_design_system`)**

You enabled this because your project uses design tokens, a shared component library, or a brand system. The framework added:

- `ascent-design-system-audit` skill at `.claude/skills/ascent-design-system-audit/` for design-token drift detection
- `docs/design/COLOR-SCHEMA.md` as your color design authority — declare your design tokens, shared components, and naming conventions here

Run `make qa-design-system-audit` to catch hardcoded values, component bypasses, and token-naming inconsistencies.

[If has_personas: true]

**Named personas (`has_personas`)**

You enabled this because your project documents named personas with distinct needs and entry points. The framework added:

- `ascent-persona-coverage` skill at `.claude/skills/ascent-persona-coverage/` for documentation persona-segmentation auditing
- `docs/personas/PERSONAS.md` as your persona definition authority — declare your personas, their needs, and their entry points here

Run `make qa-persona-coverage` to catch orphan docs, missing entry points, and broken persona references.

[If cloud_deployed: true]

**Cloud deployment (`cloud_deployed`)**

You enabled this because your project deploys to cloud infrastructure with ongoing operational costs. The framework added:

- `ascent-cost-posture` skill at `.claude/skills/ascent-cost-posture/` for cloud cost discipline auditing
- `docs/infra/COST-SCHEMA.md` as your cloud cost discipline authority — declare your resources, retention policies, and sizing justifications here

Run `make qa-cost-posture` per infrastructure change to catch cost drift, undocumented retention, and stale sandbox resources.

For service equivalents across providers (AWS / GCP / Azure / edge platforms like fly.io and Cloudflare), see the framework's `cloud-component-mapping.md` reference.

[If production_critical: true]

**Production security (`production_critical`)**

You enabled this because your project will be deployed to production with security-critical concerns. The framework added:

- `ascent-security-audit` skill at `.claude/skills/ascent-security-audit/` for point-in-time security audit
- `ascent-sec-posture` skill at `.claude/skills/ascent-sec-posture/` for cumulative security stance assessment
- `docs/security/SECURITY-BASELINE.md` as your security baseline authority — declare your security baselines, threat assumptions, and specific controls here

Run `make qa-security-audit` for point-in-time findings; run `make qa-sec-posture` for stance assessment. The two skills are enumerate/summarize siblings; they travel together and share the same authority schema.

[If track_vitality: true]

**Activity and momentum tracking (`track_vitality`)**

You enabled this because your project benefits from tracking ongoing vitality signals. The framework added:

- `ascent-vitality` skill at `.claude/skills/ascent-vitality/` for vitality signal computation and assessment
- `docs/delivery/VITALITY-METRICS.md` as your activity-and-momentum tracking authority — declare your signals, cadences, and thresholds here

Run `make qa-vitality` to assess current vitality (Active / Steady / Slowing / Dormant) and trend analysis.

[End of conditional section]

## Your first 30 minutes

1. **Boot the stack:**

   ```
   make dev-up
   ```

   Verify: http://localhost:3001/healthz responds with 200 OK.

2. **Verify the scaffold integrity:**

   ```
   make qa
   make test-skills
   ```

   All validators and tests should pass on Day 0. If anything fails, that's a scaffold bug — see "When you hit blockers" below.

3. **Open Claude Code in this project.** Claude will read `.ascent-meta.json`, `docs/delivery/session-state.md` (empty for fresh scaffold; protocol announces this), and `CLAUDE.md` (your project's entry-point with the skill catalog). Try asking:

   > "What should I work on first?"

   Claude will respond with confidence and grounding, citing your project's actual state.

4. **Make your first feature decision.** Run:

   ```
   ascent-feature-intake
   ```

   Or just describe a feature to Claude — the skill auto-engages when you discuss new features.

5. **Populate the authority schema files** for any capabilities you enabled. Each schema file ships with a minimal v1 template containing structured sections and TODO markers. As your project grows, declare your domain knowledge in the appropriate schema file before implementing in code (the "schema-leads-codebase" discipline).

## Building toward production

Your project follows a standard product lifecycle. As you build, your project progresses through six industry-recognized phases:

1. **Validation / Discovery** — confirming the project idea is worth building; user research; early prototyping. The framework provides the scaffolded foundation; you focus on understanding the problem and validating the solution.

2. **Development / Build** — implementing the project; first end-to-end feature working; basic observability wired up. This is where most of your day-to-day development happens. Run `make dev-up` to boot the stack; use `ascent-feature-intake` for new features.

3. **Beta / Early Access** — feature-complete enough for early users; full test coverage; deployment workflow established. At this phase, run `ascent-release-readiness` to verify your project meets your declared release criteria.

4. **General Availability (GA) / Launch** — production-ready, secure, monitored, on-call ready. Your conditional skills become especially load-bearing at this phase. If you enabled `production_critical`, run `make qa-security-audit` and `make qa-sec-posture` before launch. If you enabled `cloud_deployed`, run `make qa-cost-posture` to verify cost discipline.

5. **Growth / Scale** — optimization, multi-region deployment, cost discipline, expanding user base. Your conditional skills help maintain discipline at scale — drift catches grow more important as the project does.

6. **Maturity / Steady State** — ongoing maintenance, stable release cadence, sustaining engineering. The framework's validators run as part of your regular discipline; vitality tracking (if enabled) helps you watch for warning signs.

**Note: framework phases vs. project phases.** The ASCENT framework itself has its own development phases (Phase 0 through Phase 7) describing how the framework was built. Those are framework development phases and do NOT apply to your project's lifecycle. Your project moves through the industry-standard product phases above independently. Don't confuse "Phase 0 of ASCENT framework" with "Phase 1 of your project."

## Where to learn more

- **`README.md`** — full project documentation (organized by persona: Architect, Developer, Operator, Contributor, Learner)
- **`docs/framework/PRINCIPLES.md`** — the 16 invariants your project respects
- **`.claude/skills/INTENT-MAP.md`** — all skills with their intent classifications and cadences
- **`CHANGELOG.md`** — your project's release history (starts here)
- **ASCENT framework on GitHub** — `github.com/lloydbrian/lloydbriantech-ascent` — framework documentation, reference modules, and issue tracking

## When you hit blockers

- **`make session-resume`** — displays the contents of session-state.md and working-memory.md exactly as Claude reads them. Use this to verify Claude is grounding in real state, not confabulating.
- **`make qa-scaffold-integrity`** — runs the optional structural audit of your scaffold (audit-only; not part of default qa). Use after significant manual edits or before release.
- **`make help`** — explores the operator vocabulary; shows all available make targets organized by SDLC section.
- **Framework issues** — open an issue at github.com/lloydbrian/lloydbriantech-ascent if you find a framework bug, missing feature, or documentation gap.

---

Welcome aboard. Build well.
```

### 8.3 Notes on the v1 template

The template above uses several substitution and conditional mechanisms:

- **`<<PROJECT_NAME>>`** — placeholder for the project's name, substituted by scaffold.py at generation time (existing template-asset convention from Phase 2)
- **`[If <capability>: true]` and `[End of conditional section]`** — conditional markers showing where scaffold.py renders or omits sections based on `.ascent-scaffold.yaml` state
- **Specific skill names and file paths** — these are durable framework knowledge and ship as-is

The actual implementation in Cluster 3 uses scaffold.py's templating logic to render or omit conditional sections. The placeholders `[If ...]` and `[End of conditional section]` are illustrative of structure; the actual template syntax (e.g., Jinja-style, Python f-string style, or custom substitution) is implementation detail decided during Cluster 3.

### 8.4 Voice principles applied in this template

- **Concrete over abstract:** specific file paths (`docs/ai/AI-CONFIG.md`), specific commands (`make qa-ai-evals`), specific examples
- **Second-person:** "Your project ships with...", "Run `make dev-up`...", "Try asking..."
- **Skill-value framing:** each enabled capability mentions what the skill does for the developer, not just what it is
- **No "capabilities you did not enable" section:** the document is forward-looking; paths not taken aren't surfaced as reminders
- **Action-oriented:** "Your first 30 minutes" tells the developer what to do, not just what exists
- **Closing line:** "Welcome aboard. Build well." sets a tone of partnership rather than a sterile sign-off

### 8.5 What this v1 captures vs. what's deferred

**v1 captures:**

- Universal foundation explanation
- Conditional capability sections for all 6 capabilities
- Action-oriented first-30-minutes guidance
- Industry-standard 6-phase product lifecycle framing
- Cross-references to framework documentation
- Troubleshooting and support guidance

**Deferred to v1.x or later refinement:**

- Refinement of conditional section copy based on Phase 7's first production project feedback (per PHASE-4-PLAN.md §1.4)
- Persona-specific entry points (the current template addresses the developer generically; future versions may segment by persona)
- Multi-language support (the v1 template is English; localization is a future concern)
- Project-type-specific guidance (e.g., different first-30-minutes for AI-augmented projects vs. CLI tools)

Refinements land via plan-amendment discipline per §6.3 — appended to this companion document, never rewriting the v1 text.

---

## §9 — Schema file lifecycle discipline

Each conditional capability that is enabled in an ASCENT project generates a corresponding authority schema file (per PHASE-4-PLAN.md §5.1's table). The schema file is the canonical record of the project's domain knowledge for that concern; the corresponding conditional skill audits against it as authority.

This section describes the lifecycle discipline that applies to all schema files generically. Per-capability sections (§2-§7) reference this section rather than duplicating discipline content.

### 9.1 The six schema files

For quick reference, the schema files generated by Phase 4 when their corresponding capability is enabled:

| Capability | Schema file | What it records |
|---|---|---|
| has_ai_features | `docs/ai/AI-CONFIG.md` | LLM prompts, eval criteria, model configurations |
| has_design_system | `docs/design/COLOR-SCHEMA.md` | Design tokens, shared components, naming conventions |
| has_personas | `docs/personas/PERSONAS.md` | Named personas, their needs, their entry points |
| cloud_deployed | `docs/infra/COST-SCHEMA.md` | Cloud resources, expected costs, retention policies |
| production_critical | `docs/security/SECURITY-BASELINE.md` | Security baselines, threat assumptions, specific controls |
| track_vitality | `docs/delivery/VITALITY-METRICS.md` | Activity signals, project health indicators, cadences |

The skill that reads each schema file is named in §5.1 of PHASE-4-PLAN.md.

### 9.2 The three lifecycle moments

Three lifecycle moments matter for every schema file:

**Moment 1 — At scaffold time (Day 0)**

scaffold.py generates the schema file as a minimal v1 template. The file ships with structured sections (headers, TODO markers, example patterns) but without substantive canonical content. The developer does not need to do anything with it on Day 0 except know it exists at its canonical path.

The minimal v1 template declares its purpose at the top — what the file is for, what the corresponding skill audits against it, and how to populate it as the project grows.

**Moment 2 — During development**

As the project grows, the developer (or team) updates the schema file to reflect the canonical state of their domain knowledge. New design tokens added to the codebase → declared in COLOR-SCHEMA.md. New prompts added → declared in AI-CONFIG.md. New cloud resources deployed → declared in COST-SCHEMA.md.

The recommended cadence: **update the schema file as part of any domain-changing commit.** When a PR introduces a new design token, the same PR updates COLOR-SCHEMA.md. When a new prompt template is added, the same PR updates AI-CONFIG.md.

This keeps the schema file in sync with the codebase. Code review verifies the schema file matches what's being added or changed.

**Moment 3 — At audit time**

When the corresponding conditional skill runs (via `make qa-<skill-name>` or in CI), the skill reads the schema file as authority and compares it against the codebase. Drift between schema and codebase surfaces in the skill's report.

The developer reads the report and either:
- Refactors the codebase to match the schema (e.g., replace hardcoded values with token references)
- Updates the schema to declare what's now in the codebase (e.g., add a new token declaration)
- Removes stale entries from the schema (e.g., a retired prompt template)

**A concrete walkthrough — COLOR-SCHEMA.md across the three moments**

To illustrate the lifecycle, consider COLOR-SCHEMA.md (enabled when has_design_system: true):

**Moment 1 — Day 0:** scaffold.py generates `docs/design/COLOR-SCHEMA.md` with sections for color tokens, typography tokens, spacing tokens, shared components, and naming conventions. Each section has a TODO marker and an example pattern showing the declaration format. **The example is illustrative — the developer chooses their own tokens and conventions.** The file is minimal but structured.

**Moment 2 — Development:** A developer adds a new button component in `components/Button.tsx`. The component uses `var(--color-primary)` for its background. The same PR adds an entry to COLOR-SCHEMA.md's color tokens section declaring `--color-primary` (with its hex value, intended use, and any usage constraints). Six months later, a designer wants the brand color updated. They change the hex value in COLOR-SCHEMA.md; CSS references that read `var(--color-primary)` inherit the change automatically. Hardcoded references (if any exist) do not.

**Moment 3 — Audit:** Pre-release, the team runs `make qa-design-system-audit`. The skill reads COLOR-SCHEMA.md as authority and scans the codebase. It finds 3 files using hardcoded hex values where `--color-primary` should be referenced (drift from the schema). The team refactors those files; the next audit passes.

### 9.3 The discipline

**Schema-leads-codebase.** New domain entities are declared in the schema file first, then implemented in code. Reverse-direction work (implementing first, declaring later) is acceptable but should result in immediate schema update in the same PR.

**Schema-in-PR.** When a PR introduces or changes domain entities, the schema file update is part of the same PR. Reviewers verify the schema reflects the change.

**Audit-catches-lapse.** When schema-leads-codebase or schema-in-PR discipline lapses, the corresponding skill's audit catches the drift. The audit report is the safety net for discipline lapses.

**Schema is durable record.** The schema file lives in the project permanently. It is git-tracked. Historical schema state can be reconstructed from git history. The schema file is part of the project's domain documentation, not transient state.

**Domain-appropriate assessment ladders.** Different conditional skills produce assessments using vocabulary appropriate to their domain. ascent-cost-posture and ascent-sec-posture use Strong / Partial / Moderate / Weak — language appropriate for operational discipline. ascent-vitality uses Active / Steady / Slowing / Dormant — language appropriate for activity over time. Each skill's assessment vocabulary is chosen for fit to its domain rather than enforced consistency across skills.

### 9.4 What schema files do NOT do

Schema files are authority records, not policy enforcers. They:

- Do NOT prevent the developer from making changes (the developer can hardcode a color value; the schema doesn't block it)
- Do NOT auto-update from codebase changes (the developer must update the schema; nothing parses the codebase and writes to the schema)
- Do NOT replace ADRs, design documents, or other architectural records (those describe *decisions*; schema files record *canonical state*)
- Do NOT carry semantic meaning the framework enforces (a token named `--color-primary` could refer to any color; the schema records the name and intent, not the design rationale)

The skill that reads a schema file is the enforcement mechanism — the schema is the authority the skill audits against.

### 9.5 Schema file v1 minimum content

Each schema file ships from Phase 4 with minimum v1 content:

- Title and purpose statement
- Canonical path reference (so the file says where it lives)
- Reference to the corresponding skill (so the file says what audits against it)
- Lifecycle reminder (so the file says when to update)
- Structured TODO sections (so the developer knows what to fill in)

The actual structure and TODO sections per schema file are implemented in Cluster 3 (Phase 4 plan §9.4) and documented in the final `.tmpl` files that ship with ASCENT projects. The companion document does not draft these literal template contents — Cluster 3 implements them with concrete v1 structure per schema.

### 9.6 Schema files and deployment readiness

Schema files participate in the project's deployment lifecycle, not just its development lifecycle. As a project moves toward production deployment and through subsequent releases, the schema file's role evolves.

**Pre-deploy review:** Before a project's first production deploy, the schema file should be reviewed for:

- Completeness — are all known domain entities (tokens, prompts, personas, etc.) declared in the schema?
- Consistency — does `make qa-<skill-name>` pass cleanly, with no drift between schema and codebase?
- Currency — are stale or deprecated entries removed or clearly marked as deprecated?

The Phase 3 skill `ascent-release-readiness` is the natural surface for this review. Release-readiness checks should include schema-file audit status (the corresponding conditional skill passes) as part of the release gate.

**At deploy time:** The schema file ships with the project. In production:

- AI-CONFIG.md may be read by the application at runtime (e.g., the agent layer reads it to know which prompts are valid)
- COLOR-SCHEMA.md typically stays as documentation, but design system tokens it declares (via CSS variables) ship in the application's stylesheet
- COST-SCHEMA.md may inform infrastructure-as-code generation (declared resources match deployed resources)
- SECURITY-BASELINE.md is the audit reference for production security posture
- VITALITY-METRICS.md drives ongoing measurement of the deployed project's health

The schema file's role at deploy time depends on its domain. Some schemas are runtime authorities; others are documentation authorities. The schema-leads-codebase discipline applies in both cases.

**Post-deploy maintenance:** Production runs introduce changes that need retroactive schema updates:

- Hotfix added a new design token? Update COLOR-SCHEMA.md before next release
- Emergency prompt patch deployed? Update AI-CONFIG.md to reflect the new prompt state
- Cloud resource scaled up in production? Update COST-SCHEMA.md to reflect new resource allocations

Without discipline, post-deploy changes drift from the schema. The next audit catches it; the schema gets retroactively updated. Release-readiness for the next deploy verifies schema is current before shipping.

**Across releases over time:** Each release should treat schema-file consistency as part of release-readiness. Treat schema review as a release-gating concern:

- Run `make qa-<skill-name>` and confirm passes
- Diff the schema against the previous release tag (`git diff <last-tag> docs/design/COLOR-SCHEMA.md`) and review changes
- Confirm deprecated entries are removed or clearly marked
- Confirm the schema's "what to update" reminder still applies

The schema file's git history is a durable record of how the project's domain knowledge has evolved. Major architectural changes (rebranding, persona expansion, new AI features, security posture changes) show up in schema-file diffs across releases.

**Schema files and the deployment readiness lifecycle:**

| Lifecycle moment | Schema file action |
|---|---|
| Pre-first-deploy | Review for completeness, consistency, currency |
| At deploy time | Ships as part of project; some are runtime authority |
| Post-deploy maintenance | Update retroactively for production-only changes |
| Pre-next-release | Re-review; treat as release-gating |
| Across releases | Schema diffs document domain evolution |

### 9.7 Schema file maintenance over project lifetime

As the project ages, the schema file accumulates entries. Some entries become stale (retired tokens, deprecated prompts). The developer is responsible for maintenance:

- **Adding entries:** When new domain entities emerge, declare them
- **Updating entries:** When existing entities change (renamed, modified), update the schema
- **Removing entries:** When entities are retired, remove them from the schema (or mark them deprecated with a clear path forward)

The skill's audit catches "entries declared but not in codebase" (stale schema entries) and "entities in codebase but not declared" (missing schema entries). Both directions of drift are flagged.

Refactoring guidance: at major releases or version transitions, review the schema file to ensure it reflects current canonical state. Treat schema review as part of release-readiness work.

### 9.8 Pattern application: detect-don't-ask

The schema-file pattern is a concrete application of detect-don't-ask (per patterns.md). The conditional skill does not prompt the developer for "what tokens exist?" or "what prompts are in this project?" — it reads the schema file to detect canonical state. The developer's domain knowledge lives in the schema file; the skill detects from it.

Future framework work may add additional schema-style conventions following the same pattern: a readable authoritative file that the skill reads, the developer maintains, and code review verifies. The "Structural verification of declared artifacts" pattern (per PHASE-4-PLAN.md §8.5 — to be elevated to patterns.md in Cluster 4) operates adjacent to detect-don't-ask: the schema-file convention is detect-don't-ask applied at the domain-knowledge level; structural verification operates at the artifact-existence level.

### 9.9 Cross-reference for per-capability sections

Sections §2 through §7 of this companion document reference §9 for the schema-file lifecycle discipline. Each capability section names its schema file, describes what the skill reads from it, and implicitly applies the discipline described here.

The per-capability sections do NOT repeat:
- The three lifecycle moments (§9.2)
- The schema-leads-codebase discipline (§9.3)
- The "what schema files do NOT do" boundary (§9.4)
- The maintenance guidance (§9.7)
- Deployment readiness considerations (§9.6)

If a reader of a per-capability section wants schema-file operational discipline, §9 is the canonical reference.
