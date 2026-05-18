# Phase 3 Plan — Project-embedded skills

The blueprint for Phase 3 of the ASCENT framework. Implementation chunks reference this document. v1.0 retrospectives reference this document. Every number here reconciles; every estimate is grounded in Phase 2's actual delivery data.

**Phase 3 goal:** Author the SKILL.md files for all 28 project-embedded skills. Each skill is invocable inside a scaffolded project. When Phase 3 closes, every shipped skill demonstrably does what its operational-logic section claims.

**Version on completion:** v0.4.0

---

## Section 1 — Skill inventory (28 skills)

| # | Skill | Category | Current state | Depth tier | Est. lines (skill + test) | Cluster |
|---|---|---|---|---|---|---|
| 1 | ascent-self-audit | baseline v0.3.0 | scaffold exists (50 lines) | deep | 250 + 80 | 1 |
| 2 | ascent-layering-check | baseline v0.3.0 | scaffold exists (48 lines) | deep | 220 + 70 | 1 |
| 3 | ascent-env-audit | baseline v0.3.0 | scaffold exists (48 lines) | deep | 220 + 70 | 1 |
| 4 | ascent-observability-check | baseline v0.3.0 | scaffold exists (49 lines) | deep | 220 + 70 | 1 |
| 5 | ascent-delivery-status | baseline v0.3.0 | scaffold exists (52 lines) | deep | 230 + 70 | 2 |
| 6 | ascent-feature-intake | baseline v0.3.0 | scaffold exists (50 lines) | deep | 230 + 70 | 2 |
| 7 | ascent-standup | remaining baseline | no artifact | deep | 200 + 60 | 2 |
| 8 | ascent-adr-write | baseline v0.3.0 | scaffold exists (50 lines) | deep | 230 + 70 | 3 |
| 9 | ascent-doc-stub | baseline v0.3.0 | scaffold exists (50 lines) | deep | 220 + 70 | 3 |
| 10 | ascent-make-target | baseline v0.3.0 | scaffold exists (52 lines) | deep | 220 + 70 | 3 |
| 11 | ascent-reflect | remaining baseline | no artifact | deep | 200 + 60 | 5 |
| 12 | ascent-handoff | remaining baseline | no artifact | deep | 200 + 60 | 5 |
| 13 | ascent-onboard | remaining baseline | no artifact | deep | 200 + 60 | 5 |
| 14 | ascent-health | remaining baseline | no artifact | deep | 200 + 60 | 8 |
| 15 | ascent-data-health | specialized | no artifact | lean | 130 + 50 | 4 |
| 16 | ascent-doc-sweep | specialized | no artifact | lean | 130 + 50 | 4 |
| 17 | ascent-dependency-health | specialized | no artifact | lean | 130 + 50 | 4 |
| 18 | ascent-adr-conformance | specialized | no artifact | lean | 130 + 50 | 4 |
| 19 | ascent-skills-doctor | specialized | no artifact | lean | 140 + 60 | 4 |
| 20 | ascent-qa | specialized | no artifact | lean | 130 + 50 | 6 |
| 21 | ascent-release-readiness | specialized | no artifact | lean | 140 + 60 | 6 |
| 22 | ascent-security-audit | conditional | no artifact | lean | 120 + 50 | 7 |
| 23 | ascent-sec-posture | conditional | no artifact | lean | 120 + 50 | 7 |
| 24 | ascent-cost-posture | conditional | no artifact | lean | 120 + 50 | 7 |
| 25 | ascent-vitality | conditional | no artifact | lean | 120 + 50 | 7 |
| 26 | ascent-ai-evals | conditional | no artifact | lean | 130 + 50 | 8 |
| 27 | ascent-design-system-audit | conditional | no artifact | lean | 120 + 50 | 8 |
| 28 | ascent-persona-coverage | conditional | no artifact | lean | 120 + 50 | 8 |

**Category reconciliation:** 9 (baseline v0.3.0) + 5 (remaining baseline) + 7 (specialized) + 7 (conditional) = **28 skills**.

**Tier reconciliation:** 14 (baseline-deep: skills 1-14) + 14 (specialized-lean: skills 15-28) = **28 skills**.

**Starting state:** 9 scaffolds exist and need expansion (operational-logic paragraph → multi-paragraph decision tree). 19 skills have no artifact and need both scaffolding and implementation.

---

## Section 2 — Implementation depth tiers

### Baseline-deep tier (14 skills)

**Target:** 200-250 lines per skill SKILL.md. The 9 v0.3.0 scaffolds provide section structure; the operational-logic paragraph is the primary expansion target.

**Section structure and length expectations:**

| Section | Length | "Implementation complete" means |
|---|---|---|
| Frontmatter | ~12 lines | name, description, version, allowed-tools — all complete and accurate |
| Header + When this skill engages | ~15 lines | 1-2 sentence description + 4-6 trigger conditions with context |
| Inputs | ~8 lines | Every input named with type, source, and optionality |
| Outputs | ~10 lines | Every output artifact named with format and destination |
| Operational logic | ~80-100 lines | Multi-paragraph decision tree. Each decision point names the condition, the action, and the fallback. The logic is specific enough that a reader can mentally execute it. |
| Examples | ~40-50 lines | 3-5 concrete examples. Each shows input state → skill action → output. At least one example shows an edge case (empty input, conflicting state). |
| Anti-patterns | ~25-35 lines | 3-5 specific anti-patterns. Each names the failure mode, why it's tempting, and what to do instead. |

**"Scaffold-acceptable" (what the v0.3.0 scaffolds provide):** Frontmatter + header + inputs/outputs + one operational-logic paragraph + examples pointer + one anti-pattern paragraph. ~48-52 lines. This is the Phase 2 starting point, not the Phase 3 end state.

### Specialized-lean tier (14 skills)

**Target:** 100-150 lines per skill SKILL.md. Full scaffolding + implementation but with less exhaustive examples and anti-patterns than baseline-deep.

**Section structure and length expectations:**

| Section | Length | "Implementation complete" means |
|---|---|---|
| Frontmatter | ~12 lines | Same standard as baseline-deep |
| Header + When this skill engages | ~12 lines | 1-2 sentence description + 3-4 trigger conditions |
| Inputs | ~6 lines | Every input named |
| Outputs | ~8 lines | Every output artifact named |
| Operational logic | ~40-60 lines | Substantive decision tree, less exhaustive than baseline-deep. Each major decision point covered; edge-case handling deferred to v0.4.x hardening. |
| Examples | ~15-20 lines | 1-2 concrete examples (primary use case + one edge case) |
| Anti-patterns | ~10-15 lines | 1-2 specific anti-patterns (primary failure mode + one secondary) |

**Hardening deferred to v0.4.x:** Additional examples, edge-case decision branches, adversarial anti-patterns. The lean tier is substantive (not stubs) but not exhaustive.

---

## Section 3 — Cluster definitions

### Cluster 1 — Foundation (4 skills, all baseline-deep)

**Skills:** ascent-self-audit, ascent-layering-check, ascent-env-audit, ascent-observability-check

**Rationale:** The umbrella audit and its three components. Must ship first because every other cluster's tests may invoke `ascent-self-audit` as a validation step.

**Internal dependencies:** ascent-self-audit composes the other three (umbrella → components).

**External dependencies:** None — this is the root of the dependency graph.

**Estimated lines:** 4 skills × ~230 avg + 4 tests × ~73 avg = **920 + 290 = ~1,210 lines**.

### Cluster 2 — Delivery (3 skills, all baseline-deep)

**Skills:** ascent-delivery-status, ascent-feature-intake, ascent-standup

**Rationale:** Phase tracking and daily workflow. ascent-standup depends on delivery-status output. Both delivery-status and feature-intake have §15 session-resumption extensions (v0.3.1 Chunk 3).

**Internal dependencies:** ascent-standup depends on ascent-delivery-status output.

**External dependencies:** Cluster 1 (ascent-self-audit may be invoked as a quality gate).

**Estimated lines:** 3 skills × ~220 avg + 3 tests × ~67 avg = **660 + 200 = ~860 lines**.

### Cluster 3 — Authoring (3 skills, all baseline-deep)

**Skills:** ascent-adr-write, ascent-doc-stub, ascent-make-target

**Rationale:** Skills that produce artifacts (files, targets). Write-capable (allowed-tools includes Write/Edit).

**Internal dependencies:** None between the three.

**External dependencies:** Cluster 1 (ascent-self-audit validates after creation: adr-write hands off to self-audit, make-target hands off to self-audit).

**Estimated lines:** 3 skills × ~223 avg + 3 tests × ~70 avg = **670 + 210 = ~880 lines**.

### Cluster 4 — Health checks (5 skills, all specialized-lean)

**Skills:** ascent-data-health, ascent-dependency-health, ascent-doc-sweep, ascent-adr-conformance, ascent-skills-doctor

**Rationale:** Specialized checks that verify specific concerns (data quality, dependency freshness, doc consistency, ADR format, skill collection integrity). All read-only.

**Internal dependencies:** ascent-skills-doctor may invoke patterns from other health checks.

**External dependencies:** Cluster 1 (ascent-self-audit references health checks as available component checks).

**Estimated lines:** 5 skills × ~132 avg + 5 tests × ~52 avg = **660 + 260 = ~920 lines**.

### Cluster 5 — Lifecycle (3 skills, all baseline-deep)

**Skills:** ascent-reflect, ascent-handoff, ascent-onboard

**Rationale:** Session and developer lifecycle skills. ascent-reflect captures end-of-session state (related to §15 session-snapshot). ascent-handoff documents project state for another developer. ascent-onboard guides a new developer through the project.

**Internal dependencies:** None between the three.

**External dependencies:** Cluster 2 (ascent-delivery-status output feeds into ascent-reflect and ascent-handoff).

**Estimated lines:** 3 skills × ~200 avg + 3 tests × ~60 avg = **600 + 180 = ~780 lines**.

### Cluster 6 — Quality gates (2 skills, both specialized-lean)

**Skills:** ascent-qa, ascent-release-readiness

**Rationale:** Gate skills that compose multiple checks into go/no-go decisions. ascent-release-readiness depends on ascent-qa and ascent-self-audit.

**Internal dependencies:** ascent-release-readiness may invoke ascent-qa.

**External dependencies:** Cluster 1 (ascent-self-audit), Cluster 4 (health checks feed into release-readiness).

**Estimated lines:** 2 skills × ~135 avg + 2 tests × ~55 avg = **270 + 110 = ~380 lines**.

### Cluster 7 — Security/cost conditional (4 skills, all specialized-lean)

**Skills:** ascent-security-audit, ascent-sec-posture, ascent-cost-posture, ascent-vitality

**Rationale:** Conditional skills that ship only when the architect interview selects them. Security and cost posture are closely related; vitality is the project-health meta-skill.

**Internal dependencies:** ascent-sec-posture may reference ascent-security-audit output.

**External dependencies:** Cluster 1 (ascent-self-audit baseline), Cluster 4 (health check patterns).

**Estimated lines:** 4 skills × ~120 avg + 4 tests × ~50 avg = **480 + 200 = ~680 lines**.

### Cluster 8 — Advanced conditional (4 skills: 3 specialized-lean + 1 baseline-deep)

**Skills:** ascent-ai-evals, ascent-design-system-audit, ascent-persona-coverage, ascent-health

**Rationale:** Conditional skills for AI-using projects, design-system projects, and the general health check. ascent-health is baseline-deep (remaining baseline #14) but clustered here because it's a meta-health skill that benefits from all other health checks being implemented first.

**Internal dependencies:** None between the four.

**External dependencies:** Cluster 1 (ascent-self-audit), Cluster 4 (health check patterns), Cluster 6 (ascent-qa gate).

**Estimated lines:** 3 lean skills × ~123 avg + 1 deep skill × ~200 + 4 tests × ~53 avg = **570 + 210 = ~780 lines**.

**Cluster totals:** 1,210 + 860 + 880 + 920 + 780 + 380 + 680 + 780 = **~6,490 lines** across 8 clusters.

---

## Section 4 — Test framework design

### Test location

`assets/template/tests/skills/test-<skill-name>.sh`

Tests ship as template files in the scaffolded project. Every scaffolded project can self-test its skill collection. The directory lives alongside the backend tests at `assets/template/backend/tests/` but in a separate `tests/skills/` tree.

### Test runner choice — bash scripts

**Decision:** Bash scripts, not Vitest.

**Rationale:** Skill tests verify Markdown operational logic against project structure — file existence, content patterns, import graphs, configuration shapes. This is `grep`/`sed`/`jq` territory, not JavaScript unit-test territory. Phase 2 Chunk 8's smoke test (14/14 steps, bash-based) proved the pattern. Vitest remains the runner for backend JavaScript tests; bash is the runner for skill structural tests. Two domains, two runners, one unified `make test-all`.

### Test naming convention

One script per skill: `test-ascent-self-audit.sh`, `test-ascent-layering-check.sh`, etc. Each script is self-contained: sets up fixtures (if needed), runs assertions, reports PASS/FAIL, cleans up.

### Test runner integration

```
make test-skills              — runs all 28 skill tests; reports N/28 PASS
make test-skill SKILL=<name>  — runs one test (e.g., make test-skill SKILL=ascent-env-audit)
make test-all                 — runs test-unit (Vitest) + test-skills (bash) + test-integration + test-e2e
```

`make test-skills` lives in the TEST section of the SDLC-sectioned make tree, alongside `test-unit`, `test-integration`, `test-e2e`.

### Runtime model

Skill tests run from the project root on the host (or inside the container via `make dev-shell`). Most tests inspect static structure (files, patterns, configuration) — no running container needed. Tests that verify runtime behavior (e.g., ascent-observability-check verifying actual log output from a running service) are marked with a `# REQUIRES: dev-up` comment and skip gracefully if containers aren't running.

Per Principle 1, the canonical execution path is inside the container (`make dev-shell` then `make test-skills`). But file-structure tests produce identical results on host or in container because they inspect the same bind-mounted source tree.

### Fixture management

Tests use the project's own structure as the primary fixture. For tests that need specific states (e.g., ascent-adr-conformance testing a project with 0 ADRs, then 47 ADRs), tests create ephemeral state in a `tests/skills/.fixtures/` directory (gitignored) and clean up after each run. Fixture setup is explicit in each test script — no hidden shared state between tests. Tests use `trap` to clean up on exit (including on test failure), not just on successful completion — prevents fixture accumulation when tests fail mid-run.

### Pass/fail reporting

Each test script prints:

```
PASS  ascent-env-audit: .env.example has empty defaults only
PASS  ascent-env-audit: .env listed in .gitignore
FAIL  ascent-env-audit: HELLO_WORLD_APP_PORT read in code but missing from .env.example
```

The runner (`make test-skills`) aggregates:

```
Skills test suite: 27/28 PASS, 1 FAIL
  FAIL: ascent-env-audit (1 assertion failed)
```

### Integration with smoke test

Phase 3's closing chunk extends Phase 2's smoke test (`tools/scratch/scaffold-hello-world.sh`) to also run `make test-skills` after the 14-step verification. The extended smoke test proves: the scaffolded project boots AND its skill tests pass.

---

## Section 5 — Test suite scope

### The 28 tests at a glance

| # | Skill | Test name | Mechanically verifies | Fixture complexity |
|---|---|---|---|---|
| 1 | ascent-self-audit | test-ascent-self-audit.sh | All 14 (now 15) invariant checks compose correctly; PASS/FAIL for each | Medium (needs full project structure) |
| 2 | ascent-layering-check | test-ascent-layering-check.sh | Import graph validates downward-only dependencies across 4 layers | Low (inspects backend/ structure) |
| 3 | ascent-env-audit | test-ascent-env-audit.sh | .env gitignored, .env.example empty defaults, code-reads match schema | Low (inspects config files) |
| 4 | ascent-observability-check | test-ascent-observability-check.sh | Logger emits required fields, /healthz + /readyz exist, lifecycle events present | Low (inspects source patterns) |
| 5 | ascent-delivery-status | test-ascent-delivery-status.sh | Reads .ascent-meta.json phase, synthesizes status from project state | Medium (needs .ascent-meta.json + PHASE-PLAN) |
| 6 | ascent-feature-intake | test-ascent-feature-intake.sh | Decomposes vague input into structured acceptance criteria | Medium (needs PHASE-PLAN fixtures) |
| 7 | ascent-standup | test-ascent-standup.sh | Summarizes recent activity + delivery-status into standup format | Medium (needs git history + delivery state) |
| 8 | ascent-adr-write | test-ascent-adr-write.sh | Creates ADR file with all 5 sections + updates INDEX.md | Medium (needs docs/architecture/decisions/) |
| 9 | ascent-doc-stub | test-ascent-doc-stub.sh | Creates persona-targeted doc with audience-appropriate sections | Low (creates doc file) |
| 10 | ascent-make-target | test-ascent-make-target.sh | Proposes correctly-named target in right .mk file | Low (inspects make/ tree) |
| 11 | ascent-reflect | test-ascent-reflect.sh | Captures session summary with structured sections | Low (writes session state) |
| 12 | ascent-handoff | test-ascent-handoff.sh | Documents project state for another developer | Medium (needs full project context) |
| 13 | ascent-onboard | test-ascent-onboard.sh | Guides new developer through project structure | Medium (needs full project context) |
| 14 | ascent-health | test-ascent-health.sh | Aggregates health signals across all health-check skills | High (needs all health checks available) |
| 15 | ascent-data-health | test-ascent-data-health.sh | Validates schema integrity + migration state + data quality | Low (inspects storage/ structure) |
| 16 | ascent-doc-sweep | test-ascent-doc-sweep.sh | Audits doc consistency: broken links, orphaned docs, persona coverage | Low (inspects docs/ tree) |
| 17 | ascent-dependency-health | test-ascent-dependency-health.sh | Checks dependency freshness + known CVEs | Low (inspects package.json) |
| 18 | ascent-adr-conformance | test-ascent-adr-conformance.sh | Validates all ADRs use canonical template with 5 required sections | Low (inspects ADR files) |
| 19 | ascent-skills-doctor | test-ascent-skills-doctor.sh | Self-checks skill collection: frontmatter valid, INTENT-MAP current | Medium (needs all 28 skills + INTENT-MAP) |
| 20 | ascent-qa | test-ascent-qa.sh | Composes lint + typecheck + structure into composite gate | Low (runs sub-checks) |
| 21 | ascent-release-readiness | test-ascent-release-readiness.sh | Composes qa + self-audit + tests into release gate | Medium (needs test results) |
| 22 | ascent-security-audit | test-ascent-security-audit.sh | Validates auth flows, secret handling, endpoint exposure | Low (inspects security patterns) |
| 23 | ascent-sec-posture | test-ascent-sec-posture.sh | Summarizes security posture for compliance | Low (aggregates security state) |
| 24 | ascent-cost-posture | test-ascent-cost-posture.sh | Reports AI/infra cost signals from logs | Low (inspects log patterns) |
| 25 | ascent-vitality | test-ascent-vitality.sh | Meta-health: project activity, debt indicators, momentum | Medium (needs git history + metrics) |
| 26 | ascent-ai-evals | test-ascent-ai-evals.sh | Validates eval scenario structure + prompt-test coverage | Low (inspects tests/evals/) |
| 27 | ascent-design-system-audit | test-ascent-design-system-audit.sh | Validates design tokens, component consistency, theming | Low (inspects frontend/ patterns) |
| 28 | ascent-persona-coverage | test-ascent-persona-coverage.sh | Validates every persona has entry point + bounded path | Low (inspects doc graph) |

### What the suite proves

**v0.4.0 commits to:** every shipped skill demonstrably does what its operational-logic section claims. Each test mechanically verifies the skill's primary function against a representative project structure.

### What the suite does NOT prove

- **Routing verification** — that Claude reliably invokes the right skill on user prompts. Deferred to real use.
- **Real-use scenarios** — that skills produce useful output for a working developer in a real project. Deferred to Phase 7 (first production project).
- **Performance characteristics** — how long skills take to execute, context budget consumed. Not measured.
- **Adversarial inputs** — malicious or pathologically malformed project state. Lean-tier skills defer edge-case handling to v0.4.x hardening.

---

## Section 6 — Per-cluster scope

### Cluster 1 — Foundation

**Skills:** ascent-self-audit (deep, scaffold exists), ascent-layering-check (deep, scaffold exists), ascent-env-audit (deep, scaffold exists), ascent-observability-check (deep, scaffold exists)

**Work:** Expand 4 existing scaffolds from ~49 lines to ~225 lines each. Primary expansion: operational-logic paragraph → multi-paragraph decision tree with explicit check logic for each invariant/pattern.

**Test plan per skill:**
- ascent-self-audit: test all 15 invariant checks compose; test PASS on healthy project; test FAIL on project with removed Dockerfile (invariant 1 violation)
- ascent-layering-check: test PASS on correct layering; test FAIL on route importing storage; test FAIL on service importing express
- ascent-env-audit: test PASS on correct .env.example; test FAIL on REPLACE_ME placeholder; test FAIL on code-read not in .env.example
- ascent-observability-check: test PASS on correct emission; test FAIL on missing trace_id field; test FAIL on /healthz checking DB

**Estimated chunk size:** ~1,210 lines (skills + tests).

### Cluster 2 — Delivery

**Skills:** ascent-delivery-status (deep, scaffold exists), ascent-feature-intake (deep, scaffold exists), ascent-standup (deep, no artifact)

**Work:** Expand 2 existing scaffolds; scaffold + implement 1 new skill. Both existing scaffolds have §15 session-resumption extensions (v0.3.1). ascent-standup is new and depends on delivery-status output.

**Prerequisites:** Cluster 1 (self-audit as quality gate).

**Test plan per skill:**
- ascent-delivery-status: test reads .ascent-meta.json phase correctly; test synthesizes exit-criteria progress; test reads session-state.md per §15; test handles MISSING/EMPTY/STALE session-state.md and working-memory.md per §15
- ascent-feature-intake: test decomposes vague request into criteria; test writes to working-memory.md per §15; test rejects untestable criteria; test handles MISSING/EMPTY/STALE session-state.md and working-memory.md per §15
- ascent-standup: test summarizes recent git activity; test includes delivery-status output; test handles empty-project gracefully; test handles MISSING/EMPTY/STALE session-state.md and working-memory.md per §15

**Estimated chunk size:** ~860 lines.

### Cluster 3 — Authoring

**Skills:** ascent-adr-write (deep, scaffold exists), ascent-doc-stub (deep, scaffold exists), ascent-make-target (deep, scaffold exists)

**Work:** Expand 3 existing scaffolds. All are write-capable (allowed-tools includes Write/Edit).

**Prerequisites:** Cluster 1 (self-audit validates after authoring).

**Test plan per skill:**
- ascent-adr-write: test assigns correct next number; test creates file with all 5 sections; test updates INDEX.md; test handles supersession
- ascent-doc-stub: test creates doc with correct persona; test section headings match audience; test respects 3-click depth
- ascent-make-target: test proposes correct name; test places in right .mk file; test detects alias collision

**Estimated chunk size:** ~880 lines.

### Cluster 4 — Health checks

**Skills:** ascent-data-health (lean), ascent-dependency-health (lean), ascent-doc-sweep (lean), ascent-adr-conformance (lean), ascent-skills-doctor (lean)

**Work:** Scaffold + implement 5 new skills at lean tier. All read-only specialized checks.

**Prerequisites:** Cluster 1 (health-check pattern established).

**Test plan per skill:**
- ascent-data-health: test validates schema integrity; test detects missing migration
- ascent-dependency-health: test detects outdated package; test detects known CVE pattern
- ascent-doc-sweep: test detects broken internal link; test detects orphaned doc
- ascent-adr-conformance: test validates canonical template; test detects missing Cost implications section
- ascent-skills-doctor: test validates all skill frontmatter; test detects INTENT-MAP mismatch

**Estimated chunk size:** ~920 lines.

### Cluster 5 — Lifecycle

**Skills:** ascent-reflect (deep), ascent-handoff (deep), ascent-onboard (deep)

**Work:** Scaffold + implement 3 new skills at deep tier. Session and developer lifecycle.

**Prerequisites:** Cluster 2 (delivery-status output feeds reflect and handoff).

**Test plan per skill:**
- ascent-reflect: test captures structured session summary; test includes recent decisions; test handles empty-project; test handles MISSING/EMPTY/STALE session-state.md and working-memory.md per §15
- ascent-handoff: test documents project state comprehensively; test includes phase progress; test includes blockers; test handles MISSING/EMPTY/STALE session-state.md and working-memory.md per §15
- ascent-onboard: test guides through project structure; test identifies setup steps; test handles fresh scaffold

**Estimated chunk size:** ~780 lines.

### Cluster 6 — Quality gates

**Skills:** ascent-qa (lean), ascent-release-readiness (lean)

**Work:** Scaffold + implement 2 new skills at lean tier. Composite gate skills.

**Prerequisites:** Cluster 1 (self-audit), Cluster 4 (health checks feed into release-readiness).

**Test plan per skill:**
- ascent-qa: test composes lint + typecheck + structure checks; test reports composite PASS/FAIL
- ascent-release-readiness: test composes qa + self-audit + tests into release gate; test blocks release on failing checks

**Estimated chunk size:** ~380 lines.

### Cluster 7 — Security/cost conditional

**Skills:** ascent-security-audit (lean), ascent-sec-posture (lean), ascent-cost-posture (lean), ascent-vitality (lean)

**Work:** Scaffold + implement 4 new skills at lean tier. Conditional (ship only when architect interview selects them).

**Prerequisites:** Cluster 1 (self-audit baseline), Cluster 4 (health-check patterns).

**Test plan per skill:**
- ascent-security-audit: test validates auth flow patterns; test detects committed .env
- ascent-sec-posture: test summarizes security state; test references threat model
- ascent-cost-posture: test detects cost-logging patterns; test reports missing cost tracking
- ascent-vitality: test aggregates project-health signals; test handles inactive project

**Estimated chunk size:** ~680 lines.

### Cluster 8 — Advanced conditional

**Skills:** ascent-ai-evals (lean), ascent-design-system-audit (lean), ascent-persona-coverage (lean), ascent-health (deep)

**Work:** Scaffold + implement 3 lean + 1 deep. ascent-health is baseline-deep but benefits from all health checks being implemented first.

**Prerequisites:** Cluster 1, Cluster 4, Cluster 6.

**Test plan per skill:**
- ascent-ai-evals: test validates eval scenario structure; test detects untested prompts
- ascent-design-system-audit: test validates token consistency; test detects hardcoded values
- ascent-persona-coverage: test validates persona entry points; test detects orphaned persona
- ascent-health: test aggregates all health signals; test composes sub-checks correctly

**Estimated chunk size:** ~780 lines.

---

## Section 7 — Cross-skill dependency graph

```
ascent-self-audit ──────────── composes ──────────── ascent-layering-check
                   ├─────────── composes ──────────── ascent-env-audit
                   └─────────── composes ──────────── ascent-observability-check

ascent-standup ─────────────── depends on ─────────── ascent-delivery-status
ascent-reflect ─────────────── depends on ─────────── ascent-delivery-status
ascent-handoff ─────────────── depends on ─────────── ascent-delivery-status

ascent-adr-write ───────────── hands off to ────────── ascent-self-audit (post-creation validation)
ascent-make-target ─────────── hands off to ────────── ascent-self-audit (post-creation validation)

ascent-release-readiness ───── depends on ─────────── ascent-qa
                         ───── depends on ─────────── ascent-self-audit

ascent-health ──────────────── aggregates ─────────── ascent-data-health
               ├────────────── aggregates ─────────── ascent-dependency-health
               ├────────────── aggregates ─────────── ascent-doc-sweep
               └────────────── aggregates ─────────── ascent-adr-conformance

ascent-sec-posture ─────────── references ─────────── ascent-security-audit
```

**Implementation order rule:** A skill's dependencies must be implemented before it. Clusters are ordered to respect this: Cluster 1 (no deps) → 2 (depends on 1) → 3 (depends on 1) → 4 (depends on 1) → 5 (depends on 2) → 6 (depends on 1, 4) → 7 (depends on 1, 4) → 8 (depends on 1, 4, 6).

Tests respect dependencies: a dependent skill's test can assume its prerequisite skill's test passes.

---

## Section 8 — Documentation deliverables

Files updated in Phase 3's closing chunk:

| File | Update |
|---|---|
| `CLAUDE.md` (framework) | Phase status: "v0.3.1 complete" → "Phase 3 — Project-embedded skills (complete)" |
| `docs/framework/ROADMAP.md` | Phase 3 ✅ complete; Phase 4 status ⏸️ awaiting signal; current-state line bumped |
| `CHANGELOG.md` | v0.4.0 entry documenting all 28 skills + 28 tests |
| `skills/lloydbriantech-ascent/SKILL.md` | Version bump 0.3.1 → 0.4.0 |
| `Makefile` | Version bump 0.3.1 → 0.4.0 |
| `assets/template/.claude/skills/INTENT-MAP.md` | Expanded from 9-skill table to full 28-skill table with all intent mappings + cadences |
| `assets/template/Makefile` | Add `include make/test-skills.mk` (or add targets to existing test.mk) |
| `assets/template/make/test.mk` | Promote `test-unit` from stub to real (invokes Vitest); add `test-skills` target |
| `skills/lloydbriantech-ascent/references/ASCENT-INVARIANTS.md` | Update "fourteen" → "fifteen" if not already done; add §15 row |
| `make/meta.mk` | Phase status line update |
| `tools/scratch/scaffold-hello-world.sh` | Extend smoke test to run `make test-skills` |
| `assets/template/.gitignore.tmpl` | Add `tests/skills/.fixtures/` to gitignore (test fixture cleanup) |

`test-integration` and `test-e2e` stubs remain stubs in Phase 3; their implementation lands in Phase 5 (Test harness with evals). Phase 3 promotes `test-unit` and adds `test-skills`; it does not expand the integration or e2e test infrastructure.

---

## Section 9 — Exit criteria

All criteria are observable and testable:

- [ ] All 28 skill SKILL.md files exist under `assets/template/.claude/skills/`
- [ ] All 14 baseline-deep skills are ≥200 lines with full decision trees in Operational logic
- [ ] All 14 specialized-lean skills are ≥100 lines with substantive Operational logic
- [ ] All 28 test scripts exist at `assets/template/tests/skills/test-ascent-*.sh`
- [ ] `make test-skills` runs the full suite and reports **28/28 PASS**
- [ ] Phase 3 smoke test passes (extends Phase 2's smoke test to invoke `make test-skills`)
- [ ] All 9 v0.3.0 baseline scaffolds are upgraded from scaffold to implementation
- [ ] Cross-skill dependency graph validated (no broken references between skills)
- [ ] INTENT-MAP.md expanded from 9-skill to 28-skill table
- [ ] `make qa-skill-frontmatter` validates all 28 + 1 (parent) = 29 SKILL.md files
- [ ] `CHANGELOG.md` v0.4.0 entry shipped
- [ ] `v0.4.0` tag pushed and `release.yml` workflow fires successfully

Conditional skill template inclusion mechanism (default-included with architect-interview-gated activation, or scaffolder-selected at scaffold time) is a Phase 4 concern. v0.4.0 ships all 28 skill templates; Phase 4's scaffolder selects which land in scaffolded projects.

---

## Section 10 — Pacing estimate + deferred work

### Per-chunk pacing

| Chunk | Cluster | Skills | Estimated lines | Estimated effort |
|---|---|---|---|---|
| 0 | — | — | ~500 (this document) | Planning |
| 1 | Foundation (C1) | 4 skills + 4 tests | ~1,210 | Largest implementation chunk |
| 2 | Delivery (C2) | 3 skills + 3 tests | ~860 | §15 extensions already seeded |
| 3 | Authoring (C3) | 3 skills + 3 tests | ~880 | Write-capable; ADR creation logic |
| 4 | Health checks (C4) | 5 skills + 5 tests | ~920 | Most skills in one chunk |
| 5 | Lifecycle (C5) | 3 skills + 3 tests | ~780 | New scaffolds (no prior artifacts) |
| 6 | Quality gates (C6) | 2 skills + 2 tests | ~380 | Smallest implementation chunk |
| 7 | Security/cost (C7) | 4 skills + 4 tests | ~680 | Conditional; lean tier |
| 8 | Advanced (C8) | 4 skills + 4 tests | ~780 | Mixed tier (1 deep + 3 lean) |
| 9 | Closing | — | ~200 | CHANGELOG, ROADMAP, tag |

**Total estimated:** ~500 (plan) + ~6,490 (skills + tests) + ~200 (closing) = **~7,190 lines** across 10 chunks (1 planning + 8 implementation + 1 closing).

For pacing context: Phase 2 shipped ~3,500 lines across 9 chunks in roughly 2 days at high cadence. Phase 3 at ~7,190 lines is roughly 2x Phase 2's volume — realistically 4-5 working days at high cadence, 6-8 working days at sustainable cadence. Phase 3 is a substantial multi-day commitment.

### Deferred to v0.4.x

- **Hardening of 14 specialized/conditional skills** — bring lean-tier skills to baseline-deep depth (additional examples, edge-case branches, adversarial anti-patterns)
- **Routing verification** — testing that Claude reliably invokes the right skill on user prompts. Requires real-use observation, not mechanical testing.
- **Performance profiling** — measuring context budget consumed by each skill and the suite as a whole
- **Additional skills surfaced during real use** — Phase 7's first production project will likely identify gaps
- **Automatic skill-test CI integration** — `make test-skills` in the CI pipeline (currently manual/local only)

---

*This document is the durable record of Phase 3's design decisions. Implementation chunks reference it by section number. Changes to the plan during implementation are captured as amendments at the bottom of this document, not by rewriting the original plan.*
