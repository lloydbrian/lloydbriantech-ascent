# Phase 3 Retrospective Plan — v0.4.1

The plan for the Phase 3 retrospective. Captures 5 durable lessons from Phase 3's implementation of 28 project-embedded skills across 8 clusters. Implementation chunks reference this document by section number. Changes during implementation are captured as amendments at the bottom, not by rewriting.

**Scope:** v0.4.1 patch release, matching the v0.3.1 precedent (focused patch adding framework discipline artifacts, not new features).

**Input:** Phase 3 delivery evidence — 9 PRs (#21-#33), PHASE-3-PLAN.md, CHANGELOG v0.4.0 entry, cluster-by-cluster review packets, and the two process leaks identified in Cluster 9 (INTENT-MAP consolidation gap, ASCENT-INVARIANTS §15 catch-up).

---

## Section 1 — Lesson inventory

| # | Lesson | Phase 3 evidence | Output artifact(s) | Est. lines | Chunk |
|---|---|---|---|---|---|
| 1 | Cluster-based PR discipline | Clusters 1-8 each shipped as single reviewed PR with test + validator + review packet | CONTRIBUTING.md new section | 60-80 | 2 |
| 2 | Four architectural patterns | Sibling (C4), hybrid (C6), detect-don't-ask (C5), enumerate/summarize (C4→C7→C8) | patterns.md reference module + PRINCIPLES.md pointer + PRINCIPLES table row | 150-200 + 5 + 1 | 1 + 2 |
| 3 | Process-leak class (cross-cutting artifact drift) | INTENT-MAP missed across C1-C8; ASCENT-INVARIANTS §15 missed in v0.3.1 | CONTRIBUTING.md section + qa-claimed-vs-actual validator | 30-40 + 80-120 | 2 |
| 4 | Behavior verification via mechanical stand-ins | 28 tests using controlled fixtures + stand-in functions; Cluster 2 rework established the anti-pattern boundary | Principle §16 + ASCENT-INVARIANTS §16 + README badge | 20 + 25 + 1 | 2 + 3 |
| 5 | Phase-plan discipline | PHASE-3-PLAN.md served as durable reference across 8 clusters; chunks referenced it by section number; the retro itself uses the discipline | CONTRIBUTING.md section | 30-40 | 2 |

**Reconciliation:** 5 lessons, each producing 1-3 artifacts, landing across chunks 1-3. Chunk 0 is this plan. Chunk 3 is the closing chunk (CHANGELOG, ROADMAP, version bump, tag).

---

## Section 2 — Output artifact catalog

| # | Artifact | Path | Type | Est. lines | Chunk |
|---|---|---|---|---|---|
| 1 | Retrospective narrative | `docs/framework/RETROSPECTIVES/PHASE-3.md` | NEW DIR + NEW FILE | 350-450 | 1 |
| 2 | Patterns reference module | `skills/lloydbriantech-ascent/references/patterns.md` | NEW FILE | 150-200 | 1 |
| 3 | PRINCIPLES pointer to patterns | `docs/framework/PRINCIPLES.md` | SURGICAL EDIT | 1-2 sentences | 1 |
| 4 | Principle §16 | `docs/framework/PRINCIPLES.md` | ADDITIVE EDIT (new section) | ~20 lines | 2 |
| 5 | PRINCIPLES relate-to-framework table row | `docs/framework/PRINCIPLES.md` | SURGICAL EDIT | 1 row | 2 |
| 6 | ASCENT-INVARIANTS §16 | `skills/lloydbriantech-ascent/references/ASCENT-INVARIANTS.md` | ADDITIVE EDIT (new section) | ~25 lines | 2 |
| 7 | README badge (principles count) | `README.md` | SURGICAL EDIT | 1 line | 3 |
| 8 | CONTRIBUTING — cluster discipline | `CONTRIBUTING.md` | NEW SECTION | 60-80 | 2 |
| 9 | CONTRIBUTING — cross-cutting verification | `CONTRIBUTING.md` | NEW SECTION | 30-40 | 2 |
| 10 | CONTRIBUTING — phase-plan discipline | `CONTRIBUTING.md` | NEW SECTION | 30-40 | 2 |
| 11 | qa-claimed-vs-actual validator | `make/qa-claimed-vs-actual.sh` | NEW FILE | 80-120 | 2 |
| 12 | qa-claimed-vs-actual integration | `make/quality.mk` | SURGICAL EDIT (add target) | ~5 lines | 2 |
| 13 | CHANGELOG v0.4.1 entry | `CHANGELOG.md` | NEW SECTION | ~100 | 3 |
| 14 | ROADMAP v0.4.1 entry | `docs/framework/ROADMAP.md` | NEW SECTION | ~30 | 3 |
| 15 | Version bump | `Makefile` + `skills/lloydbriantech-ascent/SKILL.md` | SURGICAL EDIT | 2 lines | 3 |
| 16 | Self-test appendix | This file (`PHASE-3-RETRO-PLAN.md`) | APPENDIX | ~20 | 3 |

**Reconciliation:** 16 artifact entries across 3 implementation chunks (chunks 1-3). Chunk 0 produces this plan only.

---

## Section 3 — Lesson-by-lesson design decisions

### Lesson 1 — Cluster-based PR discipline

**Question resolved:** How to formalize the cluster-based workflow that emerged in Phase 3 so future phases inherit the discipline without re-discovering it.

**Artifact:** New section in `CONTRIBUTING.md` titled "Cluster-based contribution discipline" (~60-80 lines). Covers: what a cluster is (a group of related skills or artifacts shipped as a single reviewed PR), what a review packet contains (verbatim file content, validator outputs, confirmations checklist), and the pre-push spot-check discipline (run validators, run tests locally, export to /tmp AFTER amend).

**What this lesson does NOT prescribe:** Cluster size, skill count per cluster, exact PR description format. The discipline is about flow (propose → approve → implement → review packet → push), not about granularity. Phase 4 clusters may be larger or smaller than Phase 3 clusters.

### Lesson 2 — Four architectural patterns

**Question resolved:** Where the four patterns live as durable framework knowledge — not just in CHANGELOG v0.4.0's Decided section, but as a reference module that the parent skill can consult when routing to roles that design skill interactions.

**Artifact:** New reference module `skills/lloydbriantech-ascent/references/patterns.md` (~150-200 lines). Documents each pattern with: definition, when to use, concrete Phase 3 examples (named skills), and when NOT to use. Also a 1-2 sentence pointer in `docs/framework/PRINCIPLES.md` directing readers from the principle about skill interactions to the patterns reference module for the established shapes.

**Why a reference module and not a principle:** Patterns are descriptive shapes that emerged from practice. They describe how skills relate to each other, not what a project must do to be ASCENT-compliant. Principles are invariants; patterns are conventions. A future phase could introduce a fifth pattern without violating any principle.

**What this lesson does NOT prescribe:** That Phase 4 must use these patterns. A new interaction shape in Phase 4 that doesn't fit the four patterns is fine — it becomes a candidate for a fifth pattern, not a violation.

### Lesson 3 — Process-leak class

**Question resolved:** How to prevent cross-cutting artifact drift when multiple PRs touch the same file or when a plan claims an artifact will be updated but the implementation doesn't deliver.

**Two artifacts:**

1. New section in `CONTRIBUTING.md` titled "Cross-cutting artifact verification" (~30-40 lines). Names the specific files that are cross-cutting (INTENT-MAP.md, ASCENT-INVARIANTS.md, README skill counts, CHANGELOG) and requires a diff-check against the plan before each PR's pre-push spot-check.

2. New validator `make/qa-claimed-vs-actual.sh` (~80-120 lines). Structural-only: given a plan file path, extracts claimed artifact paths (from tables matching the Section 2 format) and verifies each path exists in the repo. Does not verify content — only that the file was created or modified. Wired into `make/quality.mk` as `make qa-claimed-vs-actual PLAN=<path>`.

**Why structural-only:** Semantic verification (did the file change match the plan's intent?) requires parsing natural-language descriptions against file diffs — beyond the scope of a bash validator. Structural verification (does the file exist?) catches the class of leak where a plan claims an artifact and the implementation never touches it. This was the exact failure mode in Phase 3's INTENT-MAP gap.

**What this lesson does NOT prescribe:** That every PR must run the validator. The validator is a tool for closing-chunk verification — run it when the plan claims all artifacts are delivered. Per-cluster PRs can use it optionally.

### Lesson 4 — Behavior verification via mechanical stand-ins

**Question resolved:** Whether the testing discipline that emerged in Phase 3 (mechanical stand-ins, controlled fixtures, no documentation-grep) rises to the level of a framework principle.

**Artifact:** New Principle §16 in `docs/framework/PRINCIPLES.md` (~20 lines). Corresponding §16 section in `skills/lloydbriantech-ascent/references/ASCENT-INVARIANTS.md` (~25 lines). Separate table-row addition to the "How the principles relate to the framework" table in PRINCIPLES.md. README badge update (15 → 16 principles) in the closing chunk.

**Principle statement (draft, refined in Chunk 2):**

Statement: "Tests verify behavior through mechanical stand-ins and controlled fixtures, asserting on what the code actually produces rather than on what the documentation claims."

Why: "A test that passes because the SKILL.md contains the right keywords — rather than because the logic produces the right output — is not actually testing anything. Documentation-grep tests are tautological and mask real defects when implementation drifts from documentation."

**Why a principle and not just a convention:** The discipline was load-bearing throughout Phase 3. Cluster 2's rework (standup, delivery-status, feature-intake tests rewritten from documentation-grep to mechanical stand-ins) established the boundary. Every subsequent cluster honored it. The discipline prevented a class of false-positive tests that would have masked real logic errors. This meets the bar for an invariant: if a scaffolded project breaks this rule, its test suite is unreliable.

**What this lesson does NOT prescribe:** A specific test framework (bash, Vitest, or other). The principle is about verification intent (behavior, not documentation), not implementation tool.

### Lesson 5 — Phase-plan discipline

**Question resolved:** Whether the PHASE-3-PLAN.md practice (durable plan committed first, chunks reference by section number, amendments appended not rewritten) should be formalized for future phases.

**Artifact:** New section in `CONTRIBUTING.md` titled "Phase-plan discipline" (~30-40 lines). Describes the practice: commit the plan before implementation, reference it by section number in PRs, append amendments rather than rewriting. Notes that the Phase 3 retro itself dogfoods this discipline as a self-test.

**What this lesson does NOT prescribe:** Plan length or structure. Phase 4's plan may be lighter than Phase 3's plan if the work is more design-driven and less inventory-driven. The discipline is about committing a plan and referencing it durably, not about matching a specific template.

**Self-test:** This retro plan (PHASE-3-RETRO-PLAN.md) uses the discipline. The Chunk 3 closing chunk records whether the plan-discipline approach worked at smaller scope as a self-test appendix.

---

## Section 4 — Chunk plan

### Chunk 0 — Planning

**Scope:** This document (`docs/framework/PHASE-3-RETRO-PLAN.md`).

**Exit criteria:**
- [ ] PHASE-3-RETRO-PLAN.md reviewed and merged to main

### Chunk 1 — Narrative + patterns

**Scope:** Retrospective narrative (`docs/framework/RETROSPECTIVES/PHASE-3.md`) + patterns reference module (`skills/lloydbriantech-ascent/references/patterns.md`) + PRINCIPLES.md pointer sentence.

**Dependencies:** Chunk 0 (plan committed).

**Exit criteria:**
- [ ] `docs/framework/RETROSPECTIVES/` directory created
- [ ] `RETROSPECTIVES/PHASE-3.md` exists with all 5 lessons narrated
- [ ] `references/patterns.md` exists with 4 patterns documented
- [ ] `PRINCIPLES.md` contains pointer to patterns.md
- [ ] `make qa-links` validates all new cross-references

### Chunk 2 — Discipline + principle + validator

**Scope:** 3 CONTRIBUTING.md sections + Principle §16 in PRINCIPLES.md + PRINCIPLES table row + ASCENT-INVARIANTS §16 + qa-claimed-vs-actual validator + quality.mk wire-up.

**Dependencies:** Chunk 1 (narrative references patterns; CONTRIBUTING sections reference narrative).

**Exit criteria:**
- [ ] CONTRIBUTING.md has 3 new sections (cluster discipline, cross-cutting verification, phase-plan discipline)
- [ ] PRINCIPLES.md has §16 (behavior verification) + table row
- [ ] ASCENT-INVARIANTS.md has §16 section ("sixteen" wording)
- [ ] `make/qa-claimed-vs-actual.sh` exists and runs
- [ ] `make qa-claimed-vs-actual PLAN=docs/framework/PHASE-3-RETRO-PLAN.md` produces expected output
- [ ] All validators green

### Chunk 3 — Closing

**Scope:** CHANGELOG v0.4.1 entry + ROADMAP v0.4.1 entry + version bump (0.4.0 → 0.4.1) + README badge (15 → 16 principles) + self-test appendix on this plan + tag v0.4.1.

**Dependencies:** Chunks 1-2 (all content artifacts committed).

**Exit criteria:**
- [ ] CHANGELOG v0.4.1 entry documents all 5 lessons and their artifacts
- [ ] ROADMAP has v0.4.1 entry between Phase 3 ✅ and Phase 4 ⏸️
- [ ] Version 0.4.1 in Makefile + SKILL.md
- [ ] README badge: principles-16
- [ ] Self-test appendix appended to this plan
- [ ] All validators green
- [ ] Tag v0.4.1 pushed; release workflow fires

---

## Section 5 — Exit criteria for v0.4.1

All criteria are mechanically verifiable:

- [ ] `docs/framework/RETROSPECTIVES/PHASE-3.md` exists with all 5 lessons
- [ ] `skills/lloydbriantech-ascent/references/patterns.md` exists with 4 patterns and concrete Phase 3 examples
- [ ] `docs/framework/PRINCIPLES.md` has 16 principles (§16 added) + table row for §16
- [ ] README badge shows `principles-16`
- [ ] `skills/lloydbriantech-ascent/references/ASCENT-INVARIANTS.md` updated to "sixteen" + §16 section
- [ ] `CONTRIBUTING.md` has 3 new sections (cluster discipline, cross-cutting verification, phase-plan discipline)
- [ ] `make qa-claimed-vs-actual` validator exists and runs against this plan file
- [ ] `CHANGELOG.md` has v0.4.1 entry
- [ ] `docs/framework/ROADMAP.md` has v0.4.1 entry
- [ ] Version 0.4.1 in `Makefile` + `skills/lloydbriantech-ascent/SKILL.md`
- [ ] All validators green; v0.4.1 tag pushed; release fires
- [ ] Self-test appendix records whether the plan-discipline approach worked at retro scope

---

## Section 6 — Out of scope for v0.4.1

**Phase 4 work.** v0.4.1 closes Phase 3 lessons. Phase 4 opens against the v0.4.1 baseline with a separate "Proceed with Phase 4" signal. No Phase 4 design or implementation in this release.

**Semantic validator extensions for qa-claimed-vs-actual.** The validator checks structural existence (does the file exist?), not semantic correctness (does the file's content match the plan's description?). Semantic checking requires natural-language-to-diff matching — deferred to v0.4.x or later if the structural check proves insufficient.

**Per-skill design retrospectives.** This retro operates at the phase level (5 lessons across 28 skills). Per-skill retros (e.g., "was ascent-health's stance ladder the right abstraction?") can land in v0.4.x hardening if specific skills need design revisits.

**PHASE-3-PLAN.md amendments.** The Phase 3 plan is a closed historical document. This retro references it as evidence but does not modify it. Amendments go in this retro plan, not in the Phase 3 plan.

---

*This document is the durable record of the Phase 3 retrospective's design decisions. Implementation chunks reference it by section number. Changes during implementation are captured as amendments at the bottom of this document, not by rewriting the original plan.*

---

## Appendix — Self-test observations

Added as part of Chunk 3 closing (May 21, 2026). Records what the plan-discipline approach revealed when applied at retrospective scope (~196-line plan, 3 implementation chunks, 4 PRs) versus the Phase 3 implementation scope (~500-line plan, 8 implementation clusters, 9 PRs).

### Observation 1 — Line-count estimates over-projected

The plan estimated PHASE-3.md (retrospective narrative) at 350-450 lines; actual landed at 167 lines (~45% of estimate). The plan estimated patterns.md at 180-200 lines; actual landed at 124 lines (~65% of estimate). Both artifacts are substantively complete — approved in review before implementation. The estimates over-projected because the prose was denser than anticipated; each paragraph carried more content per line than the estimate assumed.

**Lesson for Phase 4:** Anchor plan estimates on substantive completeness (does the artifact contain the required sections with real content?), not line-count targets. Line counts are useful for scoping work effort but should not be quality gates.

### Observation 2 — Plan-path discrepancy class

PHASE-3-RETRO-PLAN.md §2 artifact #12 specified destination `make/quality.mk`. The actual destination is `make/qa.mk` — the file where existing qa-skill-frontmatter, qa-links, and qa-template-placeholders targets live. The qa-claimed-vs-actual validator caught this as 1 FAIL in Chunk 2's first run.

The plan's original text is preserved per the "append amendments, never rewrite" discipline. The FAIL is honest: the plan's path was wrong; the actual file is at `make/qa.mk`; this appendix documents the gap.

**Lesson for Phase 4:** When a plan references a specific file path, verify the path exists in the repo before committing the plan. The qa-claimed-vs-actual validator can catch this class of gap — run it against the plan as a pre-merge check for Chunk 0 (planning), not just Chunk N (closing).

### Observation 3 — Structural-only validator limitation confirmed

At end of Chunk 2, the qa-claimed-vs-actual validator reported 14 PASS / 1 FAIL / 1 SKIP. Four of the 14 PASS results were for files that existed on main but had not yet received their Chunk 3 content edits (README.md badge, CHANGELOG.md v0.4.1 entry, ROADMAP.md v0.4.1 entry, Makefile + SKILL.md version bump). The validator correctly reported file-existence; it did not (and cannot) verify that the specific content edit claimed in the plan had landed.

This is the structural-vs-semantic constraint working exactly as specified in §3 Lesson 3. The validator catches "file claimed in plan but absent in repo" (the INTENT-MAP class). It does not catch "file exists but content edit is missing."

**Lesson for Phase 4:** Structural verification is necessary but not sufficient. The closing-chunk human PR review becomes the de-facto semantic check — eyeballing whether the README badge changed, the CHANGELOG has its entry, the version string updated. For Phase 4, build the closing-chunk review with this division of labor in mind: qa-claimed-vs-actual catches the absent-file class; the human reviewer catches the absent-content class. Each is necessary; neither alone is sufficient.

### Observation 4 — Chunk-size variance was self-correcting

The plan estimated Chunk 1 at the largest volume (narrative + patterns: ~530-650 lines), Chunk 2 at moderate volume (~250-350 lines), and Chunk 3 at smallest (~150 lines). Actual insertions per PR:

- Chunk 1 (PR #35): 293 insertions (3 files: PHASE-3.md 167, patterns.md 124, PRINCIPLES.md +2)
- Chunk 2 (PR #36): 177 insertions (5 files)
- Chunk 3 (this PR): ~150 lines estimated

Chunks 1 and 2 came in 45-50% under their estimates. Yet Chunk 3 (the closing chunk) maintains roughly its planned size because closing-chunk work is constrained by fixed-shape artifacts (CHANGELOG entry, ROADMAP entry, badge, version bump, appendix) — there is a natural floor to what those artifacts must contain regardless of how concise the prose is.

**Lesson for Phase 4:** Implementation chunks have flexible line-count floors (substantive completeness governs); closing chunks have rigid line-count shapes (fixed-shape artifacts dictate volume). Plan estimates should reflect this asymmetry — loose ranges for implementation, tighter targets for closing.
