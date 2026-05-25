# Phase 4 Plan — Scaffolding scripts (v0.5.0)

The plan for Phase 4. Implements the executable scripts that perform scaffold, enhance, and migrate operations against ASCENT-scaffolded projects. Until this phase, the parent skill `lloydbriantech-ascent` describes what to do; this phase ships the scripts that actually do it.

**Scope:** v0.5.0 release. The framework gains a fully functional scaffolder layer. A developer running `python3 scaffold.py` produces an ASCENT project ready for confident AI-assisted software development.

**Input:** Phase 3 delivery evidence (28 project-embedded skills, 4 architectural patterns, 16 principles, the two-layer verification model from v0.4.1), the design dialogue captured in §2, the prompt content drafted in PHASE-4-CAPABILITIES.md (companion document), and the established cluster-based contribution discipline from CONTRIBUTING.md.

---

## §1 — Mission and scope

### 1.1 What v0.5.0 ships

Phase 4 ships the scripts and templates that complete the framework's scaffolder layer. After v0.5.0, a developer can scaffold a fully functional ASCENT project from the meta-repo and proceed through their project's lifecycle with framework support.

**Scripts (Meta-repo-POV):**

- `scripts/scaffold.py` — interactive and config-driven scaffolder. Reads developer input or `.ascent-scaffold.yaml`, generates a complete ASCENT project structure with baseline + selected conditional skills, populates `INTENT-MAP.md`, initializes git, runs final integrity check
- `scripts/bootstrap.py` — placeholder substitution against template-shaped inputs. Used by scaffold.py and migrate.py; can be invoked standalone for re-substitution after manual edits
- `scripts/enhance.py` — adds capabilities to existing ASCENT projects post-scaffold. Toggles a capability from false to true; generates the corresponding conditional skill and authority schema file; updates `.ascent-scaffold.yaml`
- `scripts/migrate.py` — brings non-ASCENT projects to ASCENT. Operates per ADR-002 modify-not-overwrite discipline; adds framework structure to an existing repo without destroying the project's existing content

**Infrastructure (Meta-repo-POV):**

- `make/qa-scaffold-integrity.sh` — structural validator with six consistency checks (per §8). Runs as pre-commit gate in scaffold.py and as opt-in audit in ASCENT projects
- `make/qa.mk` integration — qa-scaffold-integrity wired into the make vocabulary
- Five synthetic test scripts for the scripts above (per §7)
- Three fixture YAML files for synthetic testing (per Appendix A)
- Two smoke tests against the scaffolder (per §7)
- Cloud component mapping reference (`references/cloud-component-mapping.md`) — provides AWS/GCP/Azure/edge equivalents for cloud component categories, supporting both the framework's `ascent-cost-posture` skill and developer decisions in ASCENT projects

**ASCENT-project artifacts (templates that ship into scaffolded projects):**

- `assets/template/CLAUDE.md.tmpl` substantive content — the Day 0 entry-point document for Claude in scaffolded projects. Captures session resumption protocol acknowledgment, skill catalog reference, and project orientation
- `assets/template/.claude/commands/` template directory — slash-command templates that ship into scaffolded projects
- `assets/template/START-HERE.md.tmpl` — the document that ships at the root of every ASCENT project; tells the developer what they got and how to proceed. v1 content is drafted in PHASE-4-CAPABILITIES.md §8 (see companion)
- `assets/template/docs/<domain>/<SCHEMA>.md.tmpl` — six schema-file templates corresponding to the six capabilities. When a capability is enabled, the scaffolder generates the schema file as the canonical domain knowledge authority. The corresponding conditional skill audits against the schema file. Minimal v1 templates with TODO sections; developers populate over the project's lifecycle. See §5 for the capability→schema mapping.
- `assets/template/make/qa-scaffold-integrity.sh` — opt-in audit copy that ships into ASCENT projects

**Process and release artifacts:**

- PHASE-4-PLAN.md and PHASE-4-CAPABILITIES.md (this document and its companion)
- CHANGELOG.md v0.5.0 entry
- ROADMAP.md updates (Phase 4 → complete; Phase 5 → awaiting signal)
- Framework version bump 0.4.1 → 0.5.0 (Makefile, SKILL.md frontmatter, README badge)
- Self-test appendix to PHASE-4-PLAN.md per v0.4.1 precedent

### 1.2 Two quality checkpoints (Phase 4's mission)

Phase 4's substance is the framework's commitment to two quality checkpoints that govern v0.5.0:

**Checkpoint One — Framework correctness (Meta-repo-POV).** The framework's scripts, scaffolder logic, template substitution, and validators behave correctly. This checkpoint is verified by synthetic tests, smoke tests, and the four structural validators that already exist in v0.4.1 (qa-skill-frontmatter, qa-links, qa-template-placeholders, qa-claimed-vs-actual). v0.5.0 ships when this checkpoint passes cleanly.

**Checkpoint Two — ASCENT project readiness (ASCENT-project-POV).** The framework's output — the project that emerges from `python3 scaffold.py` — is genuinely ready for confident AI-assisted software development. This is verified by qa-scaffold-integrity, the structural validator that ships in Phase 4 with six consistency checks: skill directories match INTENT-MAP rows; README skill counts match actual skills; ADR INDEX matches ADR files; conditional skills and their authority schema files match capability state in `.ascent-scaffold.yaml`; framework version is coherent across Makefile, SKILL.md, and README badge; START-HERE.md's conditional sections match the project's actual capability state. v0.5.0 ships when this checkpoint can run against scaffolded outputs cleanly.

The two checkpoints are independent. A framework can be correct (Checkpoint One) and still produce projects that aren't ready (Checkpoint Two fails on the generated output). The mission requires both.

#### 1.2.1 POV vocabulary

This plan distinguishes two perspectives on every artifact and every concern. Discipline matters because Phase 4 spans both perspectives, and clarity about which one is in scope at each moment prevents quiet drift.

- **Meta-repo-POV** — concerns that live in `lloydbrian/lloydbriantech-ascent`, the framework's repository. The framework's own development: scripts, validators, tests, plan documents, reference modules, patterns.md.
- **ASCENT-project-POV** — concerns that live in a project produced by `python3 scaffold.py`. The downstream project's experience: the rendered scaffolded directory, the developer's interaction with CLAUDE.md, the runtime behavior of skills against the developer's codebase.

Most artifacts have a single dominant POV. Some artifacts (like CLAUDE.md.tmpl content) are authored in the meta-repo from Meta-repo-POV but ship as ASCENT-project-POV templates — they have dual concerns. The POV label clarifies which concern is being discussed.

A minor asymmetry to note: "meta-repo" is anchored on the physical artifact (the repository itself). "ASCENT project" is anchored on the conceptual identity — the actual ASCENT project that the developer produced and is now working in. Both labels use hyphenated identifiers (Meta-repo-POV, ASCENT-project-POV) for consistency.

This vocabulary extends to PHASE-4-CAPABILITIES.md, the companion document. See that document's §1.4 for its POV inheritance and how the discipline applies to capability prompts and START-HERE.md content (both of which are authored in the meta-repo as templates but consumed by developers in their ASCENT projects).

### 1.3 Success criterion

v0.5.0 ships successfully when the following 7-step path executes cleanly end-to-end:

1. Developer clones lloydbriantech-ascent meta-repo
2. Developer runs `python3 scripts/scaffold.py` and answers the prompts interactively (or supplies `--config <file>` for non-interactive mode)
3. scaffold.py generates a complete ASCENT project at the developer's chosen path, with 21 baseline skills plus 0-7 conditional skills based on capability answers
4. scaffold.py invokes qa-scaffold-integrity as pre-commit gate; all 6 checks pass
5. scaffold.py initializes git and creates the initial commit (unless `--no-git` opt-out)
6. Developer changes directory into the scaffolded project, runs `make dev-up`, sees the stack come up cleanly
7. Developer opens Claude Code in the scaffolded project; Claude reads the project's state from `.ascent-meta.json`, `docs/delivery/session-state.md` (empty for fresh scaffold), and `CLAUDE.md`; Claude responds with confidence and grounding

If step 7 — the developer's first interaction with Claude in their freshly-scaffolded project — produces a confidently-grounded response, v0.5.0 has delivered on its mission.

### 1.4 What Phase 4 does NOT ship

Explicit boundary statement for scope discipline. The following items are NOT shipped in v0.5.0:

1. **`gh repo create --template` integration.** scaffold.py creates the project locally with git init + initial commit. Publishing to GitHub via `gh` is deferred to Phase 6 (starter repo generation).

2. **Runtime LLM provider abstraction.** The framework remains Claude-bound for authoring purposes. The `.ascent-scaffold.yaml`'s `llm_provider: claude` field is the door-keeping mechanism — it captures the intent without committing to multi-provider abstraction. Multi-provider abstraction (Claude / OpenAI / Anthropic API / others) is deferred to post-v1.0.

3. **Semantic content verification for cross-cutting artifacts.** qa-scaffold-integrity is structural only — it verifies file existence and bidirectional references, not whether the content meets some semantic standard. Semantic verification (does CLAUDE.md.tmpl content actually serve as a useful entry point?) remains human PR review territory per v0.4.1's two-layer verification model.

4. **Interactive-mode pexpect testing.** Phase 4's interactive-mode tests use piped-stdin minimum. Full interactive simulation via pexpect (or equivalent) is deferred to v0.5.x hardening.

5. **Capability removal in enhance.py.** enhance.py adds capabilities to existing ASCENT projects but does not remove them. If a developer wants to disable a previously-enabled capability, they edit `.ascent-scaffold.yaml` manually and the corresponding skill/schema may stay in the project. Capability removal is deferred to v0.5.x or later.

6. **Cross-AI-provider scaffolding.** scaffold.py is opinionated about producing projects that work with Claude. While `.ascent-scaffold.yaml` carries the `llm_provider` field, the scaffolder doesn't generate provider-specific entry points (e.g., a `.gemini/` directory for Gemini, a `.copilot/` directory for GitHub Copilot). Cross-provider scaffolding is post-v1.0.

7. **START-HERE.md beyond v1 content.** The v1 draft of START-HERE.md content lives in PHASE-4-CAPABILITIES.md and ships with v0.5.0. Refinements informed by Phase 7's first production project (which will be the first real reader of START-HERE.md) are deferred via the plan-amendment discipline.

8. **Substantive v1 schema file content.** The six authority schema files (per §5.1) ship with minimal v1 templates — structured skeletons with TODO sections — but NOT substantive canonical content. Each domain's schema deserves deliberate design effort (what IS the canonical structure of PERSONAS.md? What goes in COST-SCHEMA.md?); rushing this design into Phase 4 risks shipping schema files that misshape future projects. Substantive v1 content is deferred to v0.5.x or later, informed by Phase 7's first production project usage of these schemas.

These NOT-shipping items are tracked in §10.10's negative-space verification (release gate) and tracked for deferred work in v0.5.x or later phases via CHANGELOG.md "Deferred" sections and ROADMAP updates.

---

## §2 — Design decisions resolved

Six major design questions were resolved through claude.ai design dialogue. Each is captured here as a durable decision; the dialogue rationale is summarized but not exhaustive.

### 2.1 Language: Python 3.10+ standard library only

**Decision:** Implement scripts in Python 3.10+ using standard library only. Scripts invoked from `make` targets (`make scaffold`, `make bootstrap`, etc.). No `pip install` required — scripts run on any modern Python installation.

**Rationale:** Python 3.10+ is widely available on developer machines and CI runners. Standard library covers all functional needs (file I/O, YAML via PyYAML... wait, that's not stdlib. Use json + custom YAML parser, or pre-installed PyYAML, or a minimal embedded YAML reader). Avoiding pip install keeps the framework dependency-free at the script layer — developers don't need to set up Python virtualenvs to scaffold their projects.

**Implementation note:** YAML support for `.ascent-scaffold.yaml` reading uses a minimal embedded YAML parser since `pyyaml` isn't standard library. Alternatively, treat `.ascent-scaffold.yaml` as line-by-line key:value format that doesn't require full YAML grammar. Decision deferred to Cluster 1 implementation; chunky-but-feasible.

### 2.2 Interactive default with config-driven hybrid

**Decision:** scaffold.py runs interactively by default. Two non-interactive modes available:

- `--config <file>` — non-interactive mode that reads all answers from a YAML configuration file. Skips all prompts; reports any required answers missing
- `--config <file> --interactive-missing` — resume-style mode that reads what's available from config and prompts only for missing required answers

**Rationale:** Interactive mode supports first-time developers and natural exploration. Config-driven mode supports CI workflows, reproducibility, and developers who know what they want. The `--interactive-missing` flag enables a workflow where a developer drafts most answers in YAML and fills in the rest interactively.

**Prompt rendering:** Mixed format. Simple yes/no capability questions render inline with examples. Complex multi-line questions (e.g., project_name with slug derivation) render in context blocks with clear section breaks.

### 2.3 Capability-driven gating (Option d)

**Decision:** Conditional skills are gated by named capabilities declared in `.ascent-scaffold.yaml`. Six capabilities map to seven conditional skills:

- `has_ai_features` → `ascent-ai-evals` skill
- `has_design_system` → `ascent-design-system-audit` skill
- `has_personas` → `ascent-persona-coverage` skill
- `cloud_deployed` → `ascent-cost-posture` skill
- `production_critical` → `ascent-security-audit` AND `ascent-sec-posture` skills (enumerate/summarize siblings, per patterns.md)
- `track_vitality` → `ascent-vitality` skill

Plus six corresponding authority schema files (per §5.1).

Capabilities default to `false`. Developer chooses each via prompt. Post-scaffold, capabilities are toggled via `enhance.py`. Capability removal is out of scope (deferred per §1.4).

**Rationale:** Capability framing is project-shaped (the developer knows whether their project has AI features), not skill-shaped (the developer would need to know what ascent-ai-evals does to choose it). This mirrors how the framework treats discipline: framework-internal vocabulary is for framework readers; project-facing vocabulary is for developers.

### 2.4 Testing: synthetic + smoke

**Decision:** Two testing layers for v0.5.0:

- **Synthetic tests** (`tests/scripts/test-<script>.sh`) — controlled tests against each script with deterministic inputs (fixtures) and asserted outputs
- **Smoke tests** (`tests/smoke-tests/scaffolder.sh`) — end-to-end test against the full scaffolder workflow using three fixture YAMLs

Three fixtures cover representative project shapes:
- `tests/fixtures/scaffold-fixtures/full-stack.yaml` (full ASCENT project with multiple capabilities)
- `tests/fixtures/scaffold-fixtures/minimal-cli.yaml` (lean CLI project with minimal capabilities)
- `tests/fixtures/scaffold-fixtures/ai-augmented.yaml` (project focused on AI features)

Interactive mode tests use piped-stdin minimum; pexpect-based simulation deferred to v0.5.x.

**Rationale:** Synthetic tests catch logic errors in scripts. Smoke tests catch integration issues across the full scaffolder workflow. Three fixtures span the project-shape variability the framework needs to support in v0.5.0.

### 2.5 GitHub integration: local only

**Decision:** scaffold.py performs `git init --initial-branch=main` and creates the initial commit by default. The `--no-git` flag opts out of git initialization for unusual workflows. No `gh repo create --template` integration in Phase 4 (deferred to Phase 6).

**Rationale:** Local-only git keeps Phase 4 self-contained. GitHub publishing requires authentication context (user's gh CLI configuration, repo permissions, organization access) that's beyond what scaffold.py should handle. Phase 6's starter repo generation will integrate publishing as a separate concern.

### 2.6 qa-scaffold-integrity dual-POV usage

**Decision:** qa-scaffold-integrity ships in two locations with two distinct uses:

**Primary use (Meta-repo-POV):** qa-scaffold-integrity is invoked by scaffold.py as a pre-commit gate during project generation. Before scaffold.py creates the git initial commit, it runs qa-scaffold-integrity against the newly-generated project to verify structural integrity. If checks fail, scaffold.py exits with an error before committing.

**Secondary use (ASCENT-project-POV):** A copy of qa-scaffold-integrity ships into scaffolded projects at `make/qa-scaffold-integrity.sh`. It is NOT wired into the default `make qa` target. Developers can invoke it manually (`make qa-scaffold-integrity`) as an opt-in audit after significant manual edits or before release. This honors developer autonomy — the audit is available without being mandatory.

Both copies execute the same six consistency checks per §8. The dual-POV nature means qa-scaffold-integrity is itself an artifact that exists in both meta-repo and ASCENT-project contexts.

**Pattern elevation:** The "structural verification of declared artifacts" pattern (introduced through qa-claimed-vs-actual in v0.4.0 and v0.4.1, generalized to qa-scaffold-integrity in this phase) earns the 5th entry in patterns.md. To be elevated in Cluster 4.

---

## §3 — Script inventory

Four Python scripts. Line-count estimates are guidance, not contracts (per v0.4.1 Observation 1).

### 3.1 scripts/scaffold.py (~600-800 lines)

**Purpose:** Interactive and config-driven scaffolder that produces a complete ASCENT project.

**Key responsibilities:**

- Read developer answers (interactive or `--config`)
- Validate answers against required fields and constraints
- Generate complete project directory structure (skills/, docs/, make/, assets/, etc.)
- Populate INTENT-MAP.md from CAPABILITY_PROMPTS mapping
- Generate authority schema files for enabled capabilities
- Generate START-HERE.md from template with conditional capability sections
- Initialize git (unless `--no-git`)
- Invoke qa-scaffold-integrity as pre-commit gate
- Create git initial commit (unless `--no-git`)

**Key data structure:** `CAPABILITY_PROMPTS` — the 9-field per-capability mapping that is the source of truth for capability→skill→schema relationships (per §5.4).

### 3.2 scripts/bootstrap.py (~150-200 lines)

**Purpose:** Placeholder substitution against template-shaped inputs. Used by scaffold.py and migrate.py for substitution work; can be invoked standalone for re-substitution after manual template edits.

**Key responsibilities:**

- Read template files with `<<PLACEHOLDER>>` markers
- Substitute placeholders with values from `.ascent-meta.json` or `.ascent-scaffold.yaml`
- Write substituted files to destination paths
- Validate that all required placeholders had substitution values

### 3.3 scripts/enhance.py (~400-500 lines)

**Purpose:** Add capabilities to existing ASCENT projects post-scaffold. Toggles a capability from false to true; generates the corresponding conditional skill template and authority schema file; updates `.ascent-scaffold.yaml`.

**Key responsibilities:**

- Read existing project's `.ascent-scaffold.yaml`
- Validate enhance request (capability exists in inventory; capability currently false)
- Generate skill template for the newly-enabled capability
- Generate authority schema file template for the newly-enabled capability
- Update INTENT-MAP.md to add the new skill row
- Update `.ascent-scaffold.yaml` to set capability true
- Optionally invoke qa-scaffold-integrity to verify post-enhance integrity

**ASCENT-project artifacts** — CLAUDE.md.tmpl substantive content with substitution logic, .claude/commands/ slash-command templates, START-HERE.md.tmpl content. These are scaffold.py's responsibilities at generation time (Meta-repo-POV) and ship as ASCENT-project-POV templates per §4.2.

### 3.4 scripts/migrate.py (~250-350 lines)

**Purpose:** Bring non-ASCENT projects to ASCENT. Operates per ADR-002 modify-not-overwrite discipline; adds framework structure to an existing repo without destroying the project's existing content.

**Key responsibilities:**

- Read existing project directory structure
- Detect conflicts (paths the framework would create that already exist)
- For each conflict, decide modify-not-overwrite strategy (extend, append, skip with warning)
- Add framework-required directories and files that don't conflict
- Generate `.ascent-meta.json` and `.ascent-scaffold.yaml` for the migrated project
- Generate baseline skill templates
- Initialize ADR INDEX
- Optionally run qa-scaffold-integrity against migrated state

Per ADR-002, migration is a one-way operation: a non-ASCENT project becomes an ASCENT project. Reversal (un-migrating) is out of scope.

---

## §4 — Output artifact catalog

Phase 4 ships 34 artifacts across three categories. Consecutively numbered #1-#34. Type column indicates NEW FILE (created), NEW DIR (directory of files), or ADDITIVE EDIT (additions to existing artifact).

### 4.1 Meta-repo-POV artifacts (#1-#18)

| # | Artifact | Path | Type | Cluster |
|---|---|---|---|---|
| 1 | scaffold.py | `scripts/scaffold.py` | NEW FILE | 1 |
| 2 | bootstrap.py | `scripts/bootstrap.py` | NEW FILE | 2 |
| 3 | enhance.py | `scripts/enhance.py` | NEW FILE | 2 |
| 4 | migrate.py | `scripts/migrate.py` | NEW FILE | 3 |
| 5 | qa-scaffold-integrity.sh (meta-repo) | `make/qa-scaffold-integrity.sh` | NEW FILE | 4 |
| 6 | qa.mk integration | `make/qa.mk` | ADDITIVE EDIT | 4 |
| 7 | test-scaffold.sh | `tests/scripts/test-scaffold.sh` | NEW FILE | 1 |
| 8 | test-bootstrap.sh | `tests/scripts/test-bootstrap.sh` | NEW FILE | 2 |
| 9 | test-enhance.sh | `tests/scripts/test-enhance.sh` | NEW FILE | 2 |
| 10 | test-migrate.sh | `tests/scripts/test-migrate.sh` | NEW FILE | 3 |
| 11 | test-qa-scaffold-integrity.sh | `tests/scripts/test-qa-scaffold-integrity.sh` | NEW FILE | 4 |
| 12 | full-stack.yaml | `tests/fixtures/scaffold-fixtures/full-stack.yaml` | NEW FILE | 1 |
| 13 | minimal-cli.yaml | `tests/fixtures/scaffold-fixtures/minimal-cli.yaml` | NEW FILE | 1 |
| 14 | ai-augmented.yaml | `tests/fixtures/scaffold-fixtures/ai-augmented.yaml` | NEW FILE | 1 |
| 15 | scaffolder.sh smoke test | `tests/smoke-tests/scaffolder.sh` | NEW FILE | 4 |
| 16 | scaffolder-interactive.sh smoke test | `tests/smoke-tests/scaffolder-interactive.sh` | NEW FILE | 4 |
| 17 | patterns.md addition | `skills/lloydbriantech-ascent/references/patterns.md` | ADDITIVE EDIT | 4 |
| 18 | cloud-component-mapping.md | `skills/lloydbriantech-ascent/references/cloud-component-mapping.md` | NEW FILE | 3 |

### 4.2 ASCENT-project-POV artifacts (#19-#28)

| # | Artifact | Path | Type | Cluster |
|---|---|---|---|---|
| 19 | CLAUDE.md.tmpl substantive content | `skills/lloydbriantech-ascent/assets/template/CLAUDE.md.tmpl` | ADDITIVE EDIT | 3 |
| 20 | START-HERE.md.tmpl | `skills/lloydbriantech-ascent/assets/template/START-HERE.md.tmpl` | NEW FILE | 3 |
| 21 | .claude/commands/ template directory | `skills/lloydbriantech-ascent/assets/template/.claude/commands/` | NEW DIR | 3 |
| 22 | qa-scaffold-integrity.sh (ASCENT-project) | `skills/lloydbriantech-ascent/assets/template/make/qa-scaffold-integrity.sh` | NEW FILE | 4 |
| 23 | AI-CONFIG.md.tmpl | `skills/lloydbriantech-ascent/assets/template/docs/ai/AI-CONFIG.md.tmpl` | NEW FILE | 3 |
| 24 | COLOR-SCHEMA.md.tmpl | `skills/lloydbriantech-ascent/assets/template/docs/design/COLOR-SCHEMA.md.tmpl` | NEW FILE | 3 |
| 25 | PERSONAS.md.tmpl | `skills/lloydbriantech-ascent/assets/template/docs/personas/PERSONAS.md.tmpl` | NEW FILE | 3 |
| 26 | COST-SCHEMA.md.tmpl | `skills/lloydbriantech-ascent/assets/template/docs/infra/COST-SCHEMA.md.tmpl` | NEW FILE | 3 |
| 27 | SECURITY-BASELINE.md.tmpl | `skills/lloydbriantech-ascent/assets/template/docs/security/SECURITY-BASELINE.md.tmpl` | NEW FILE | 3 |
| 28 | VITALITY-METRICS.md.tmpl | `skills/lloydbriantech-ascent/assets/template/docs/delivery/VITALITY-METRICS.md.tmpl` | NEW FILE | 3 |

### 4.3 Plan and release artifacts (#29-#34)

| # | Artifact | Path | Type | Cluster |
|---|---|---|---|---|
| 29 | PHASE-4-PLAN.md | `docs/framework/PHASE-4-PLAN.md` | NEW FILE | 0 |
| 30 | PHASE-4-CAPABILITIES.md | `docs/framework/PHASE-4-CAPABILITIES.md` | NEW FILE | 0 |
| 31 | CHANGELOG v0.5.0 entry | `CHANGELOG.md` | ADDITIVE EDIT | 5 |
| 32 | ROADMAP update | `docs/framework/ROADMAP.md` | ADDITIVE EDIT | 5 |
| 33 | Version bump (Makefile, SKILL.md, README) | multiple files | ADDITIVE EDIT | 5 |
| 34 | Self-test appendix | `docs/framework/PHASE-4-PLAN.md` | ADDITIVE EDIT | 5 |

### 4.4 Reconciliation

- Total artifacts: **34**
- §4.1 Meta-repo-POV: 18 artifacts (#1-#18)
- §4.2 ASCENT-project-POV: 10 artifacts (#19-#28)
- §4.3 Plan and release: 6 artifacts (#29-#34)

### 4.5 Cluster distribution

| Cluster | Artifacts | Count |
|---|---|---|
| 0 (planning) | #29, #30 | 2 |
| 1 (scaffold.py + capability system + fixtures + test) | #1, #7, #12, #13, #14 | 5 |
| 2 (bootstrap.py + enhance.py + 2 tests) | #2, #3, #8, #9 | 4 |
| 3 (migrate.py + templates + schemas + cloud-mapping) | #4, #10, #18, #19, #20, #21, #23, #24, #25, #26, #27, #28 | 12 |
| 4 (qa-scaffold-integrity + smoke tests + pattern elevation) | #5, #6, #11, #15, #16, #17, #22 | 7 |
| 5 (closing) | #31, #32, #33, #34 | 4 |

Total: 2 + 5 + 4 + 12 + 7 + 4 = 34 ✓

### 4.6 Validator self-test expectations

After Cluster 5 ships, the framework's self-test expects:

- **qa-skill-frontmatter:** 29/29 PASS (unchanged from v0.4.1)
- **qa-links:** all internal links resolve cleanly
- **qa-template-placeholders:** all placeholders valid
- **qa-claimed-vs-actual** (with PLAN=docs/framework/PHASE-4-PLAN.md): **33 PASS / 0 FAIL / 1 SKIP**

The 1 SKIP is the self-test appendix (#34) — appendices are APPENDIX type and are skipped per qa-claimed-vs-actual's design.

---

## §5 — Capability inventory

Phase 4's substantive design work centers on six capabilities, each mapping to one or more conditional skills and an authority schema file. The mapping is captured here as a design commitment; scaffold.py's CAPABILITY_PROMPTS data structure is the canonical implementation (per §5.4).

### 5.1 Six capabilities

| Capability | Enables skill(s) | Default | Authority schema file |
|---|---|---|---|
| `has_ai_features` | `ascent-ai-evals` | false | `docs/ai/AI-CONFIG.md` |
| `has_design_system` | `ascent-design-system-audit` | false | `docs/design/COLOR-SCHEMA.md` |
| `has_personas` | `ascent-persona-coverage` | false | `docs/personas/PERSONAS.md` |
| `cloud_deployed` | `ascent-cost-posture` | false | `docs/infra/COST-SCHEMA.md` |
| `production_critical` | `ascent-security-audit`, `ascent-sec-posture` | false | `docs/security/SECURITY-BASELINE.md` |
| `track_vitality` | `ascent-vitality` | false | `docs/delivery/VITALITY-METRICS.md` |

All capabilities default to false. The developer enables them at scaffold time via prompts; post-scaffold via `enhance.py`.

### 5.2 Capability count

Six capabilities map to seven conditional skills (production_critical enables two skills as enumerate/summarize siblings per patterns.md) and six authority schema files.

### 5.3 Capability persistence

**At scaffold time (Meta-repo-POV):** Developer's capability answers are written to `.ascent-scaffold.yaml` in the scaffolded project. scaffold.py uses these answers to determine which conditional skills and schema files to generate.

**During project lifetime (ASCENT-project-POV):** `.ascent-scaffold.yaml` is the persistent record of which capabilities are active in this project. The corresponding conditional skills read it (via INTENT-MAP.md or directly) to know what they audit.

**Post-scaffold extension (Meta-repo-POV):** When the developer wants to add a capability later, `enhance.py` reads `.ascent-scaffold.yaml`, toggles the capability to true, generates the corresponding skill and schema file, and updates `.ascent-scaffold.yaml`.

**Authority schema files (ASCENT-project-POV):** When a capability is set to `true`, the scaffolder generates the corresponding authority schema file (per §5.1's table) as part of the ASCENT project. The schema file is the canonical domain knowledge for its concern — design tokens for COLOR-SCHEMA.md, persona definitions for PERSONAS.md, AI configuration for AI-CONFIG.md, etc. The conditional skill enabled by that capability reads its authority schema file at runtime; the schema file is the authority the skill audits against. Developers populate and maintain these files over the project's lifecycle.

Phase 4 ships minimal v1 schema templates per §1.1 — each schema file has a structured skeleton with TODO sections rather than canonical v1 content. Substantive v1 content for each schema file is design work deferred to v0.5.x or later, informed by Phase 7's first production project usage.

### 5.4 Mapping authority

The canonical capability-to-skill-and-schema mapping is defined in `scripts/scaffold.py` as the `CAPABILITY_PROMPTS` data structure. The framework treats this Python structure as the source of truth.

Each entry in CAPABILITY_PROMPTS is a dictionary with these fields:

- `id` — capability identifier (e.g., `"has_ai_features"`)
- `question` — the developer-facing question text
- `examples` — list of example project characteristics that trigger this capability
- `default` — the value if the developer presses Enter without typing (always `False` in v0.5.0 per §5.1)
- `enables_skill` — list of skill names this capability gates
- `enables_schema` — path to the authority schema file generated when this capability is true (e.g., `"docs/ai/AI-CONFIG.md"`)
- `skill_value` — what the gated skill does
- `why_it_helps` — the value framing for the developer
- `runtime_signal` — what the developer will observe when the skill runs

That's 9 fields. The structure is v1.1 of CAPABILITY_PROMPTS, accommodating the schema-file convention from §5.3.

### 5.5 Documentation reference

The v1 prompt content (`question`, `examples`, `skill_value`, `why_it_helps`, `runtime_signal` for each of the six capabilities) is drafted in detail in PHASE-4-CAPABILITIES.md §2-§7 (the companion document). When Cluster 1 implements scaffold.py, it reads PHASE-4-CAPABILITIES.md content into the CAPABILITY_PROMPTS data structure.

---

## §6 — Prompt content reference

### 6.1 Companion document role

The detailed v1 user-facing content for capability prompts and START-HERE.md lives in PHASE-4-CAPABILITIES.md, the companion document. This split honors the object-oriented documents principle: design decisions live in the plan; user-facing content lives in the companion. Each file does one job.

### 6.2 What the companion contains

PHASE-4-CAPABILITIES.md contains nine sections:

- §1 Companion overview — purpose, voice principles, POV vocabulary inheritance
- §2 has_ai_features — prompt definition, examples, skill value, runtime samples
- §3 has_design_system — same structure
- §4 has_personas — same structure
- §5 cloud_deployed — same structure (with cloud-provider context)
- §6 production_critical — dual-skill enablement (security-audit + sec-posture)
- §7 track_vitality — same structure
- §8 START-HERE.md v1 content — the v1 template content for the ASCENT project's entry point document
- §9 Schema file lifecycle discipline — generic discipline applying to all six schema files

### 6.3 Companion content status

The companion document is treated as **v1 — refinable**. The content reflects the design dialogue's understanding of capability prompts and START-HERE.md content as of Phase 4 planning. Refinements informed by Phase 7's first production project (which will be the first real reader of this content) are deferred via the plan-amendment discipline — amendments append to the companion, never rewrite v1.

### 6.4 Voice principles for companion content

The companion applies developer-friendly voice principles (concrete over abstract, second-person address, skill-value framing, default-explicit, conservative on framework-internal language). These principles ground the content in the developer's mental model rather than the framework's.

The plan (this document) and companion are designed to be read together: plan first for design context, companion for the user-facing content that implements the design.

---

## §7 — Testing strategy

### 7.1 Two testing layers

Phase 4 ships two distinct testing layers:

**Synthetic tests** — controlled tests against each individual script with deterministic inputs (fixture YAMLs or piped stdin) and asserted outputs. Five test scripts (one per script being tested):

- `tests/scripts/test-scaffold.sh`
- `tests/scripts/test-bootstrap.sh`
- `tests/scripts/test-enhance.sh`
- `tests/scripts/test-migrate.sh`
- `tests/scripts/test-qa-scaffold-integrity.sh`

**Smoke tests** — end-to-end tests against the full scaffolder workflow using realistic fixture inputs:

- `tests/smoke-tests/scaffolder.sh` (config-driven mode, three fixtures)
- `tests/smoke-tests/scaffolder-interactive.sh` (interactive mode via piped stdin)

### 7.2 What the smoke test verifies in the scaffolded project

For each of the three fixtures, the smoke test:

- Runs scaffold.py with the fixture YAML as `--config <file>`
- Verifies the scaffolded project exists at the expected path
- Runs `make qa` against the scaffolded project (all 4 validators pass)
- Runs `make test-skills` against the scaffolded project (skill tests pass)
- Runs `make smoke-test` against the scaffolded project (the scaffolded project's own smoke tests pass)

The smoke test thus verifies the framework produces working ASCENT projects across multiple project shapes.

### 7.3 Three fixtures

Three fixture YAMLs cover representative project shapes:

- **full-stack.yaml** — full ASCENT project with multiple capabilities enabled (has_ai_features, has_design_system, cloud_deployed, production_critical). Tests the maximal-conditional case
- **minimal-cli.yaml** — lean CLI project with all capabilities false. Tests the minimal-baseline case
- **ai-augmented.yaml** — focused project with only has_ai_features true. Tests a single-conditional-skill case

Fixture content drafts in Appendix A.

### 7.4 Interactive mode testing

Phase 4 ships interactive mode testing via piped stdin minimum. The test script pipes expected developer answers to scaffold.py's stdin and verifies the script handles the input correctly.

Full interactive simulation via pexpect (or equivalent terminal automation) is deferred to v0.5.x hardening per §1.4.

### 7.5 Test execution

All tests run via `make test-scripts` (synthetic) and `make smoke-test` (smoke). Phase 4 adds both targets to `make/test.mk`. Existing v0.4.1 `make test-skills` infrastructure handles SKILL-level testing for the conditional skill templates.

### 7.6 Behavior verification, not documentation grep

Per Principle §16 (introduced in v0.4.1), tests verify behavior through mechanical stand-ins and controlled fixtures, asserting on what the code produces rather than on what the documentation claims. Phase 4's tests follow this discipline:

- scaffold.py tests assert on generated project structure, file contents, INTENT-MAP rows
- bootstrap.py tests assert on substituted file contents matching expected output
- enhance.py tests assert on `.ascent-scaffold.yaml` state changes and generated artifacts
- migrate.py tests assert on conflict-resolution decisions and added structure
- qa-scaffold-integrity tests assert on validator output (PASS/FAIL counts) for known-good and known-bad inputs

---

## §8 — qa-scaffold-integrity design

### 8.1 Six consistency checks

qa-scaffold-integrity is a structural validator with six consistency checks. Each check verifies bidirectional structural correspondence within an ASCENT project. The checks are:

**Check 1 — Skill directories ↔ INTENT-MAP rows**

Every directory under `.claude/skills/` (excluding the parent skill and INTENT-MAP.md itself) corresponds to a row in INTENT-MAP.md. Every row in INTENT-MAP.md corresponds to a directory under `.claude/skills/`.

**Failure mode caught:** Manually added skills missing from INTENT-MAP, or INTENT-MAP rows orphaned from removed skills.

**Check 2 — README skill count ↔ actual skill count**

The skill-count statistic claimed in README.md matches the actual count of skill directories under `.claude/skills/`.

**Failure mode caught:** README stale relative to skill changes.

**Check 3 — ADR INDEX ↔ ADR files**

Every ADR file in `docs/architecture/adrs/` has a corresponding row in `docs/architecture/adrs/INDEX.md`. Every row in INDEX.md corresponds to a file.

**Failure mode caught:** ADR added without index update, or ADR removed without index cleanup.

**Check 4 — Conditional artifact inclusion ↔ `.ascent-scaffold.yaml` capability state**

For each capability set to `true` in `.ascent-scaffold.yaml`:
- The corresponding conditional skill(s) must be present in the project (per the CAPABILITY_PROMPTS mapping authority — §5.4)
- The corresponding authority schema file must be present in the project (per the capability→schema mapping in §5.1)

For each conditional skill present, its enabling capability must be `true`. For each schema file present, its enabling capability must be `true`.

The check enforces bidirectional consistency across capability state, conditional skills, and authority schema files.

**Failure mode caught:** scaffold.py's mapping drift between capabilities and what gets generated. Also catches manual edits where a developer toggles a capability in YAML without using enhance.py to apply the change.

**Check 5 — Framework version coherence**

The framework version stated in three places must agree:
- `Makefile`'s `FRAMEWORK_VERSION` value
- `.claude/skills/lloydbriantech-ascent/SKILL.md` frontmatter `version:` field
- `README.md`'s framework badge

**Failure mode caught:** Partial version bump (e.g., Makefile updated but SKILL.md or README forgotten).

**Check 6 — START-HERE.md ↔ capability state**

START-HERE.md's conditional sections (e.g., "Capabilities you enabled" subsections per §6 of PHASE-4-CAPABILITIES.md) match the project's actual capability state in `.ascent-scaffold.yaml`. Each enabled capability has its corresponding section in START-HERE.md; no orphaned sections for disabled capabilities.

**Failure mode caught:** START-HERE.md stale after enhance.py adds a capability, or after manual capability state edits.

### 8.2 Check count and discipline

Total checks: **6**.

Each check has clear pass/fail criteria. The validator outputs structured pass/fail per check; aggregates to a final exit status. Failures include diagnostic detail (which specific bidirectional relationship is broken).

### 8.3 Dual-POV usage

Per §2.6, qa-scaffold-integrity ships in two locations:

**Primary (Meta-repo-POV):** Invoked by scaffold.py as pre-commit gate during project generation. Fails the scaffold if any check fails.

**Secondary (ASCENT-project-POV):** Copy ships into scaffolded projects at `make/qa-scaffold-integrity.sh`. NOT wired into default `make qa`. Developers invoke manually as opt-in audit (`make qa-scaffold-integrity`) after significant edits or before release.

Both copies execute the same six checks. The dual-POV nature is the validator itself existing as an artifact in both contexts.

### 8.4 Implementation skeleton

```bash
#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${1:-.}"
FAIL_COUNT=0

check_skill_intent_map_correspondence() {
    # Check 1 logic
    # ...
}

check_readme_skill_count() {
    # Check 2 logic
    # ...
}

check_adr_index_correspondence() {
    # Check 3 logic
    # ...
}

check_capability_artifact_correspondence() {
    # Check 4 logic — checks both conditional skills AND authority schema files
    # ...
}

check_framework_version_coherence() {
    # Check 5 logic
    # ...
}

check_start_here_capability_correspondence() {
    # Check 6 logic
    # ...
}

# Run all checks
check_skill_intent_map_correspondence
check_readme_skill_count
check_adr_index_correspondence
check_capability_artifact_correspondence
check_framework_version_coherence
check_start_here_capability_correspondence

# Aggregate result
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "qa-scaffold-integrity: 6/6 checks PASS"
    exit 0
else
    echo "qa-scaffold-integrity: $FAIL_COUNT check(s) FAILED"
    exit 1
fi
```

The skeleton illustrates function naming convention. Cluster 4 implements the actual check logic.

### 8.5 Pattern elevation

The "structural verification of declared artifacts" pattern earns the 5th entry in patterns.md (to be elevated in Cluster 4). It generalizes the bidirectional-correspondence approach that emerged through qa-claimed-vs-actual in v0.4.0 and v0.4.1, and now qa-scaffold-integrity in Phase 4.

The pattern definition (paraphrased for inclusion in patterns.md): "A structural validator verifies that declarations in a canonical authority artifact (plan document, configuration file, schema file) correspond bidirectionally to actual artifacts in the system. The validator surfaces drift between declaration and actuality."

---

## §9 — Cluster plan

The cluster plan organizes Phase 4 implementation into six clusters following the established cluster-based contribution discipline (propose → approve → implement → review packet → push, per CONTRIBUTING.md).

Cluster size and PR format are flexible (per CONTRIBUTING.md Lesson 1). The cluster boundaries below reflect natural dependency groupings — each cluster delivers a coherent unit of work.

### 9.1 Cluster 0 — Planning documents

**Scope:** Commit PHASE-4-PLAN.md and PHASE-4-CAPABILITIES.md.

**Artifacts:** #29 (PHASE-4-PLAN.md), #30 (PHASE-4-CAPABILITIES.md).

**Coverage:** Pure Meta-repo-POV. Both documents are framework planning artifacts.

**Exit criteria:**

- [ ] `docs/framework/PHASE-4-PLAN.md` exists with all 10 sections plus Appendix A
- [ ] `docs/framework/PHASE-4-CAPABILITIES.md` exists with all 9 sections
- [ ] Both documents structurally complete (all promised sections present)
- [ ] `make qa-skill-frontmatter` reports 29/29 PASS unchanged
- [ ] `make qa-links` reports all internal links resolve cleanly
- [ ] `make qa-template-placeholders` reports 212 PASS unchanged
- [ ] PR opened and ready for review

**Estimated duration:** 1 day.

### 9.2 Cluster 1 — scaffold.py and capability system

**Scope:** Implement scaffold.py as the foundational scaffolder. Build the capability prompt system, fixture YAMLs, and synthetic test.

**Artifacts:** #1 (scaffold.py), #7 (test-scaffold.sh), #12 (full-stack.yaml), #13 (minimal-cli.yaml), #14 (ai-augmented.yaml).

**Coverage:** Pure Meta-repo-POV. All Cluster 1 artifacts (scaffold.py, synthetic test, three fixtures) live in the meta-repo.

**Exit criteria:**

- [ ] `scripts/scaffold.py` implements interactive, `--config`, and `--config --interactive-missing` modes per §2.2
- [ ] CAPABILITY_PROMPTS structure populated with all 6 capabilities per PHASE-4-CAPABILITIES.md §2-§7 content
- [ ] scaffold.py generates 21 baseline skill directories per fixture project
- [ ] scaffold.py generates 0-7 conditional skill directories based on capability state
- [ ] scaffold.py generates authority schema files for enabled capabilities (placeholders for Cluster 3 to populate)
- [ ] scaffold.py populates INTENT-MAP.md with rows for all generated skills
- [ ] scaffold.py initializes git (`git init --initial-branch=main`) and creates initial commit (unless `--no-git`)
- [ ] `--force` overwrite flag implemented for re-scaffold scenarios
- [ ] `--no-git` opt-out flag implemented
- [ ] Three fixture YAMLs exist and are loaded correctly by --config mode
- [ ] `tests/scripts/test-scaffold.sh` exists and PASS (synthetic test)
- [ ] `make qa-skill-frontmatter` unchanged; other validators applicable as expected

**Risk:** scaffold.py's scope is real. The script implements interactive prompts, capability mapping, file generation, git integration, and qa-scaffold-integrity invocation. If implementation surfaces edge cases requiring more code than estimated, Cluster 1 may exceed its duration.

**Mitigation A — Defer non-essential edge cases:** If complex edge cases surface during implementation (e.g., container engine auto-detection beyond prompt-driven, complex slug variations, sophisticated partial-failure recovery), defer them to v0.5.x hardening rather than blowing cluster scope.

When deferring, the deferred features are captured explicitly in:
- The cluster's PR description (under "Deferred to v0.5.x")
- v0.5.0's CHANGELOG.md "Deferred" section (per established precedent — see v0.4.0 and v0.4.1 CHANGELOG)
- v0.5.x work surfaces them at the next release

**Mitigation E — Mid-cluster check-in:** When scaffold.py reaches a natural inflection point — specifically when the CAPABILITY_PROMPTS structure exists and base file generation (for at least one skill) is working end-to-end — Claude Code surfaces progress for review before proceeding with the remaining features (other skill templates, edge cases, validation integration, git initialization).

This milestone typically corresponds to approximately 50% of scaffold.py's estimated scope (~300-400 lines), but the trigger is milestone-based, not line-based. The check-in produces three possible outcomes:

1. **Continue as scoped** — implementation is on track; no scope adjustment needed
2. **Defer specific edge cases** — apply Mitigation A; named features get deferred to v0.5.x with the deferral documented in the PR description and CHANGELOG
3. **Extend cluster duration** — scope is genuinely right but the duration estimate was wrong; the orchestrator acknowledges the new estimate explicitly

The check-in is not a hard pause — it's an opportunity to apply Mitigation A with evidence rather than retroactively after duration overrun.

**Estimated duration:** 2-3 days.

### 9.3 Cluster 2 — bootstrap.py and enhance.py

**Scope:** Implement bootstrap.py (placeholder substitution) and enhance.py (capability addition to existing projects). Two synthetic tests.

**Artifacts:** #2 (bootstrap.py), #3 (enhance.py), #8 (test-bootstrap.sh), #9 (test-enhance.sh).

**Coverage:** Pure Meta-repo-POV. Both scripts (bootstrap.py, enhance.py) and their tests live in the meta-repo.

**Exit criteria:**

- [ ] `scripts/bootstrap.py` performs placeholder substitution against `.ascent-meta.json` and `.ascent-scaffold.yaml` values
- [ ] `scripts/enhance.py` reads an existing ASCENT project's `.ascent-scaffold.yaml`, validates enhance request, toggles capability, generates corresponding skill and schema templates, updates INTENT-MAP and .ascent-scaffold.yaml
- [ ] enhance.py supports adding all 6 capabilities (each tested via synthetic test)
- [ ] enhance.py refuses to re-enable already-enabled capabilities; refuses to remove capabilities (add-only per §1.4)
- [ ] `tests/scripts/test-bootstrap.sh` exists and PASS
- [ ] `tests/scripts/test-enhance.sh` exists and PASS

**Estimated duration:** 2 days.

### 9.4 Cluster 3 — migrate.py + ASCENT-project templates + schema templates

**Scope:** Implement migrate.py for non-ASCENT-to-ASCENT migration. Author substantive content for CLAUDE.md.tmpl. Create START-HERE.md.tmpl and .claude/commands/ template directory. Create six authority schema file templates. Create cloud-component-mapping.md reference module. Update seven Phase 3 conditional SKILL.md template files to reference their authority schema files.

**Artifacts:** #4 (migrate.py), #10 (test-migrate.sh), #18 (cloud-component-mapping.md), #19 (CLAUDE.md.tmpl content), #20 (START-HERE.md.tmpl), #21 (.claude/commands/), #23 (AI-CONFIG.md.tmpl), #24 (COLOR-SCHEMA.md.tmpl), #25 (PERSONAS.md.tmpl), #26 (COST-SCHEMA.md.tmpl), #27 (SECURITY-BASELINE.md.tmpl), #28 (VITALITY-METRICS.md.tmpl).

**Coverage:** Mixed. migrate.py and test-migrate.sh are Meta-repo-POV. cloud-component-mapping.md is Meta-repo-POV (reference module in the meta-repo, with cross-references from ASCENT-project templates pointing to it). CLAUDE.md.tmpl, START-HERE.md.tmpl, .claude/commands/ template directory, and the six schema templates are ASCENT-project-POV templates that ship into projects at scaffold time.

**Exit criteria:**

- [ ] `scripts/migrate.py` brings non-ASCENT projects to ASCENT per ADR-002 modify-not-overwrite
- [ ] migrate.py detects conflicts and applies modify-not-overwrite per ADR-002
- [ ] migrate.py generates `.ascent-meta.json` and `.ascent-scaffold.yaml` for migrated projects
- [ ] `tests/scripts/test-migrate.sh` exists and PASS
- [ ] `assets/template/CLAUDE.md.tmpl` substantive content drafted per PHASE-4-CAPABILITIES.md §8 conventions
- [ ] `assets/template/START-HERE.md.tmpl` exists with v1 content per PHASE-4-CAPABILITIES.md §8
- [ ] `assets/template/.claude/commands/` directory exists with slash-command templates
- [ ] `assets/template/docs/ai/AI-CONFIG.md.tmpl` exists with minimal v1 structure
- [ ] `assets/template/docs/design/COLOR-SCHEMA.md.tmpl` exists with minimal v1 structure
- [ ] `assets/template/docs/personas/PERSONAS.md.tmpl` exists with minimal v1 structure
- [ ] `assets/template/docs/infra/COST-SCHEMA.md.tmpl` exists with minimal v1 structure
- [ ] `assets/template/docs/security/SECURITY-BASELINE.md.tmpl` exists with minimal v1 structure
- [ ] `assets/template/docs/delivery/VITALITY-METRICS.md.tmpl` exists with minimal v1 structure
- [ ] `skills/lloydbriantech-ascent/references/cloud-component-mapping.md` exists with service-equivalent mappings for AWS, GCP, Azure, and major edge platforms
- [ ] CLAUDE.md.tmpl, START-HERE.md.tmpl, and `ascent-cost-posture` SKILL.md template reference cloud-component-mapping.md as accessible framework knowledge for `cloud_deployed: true` projects
- [ ] 7 conditional SKILL.md templates updated to reference their authority schema files (ai-evals → AI-CONFIG.md; design-system-audit → COLOR-SCHEMA.md; persona-coverage → PERSONAS.md; cost-posture → COST-SCHEMA.md; security-audit and sec-posture → SECURITY-BASELINE.md; vitality → VITALITY-METRICS.md)

**Estimated duration:** 4-5 days. Largest cluster by scope; highest-risk for Phase 4.

### 9.5 Cluster 4 — qa-scaffold-integrity + smoke tests + pattern elevation

**Scope:** Implement qa-scaffold-integrity in both Meta-repo-POV (used by scaffold.py) and ASCENT-project-POV (template shipping into projects) forms. Wire qa-scaffold-integrity into qa.mk. Build smoke tests. Elevate the 5th pattern in patterns.md.

**Artifacts:** #5 (qa-scaffold-integrity meta-repo), #6 (qa.mk integration), #11 (test-qa-scaffold-integrity.sh), #15 (scaffolder.sh smoke), #16 (scaffolder-interactive.sh smoke), #17 (patterns.md addition), #22 (qa-scaffold-integrity ASCENT-project copy).

**Coverage:** Dual-POV. qa-scaffold-integrity ships in both locations: meta-repo (Meta-repo-POV primary use) and assets/template/make/ (ASCENT-project-POV opt-in audit) per §2.6. Smoke tests and integration test are Meta-repo-POV. patterns.md addition is Meta-repo-POV.

**Exit criteria:**

- [ ] `make/qa-scaffold-integrity.sh` implements all 6 checks per §8.1
- [ ] `make/qa.mk` includes `qa-scaffold-integrity` target
- [ ] `tests/scripts/test-qa-scaffold-integrity.sh` exists and PASS
- [ ] `tests/smoke-tests/scaffolder.sh` runs against all 3 fixtures and produces working ASCENT projects (all of project's `make qa`, `make test-skills`, `make smoke-test` PASS)
- [ ] `tests/smoke-tests/scaffolder-interactive.sh` exercises interactive mode end-to-end via piped stdin
- [ ] `skills/lloydbriantech-ascent/references/patterns.md` has 5th pattern entry ("Structural verification of declared artifacts") per §8.5
- [ ] `assets/template/make/qa-scaffold-integrity.sh` exists as ASCENT-project opt-in audit copy

**Estimated duration:** 2-3 days.

### 9.6 Cluster 5 — Closing (CHANGELOG, ROADMAP, version bump, appendix)

**Scope:** Ship the release-finalization artifacts. CHANGELOG v0.5.0 entry, ROADMAP update, version bumps, self-test appendix.

**Artifacts:** #31 (CHANGELOG entry), #32 (ROADMAP update), #33 (version bump across Makefile + SKILL.md + README), #34 (self-test appendix to PHASE-4-PLAN.md).

**Coverage:** Pure Meta-repo-POV. All closing-cluster artifacts (CHANGELOG, ROADMAP, version bump, appendix) are meta-repo content.

**Exit criteria:**

- [ ] `CHANGELOG.md` has v0.5.0 entry with substantive content per v0.4.0/v0.4.1 precedents (Added, Changed, Decided, Deferred, Statistics sections)
- [ ] `docs/framework/ROADMAP.md` Phase 4 marked ✅ complete; Phase 5 marked ⏸️ awaiting signal; current-state line bumped
- [ ] `Makefile` `FRAMEWORK_VERSION` bumped 0.4.1 → 0.5.0
- [ ] `skills/lloydbriantech-ascent/SKILL.md` frontmatter `version:` bumped 0.4.1 → 0.5.0
- [ ] `README.md` framework badge updated to 0.5.0
- [ ] PHASE-4-PLAN.md has self-test appendix with qa-claimed-vs-actual results documented (expected: 33 PASS / 0 FAIL / 1 SKIP)
- [ ] Any plan amendments accumulated during Clusters 1-4 documented in self-test appendix per v0.4.1 precedent
- [ ] All 4 structural validators PASS on meta-repo
- [ ] `make qa-claimed-vs-actual PLAN=docs/framework/PHASE-4-PLAN.md` reports 33 PASS / 0 FAIL / 1 SKIP

**Estimated duration:** 1 day.

### 9.7 Cross-cluster dependencies

- Cluster 0 (planning) precedes all others — the plan must commit before implementation work
- Cluster 1 (scaffold.py + capability system + fixtures) precedes Clusters 3, 4, 5 — those build on scaffold.py's capability system
- Cluster 2 (bootstrap.py + enhance.py) can run in parallel with Cluster 1 (both are independent scripts)
- Cluster 3 (migrate.py + templates + schemas + cloud-mapping) builds on Cluster 1's capability system and depends on it; can start after Cluster 1 reaches mid-cluster check-in
- Cluster 4 (qa-scaffold-integrity + smoke tests) depends on Clusters 1, 2, 3 — needs scaffolded projects to test against
- Cluster 5 (closing) ships last; depends on all prior clusters

### 9.8 Cluster plan total estimate

Per cluster estimates: 1 + (2-3) + 2 + (4-5) + (2-3) + 1 = **12-15 days** total Phase 4 duration.

Estimates assume single-developer pace (one developer at a time on each cluster). Cluster boundaries are coordination points where review packet shipping, PR review, and merge happen.

---

## §10 — Exit criteria for v0.5.0

The release-gating checklist. Each item is mechanically verifiable OR clearly delegable to human PR review per the two-layer verification model from v0.4.1's Lesson 3. v0.5.0 ships when all items pass; if any item fails at Cluster 5's closing-cluster review, ship is blocked until the failure is resolved (either by fixing the gap or by amending the plan via the documented amendment discipline).

This checklist is drawn from §1.3 (success criterion), §4 (artifact catalog), §9 (cluster exit criteria), and the broader Phase 4 design decisions. Where individual items reference specific sections, those are authoritative for the detail; this section is the consolidated release gate.

### 10.1 Scripts and infrastructure (Meta-repo-POV)

- [ ] `scripts/scaffold.py` ships at ~600-800 lines, implements interactive + config-driven + interactive-missing modes per §2.2
- [ ] `scripts/bootstrap.py` ships at ~150-200 lines, performs placeholder substitution against template-shaped inputs
- [ ] `scripts/enhance.py` ships at ~400-500 lines, adds capabilities to existing ASCENT projects per §5.3
- [ ] `scripts/migrate.py` ships at ~250-350 lines, brings non-ASCENT projects to ASCENT per ADR-002 modify-not-overwrite
- [ ] `make/qa-scaffold-integrity.sh` ships at ~150-200 lines, implements 6 checks per §8.1 + §8.2
- [ ] `make/qa.mk` includes `qa-scaffold-integrity` target
- [ ] All scripts use Python 3.10+ standard library only (no pip install required per §2.1)

### 10.2 Test infrastructure (Meta-repo-POV)

- [ ] `tests/scripts/test-scaffold.sh`, `test-bootstrap.sh`, `test-enhance.sh`, `test-migrate.sh`, `test-qa-scaffold-integrity.sh` all exist and PASS
- [ ] `tests/fixtures/scaffold-fixtures/full-stack.yaml`, `minimal-cli.yaml`, `ai-augmented.yaml` exist per Appendix A
- [ ] `tests/smoke-tests/scaffolder.sh` runs against all 3 fixtures and produces working ASCENT projects (all of project's `make qa`, `make test-skills`, `make smoke-test` PASS)
- [ ] `tests/smoke-tests/scaffolder-interactive.sh` exercises interactive mode end-to-end via piped stdin

### 10.3 ASCENT project artifacts (ASCENT-project-POV)

- [ ] `assets/template/CLAUDE.md.tmpl` contains substantive Day-0 entry-point content with substitution logic per §1.1 and §3.3
- [ ] `assets/template/.claude/commands/` directory contains slash-command template files (per §3.3)
- [ ] `assets/template/START-HERE.md.tmpl` ships v1 content per PHASE-4-CAPABILITIES.md §8
- [ ] `assets/template/make/qa-scaffold-integrity.sh` ships as ASCENT-project opt-in audit tool per §2.6
- [ ] `assets/template/docs/ai/AI-CONFIG.md.tmpl` exists with minimal v1 structure
- [ ] `assets/template/docs/design/COLOR-SCHEMA.md.tmpl` exists with minimal v1 structure
- [ ] `assets/template/docs/personas/PERSONAS.md.tmpl` exists with minimal v1 structure
- [ ] `assets/template/docs/infra/COST-SCHEMA.md.tmpl` exists with minimal v1 structure
- [ ] `assets/template/docs/security/SECURITY-BASELINE.md.tmpl` exists with minimal v1 structure
- [ ] `assets/template/docs/delivery/VITALITY-METRICS.md.tmpl` exists with minimal v1 structure

### 10.4 Quality verification

- [ ] `make qa-skill-frontmatter` reports all PASS on meta-repo
- [ ] `make qa-links` reports all internal links resolve on meta-repo
- [ ] `make qa-template-placeholders` reports all placeholders valid on meta-repo
- [ ] `make qa-claimed-vs-actual PLAN=docs/framework/PHASE-4-PLAN.md` reports **33 PASS / 0 FAIL / 1 SKIP** per §4.6
- [ ] Synthetic test suite passes (all 5 test scripts PASS)
- [ ] Smoke test passes (3 fixtures × end-to-end PASS = 3 successful ASCENT project scaffolds)

### 10.5 Documentation and lifecycle

- [ ] `CHANGELOG.md` has v0.5.0 entry with substantive content per v0.4.0/v0.4.1 precedents (Added, Changed, Decided, Deferred, Statistics)
- [ ] `docs/framework/ROADMAP.md` Phase 4 marked ✅ complete; Phase 5 marked ⏸️ awaiting signal; current-state line bumped
- [ ] `Makefile` FRAMEWORK_VERSION bumped 0.4.1 → 0.5.0
- [ ] `skills/lloydbriantech-ascent/SKILL.md` frontmatter version bumped 0.4.1 → 0.5.0
- [ ] `README.md` badge updated to 0.5.0
- [ ] `skills/lloydbriantech-ascent/references/patterns.md` contains 5th pattern ("Structural verification of declared artifacts") per §8.5
- [ ] `skills/lloydbriantech-ascent/references/cloud-component-mapping.md` exists as Meta-repo-POV reference

### 10.6 Companion document

- [ ] `docs/framework/PHASE-4-CAPABILITIES.md` exists with all 9 sections (companion overview + 6 capability prompts + START-HERE.md v1 content + schema file lifecycle discipline)
- [ ] Companion content drafted as v1 per §6.3 — refinable via plan-amendment discipline

### 10.7 Self-test evidence

- [ ] Self-test appendix appended to PHASE-4-PLAN.md per v0.4.1 precedent
- [ ] Any plan amendments accumulated during Clusters 1-4 documented in self-test appendix
- [ ] qa-claimed-vs-actual self-test result documented (expected: 33 PASS / 0 FAIL / 1 SKIP; deviations explained in appendix per v0.4.1 lesson)

### 10.8 Release procedure

After Cluster 5 PR merges:

- [ ] `git checkout main && git pull` syncs local main
- [ ] `git tag v0.5.0` creates the release tag
- [ ] `git push --tags` pushes to origin
- [ ] `.github/workflows/release.yml` fires successfully
- [ ] GitHub Release page at github.com/lloydbrian/lloydbriantech-ascent/releases/tag/v0.5.0 renders v0.5.0 CHANGELOG entry

### 10.9 Post-ship state

After v0.5.0 ships, the framework state should be:

- 7 tags shipped (v0.1.0-alpha through v0.5.0)
- 16 enforced principles (unchanged from v0.4.1; §16 added in that release)
- 5 architectural patterns (4 from v0.4.1 + structural verification pattern added in Phase 4 Cluster 4 — note: this count assumes Cluster 4 ships the patterns.md addition successfully; if Cluster 4 ships without the pattern entry due to amendment, the count drops to 4 with the pattern elevation deferred to v0.5.x)
- 28 project-embedded skill templates (unchanged from v0.4.0; conditional skill templates updated in Cluster 3 to reference authority schema files)
- 4 Python scripts (new in Phase 4)
- 5 structural validators (4 from v0.4.1 + qa-scaffold-integrity added in Phase 4)
- 24 reference modules (23 from v0.4.1 + cloud-component-mapping.md added in Phase 4)
- Phase 5 awaiting "Proceed with Phase 5" signal

### 10.10 Negative-space verification — items NOT shipping per §1.4

The following items were explicitly scoped out of Phase 4 per §1.4. v0.5.0 ships with these still NOT included; their continued deferral is a release gate.

- [ ] No `gh repo create --template` integration in scaffold.py (deferred to Phase 6 per §1.4)
- [ ] No runtime LLM provider abstraction (deferred to post-v1.0 per §1.4; the `.ascent-scaffold.yaml`'s `llm_provider: claude` field is the door-keeping mechanism, NOT the abstraction itself)
- [ ] No semantic content verification in qa-scaffold-integrity (validator remains structural-only per §1.4 and §2.6)
- [ ] No pexpect-based interactive testing (Phase 4 ships piped-stdin minimum per §1.4 and §7.4)
- [ ] No capability removal in enhance.py (add-only per §1.4 and §5.3)
- [ ] No cross-AI-provider scaffolding (framework remains Claude-bound for authoring per §1.4)
- [ ] START-HERE.md content remains at v1 (no v2 refinements shipped in Phase 4; refinements remain deferred to v0.5.x or Phase 7 feedback per §1.4)
- [ ] Schema files ship with minimal v1 templates only; no substantive canonical content shipped in Phase 4 (per §1.4)

If any of these items HAS shipped (i.e., crept into Phase 4 during implementation), document the scope creep in the closing-cluster self-test appendix and assess whether v0.5.0 should ship with the addition or defer the addition to v0.5.x.

Negative-space verification matters because scope creep is silent. Without an explicit check that NOT-shipping items remain NOT-shipping, Phase 4 could quietly absorb work that was supposed to be deferred.

---

## Appendix A — Test fixture YAML drafts

Three fixture YAMLs cover representative project shapes for synthetic and smoke testing. Final fixture contents drafted during Cluster 1 implementation; below is the v1 structure.

### A.1 full-stack.yaml (maximal-conditional fixture)

```yaml
project_name: "fullstack-demo"
project_slug: "fullstack-demo"
container_engine: "docker"
llm_provider: "claude"

capabilities:
  has_ai_features: true
  has_design_system: true
  has_personas: false
  cloud_deployed: true
  production_critical: true
  track_vitality: false
```

Tests the maximal-conditional case: four capabilities enabled, two skills via production_critical (security-audit + sec-posture), full feature surface.

### A.2 minimal-cli.yaml (minimal-baseline fixture)

```yaml
project_name: "cli-tool"
project_slug: "cli-tool"
container_engine: "podman"
llm_provider: "claude"

capabilities:
  has_ai_features: false
  has_design_system: false
  has_personas: false
  cloud_deployed: false
  production_critical: false
  track_vitality: false
```

Tests the minimal-baseline case: all capabilities false. Baseline 21 skills, no conditional skills or schema files.

### A.3 ai-augmented.yaml (single-conditional fixture)

```yaml
project_name: "ai-agent-research"
project_slug: "ai-agent-research"
container_engine: "docker"
llm_provider: "claude"

capabilities:
  has_ai_features: true
  has_design_system: false
  has_personas: false
  cloud_deployed: false
  production_critical: false
  track_vitality: false
```

Tests a single-conditional case: only ascent-ai-evals enabled, only AI-CONFIG.md generated. Targeted at AI/research project shapes.
