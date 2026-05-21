# Phase 3 Retrospective

> What Phase 3 teaches the ASCENT framework about building and shipping 28 project-embedded skills across 8 implementation clusters. This document captures the 5 durable lessons — not as summaries of what happened (the CHANGELOG v0.4.0 entry covers that) or as the original plan (PHASE-3-PLAN.md covers that), but as the design reasoning that turns experience into framework artifacts.
>
> Audience: framework contributors and future-phase planners. Read this before designing Phase 4's implementation chunks.

## The work that shipped

Phase 3 implements all 28 project-embedded skills that ship with every ASCENT-scaffolded project. The work spans 8 implementation clusters (Clusters 1-8), each delivered as a single reviewed PR between May 18 and May 20, 2026. Clusters 1-8 correspond to Foundation, Delivery, Authoring, Health checks, Lifecycle, Quality gates, Security/cost, and Advanced conditional respectively — see [`PHASE-3-PLAN.md`](../PHASE-3-PLAN.md) §3 for cluster definitions. A planning chunk (Cluster 0) and a closing chunk (Cluster 9) bookend the implementation work. The release ships as v0.4.0.

The 28 skills break into two tiers: 14 baseline-deep (~200-250 lines each, full decision trees in operational logic) and 14 specialized-lean (~100-150 lines each, substantive but less exhaustive). Every skill has a corresponding bash test script that verifies behavior through controlled fixtures and mechanical stand-in functions.

## What this document captures

Five lessons emerge from Phase 3 that are durable enough to become framework artifacts. Each lesson section follows the same structure: how the lesson emerges in the narrative, where it almost goes wrong (if applicable), and what it establishes for the framework going forward.

The lessons are not ranked by importance. Each is load-bearing in a different way — cluster discipline structures the workflow; patterns structure the design space; process-leak detection prevents drift; behavior verification prevents false confidence; phase-plan discipline prevents re-litigation.

---

## Lesson 1 — Cluster-based PR discipline

### How it emerges

Phase 3 faces a problem on Day 1: 28 skills cannot ship in one PR. The PHASE-3-PLAN.md breaks the work into 8 clusters based on dependency order and conceptual grouping — Foundation first (because everything depends on self-audit), then Delivery, Authoring, Health checks, Lifecycle, Quality gates, Security/cost, and Advanced conditional.

Each cluster ships as a single PR. The PR is not just code — it carries a review packet: verbatim file content for every SKILL.md and test script, validator outputs, and a confirmations checklist that names every design decision by letter (Decision A, Decision B, etc.). The review packet discipline means the reviewer reads the actual artifact, not a summary of it.

### How it works across 8 clusters

The workflow stabilizes by Cluster 2: propose decisions → get approval → implement → ship review packet with verbatim content → reviewer spot-checks specific sections → push. The proposal-then-implementation split prevents wasted work — a rejected design decision costs one message, not one implementation.

By Cluster 4, the pre-push spot-check becomes formalized: run all three validators (`qa-skill-frontmatter`, `qa-links`, `qa-template-placeholders`), run the new cluster's tests locally, export files to `/tmp/ClaudeCodeResponses/` AFTER the final amend (not before — a lesson from Cluster 2's stale-file incident). By Cluster 6, the spot-check is muscle memory.

### Where it almost breaks

The discipline holds for skill content but breaks for cross-cutting artifacts. Each cluster's proposal states that INTENT-MAP.md will gain rows for the new skills. None of the 8 implementation PRs actually update INTENT-MAP.md. The gap is invisible until Cluster 9's closing chunk, which discovers that INTENT-MAP.md is unchanged since v0.3.1. The consolidation produces the correct end-state, but the process discipline of including cross-cutting updates in each cluster's PR fails silently across all 8 clusters. This is the gap Lesson 3 addresses.

### What this establishes

The cluster-based PR discipline — propose → approve → implement → review packet → push — becomes a `CONTRIBUTING.md` section for future phases. The discipline is about flow, not granularity. Phase 4 clusters may be larger or smaller. The review packet format (verbatim content, validator outputs, confirmations) is the durable artifact; the cluster size is variable.

---

## Lesson 2 — Four architectural patterns

### Sibling pattern (Cluster 4)

Cluster 4 introduces the first design question that recurs across subsequent clusters: when two skills check overlapping domains, do they invoke each other at runtime (component pattern) or read the same project sources independently (sibling pattern)?

The answer in Cluster 4 is sibling. `ascent-adr-conformance` and `ascent-skills-doctor` both overlap with `ascent-self-audit`'s domain, but they operate independently. Self-audit provides the structural gate (§7 ADR discipline check); adr-conformance provides deeper analysis invoked separately. Neither calls the other at runtime. The relationship is documented in each skill's opening prose.

The sibling pattern holds through Cluster 5 (reflect, handoff, and onboard share §15 artifacts without invoking each other) and Cluster 7 (security-audit and sec-posture enumerate and summarize respectively without runtime coupling).

### Hybrid pattern (Cluster 6)

Cluster 6 introduces a different shape. `ascent-qa` is an aggregator — its purpose is to roll up quality signals from across the project. Three options are on the table: qa invokes sub-skills at runtime (component), qa duplicates sub-skill logic (pure sibling), or qa runs lightweight surface checks and conditionally recommends deeper sub-skills (hybrid).

The hybrid pattern wins for three reasons: it preserves the sibling precedent (no runtime invocation), it keeps qa lean (a specialized-lean skill cannot meaningfully orchestrate 10+ sub-skills), and it avoids result drift (qa's conclusions do not diverge from sub-skills' conclusions because qa does not compute deep conclusions). The conditional recommendation format — recommendations appear only when surface checks flag concerns — keeps the output actionable rather than noisy.

### Detect-don't-ask (Cluster 5)

`ascent-onboard` needs to know the developer's context: are they new to the project, new to ASCENT, or new to both? The design could prompt the developer to self-identify, but the detect-don't-ask pattern emerges instead: infer context from project state. If `working-memory.md` has entries and `PHASE-PLAN.md` has checked items, the project is established. If both are empty, it is a fresh scaffold. The developer never sees the question.

The pattern reinforces in Cluster 6: `ascent-release-readiness` detects whether it runs in the meta-repo or a scaffolded project by checking for `.ascent-meta.json` presence, adapting its version-field checks accordingly.

### Enumerate/summarize sub-pattern (Clusters 4, 7, 8)

A sub-pattern of the sibling pattern emerges across three clusters. In Cluster 4, `ascent-adr-conformance` enumerates specific ADR findings while `ascent-self-audit`'s §7 check summarizes at the gate level. In Cluster 7, `ascent-security-audit` enumerates point-in-time security findings while `ascent-sec-posture` summarizes the overall security stance.

Cluster 8 generalizes the pattern from 1:1 fan-in to 1:4 fan-in: `ascent-health` summarizes stance across four Cluster 4 enumerators. The abstraction distinction is made explicit in ascent-health's opening prose: health produces stance-level signals, not detailed findings; enumerators remain the canonical source for detailed enumeration. A future contributor should not copy enumerator logic into health — the two layers are different abstractions over the same sources.

### What this establishes

The four patterns become a reference module ([`patterns.md`](../../../skills/lloydbriantech-ascent/references/patterns.md)) in the parent skill's reference directory. Patterns are descriptive conventions that emerge from practice — they describe how skills relate to each other, not what a project must do. A future phase introducing a fifth pattern extends the library rather than violating it.

---

## Lesson 3 — Process-leak class

### The INTENT-MAP gap

Every Cluster 1-8 proposal states that INTENT-MAP.md will be updated with rows for the new skills. Every implementation PR ships without the INTENT-MAP update. The gap compounds across 8 PRs. By Cluster 9, INTENT-MAP.md is unchanged from v0.3.1 — a 9-row table that should be a 28-row table.

The root cause is not carelessness. The cluster implementation workflow focuses on SKILL.md files and test scripts — the artifacts that validators check. INTENT-MAP.md is a cross-cutting artifact that no validator tracks. The pre-push spot-check runs `qa-skill-frontmatter`, `qa-links`, and `qa-template-placeholders` — none of which flag an out-of-date INTENT-MAP.

Cluster 9's consolidation produces the correct end-state (a single 28-row table with sharpened intent phrasings), but the honest record is that the process discipline fails for cross-cutting artifacts.

### The ASCENT-INVARIANTS §15 catch-up

A second instance of the same class: v0.3.1 introduces Principle §15 (session resumption), but `ASCENT-INVARIANTS.md` — the reference module that restates all principles for runtime use — is not updated. The file continues to say "fourteen invariants" when there are fifteen. The gap persists through the entirety of Phase 3 and is caught only in Cluster 9's spot-check.

### Why structural verification, not semantic

The response to the process-leak class is a validator (`make qa-claimed-vs-actual`) that checks whether artifacts claimed in a plan file actually exist in the repo. The validator is structural-only — it confirms file existence, not content correctness. Semantic verification (did the file's content match the plan's intent?) requires parsing natural-language descriptions against file diffs, which is beyond the scope of a bash validator.

Structural verification catches the specific failure mode observed: a plan claims an artifact will be updated, and the implementation never touches it.

### What this establishes

Two artifacts: a `CONTRIBUTING.md` section naming the cross-cutting files that need verification against the plan before each closing chunk, and a `make qa-claimed-vs-actual` validator that mechanically checks claimed-artifact existence. The validator is a tool for closing-chunk verification, not a per-PR gate.

---

## Lesson 4 — Behavior verification via mechanical stand-ins

### The Cluster 2 rework

Cluster 2 (Delivery) ships its first draft with tests that verify skill behavior by grepping the SKILL.md file for expected keywords. The standup test checks whether the SKILL.md mentions "24-hour window." The delivery-status test checks whether the SKILL.md mentions "FRESH" and "STALE." These tests pass — but they test documentation, not behavior. If the SKILL.md wording changes and the logic stays the same, the tests break. If the logic changes and the SKILL.md wording stays the same, the tests pass falsely.

The review catches this: the tests verify "did Claude Code write the words" rather than "does the logic actually work." Tests must construct fixtures with controlled state, then invoke a mechanical stand-in for the skill's logic and assert on its output.

The rework introduces mechanical stand-ins: `classify_file()` reimplements the four-state classification protocol from `session-protocol.md`. `classify_session()` reimplements delivery-status's Step 2 logic. Each stand-in function takes controlled fixture input and produces testable output. The tests assert on the stand-in's behavior, not on the SKILL.md's prose.

### The Cluster 8 composite_stance() catch

In Cluster 8, the `ascent-health` skill defines a composite stance classification with four levels: Strong, Partial, Moderate, Weak. The test implements the same classification logic as a `composite_stance()` stand-in function. During review, walking the stand-in's logic for the "2 strong + 2 not-assessed" scenario reveals that the "Partial" stance is unreachable — the code paths for Moderate and Partial overlap, and Moderate always wins.

The fix sharpens the definitions to be mutually exclusive and reorders the evaluation: weak → moderate → strong → partial. The test then strictly asserts "partial" for the empty-sub-domain scenario instead of accepting either "moderate or partial." This is a concrete instance of the principle working: the mechanical stand-in catches a logic bug that documentation-grep misses entirely.

### Why this rises to principle

The discipline prevents a class of false-positive tests that give confidence without actually verifying behavior. Every subsequent cluster after Cluster 2 honors the discipline without re-litigation. The discipline is framework-level, not project-specific: any scaffolded project's test suite is unreliable if it verifies documentation rather than behavior.

### What this establishes

A new framework principle (§16) stating that tests verify behavior through mechanical stand-ins and controlled fixtures, asserting on what the code produces rather than on what the documentation claims. The principle does not prescribe a test framework — bash, Vitest, or any other runner can implement the discipline. The principle is about verification intent, not implementation tool.

---

## Lesson 5 — Phase-plan discipline

### How PHASE-3-PLAN.md holds across 8 clusters

PHASE-3-PLAN.md (~500 lines) commits before any implementation begins. Every implementation cluster references it by section number: "Per PHASE-3-PLAN.md §4, bash tests with trap-based cleanup." "Per §6 Cluster 4 scope, ~920 lines estimated." The plan is the durable anchor — when a design question arises mid-cluster, the answer is either in the plan or requires an explicit amendment.

The plan is never rewritten during implementation. Adjustments (like the scope expanding from "22 skills" in the plan to "28 skills" in the final inventory) land in context, not as edits to the original estimates. The plan's numbers serve as a comparison baseline, not as a contract.

### The dogfooding test

This retrospective applies the same discipline at smaller scope. PHASE-3-RETRO-PLAN.md (~200 lines) commits before any retrospective content is written. Chunks 1-3 reference it by section number. The Chunk 3 self-test appendix records whether the discipline generalizes from phase-scale (~500 lines, 8 clusters, 9 PRs) to retro-scale (~200 lines, 3 chunks, 3-4 PRs).

### What this establishes

A `CONTRIBUTING.md` section formalizing the practice: commit the plan before implementation, reference it by section number in PRs, append amendments rather than rewriting. The discipline does not prescribe plan length or structure — Phase 4's plan may be lighter than Phase 3's. The discipline is about committing a durable reference and working against it, not about matching a template.

---

## Cross-cutting observations

**Pattern emergence is retrospective, not designed.** None of the four patterns are named in PHASE-3-PLAN.md. The sibling pattern gets its name in Cluster 4's proposal; the hybrid pattern in Cluster 6's. The patterns emerge from specific design decisions and are recognized as recurring shapes only after multiple clusters apply them. This is the natural order — design first, name second.

**The lean-tier calibration matters.** Cluster 5's baseline-deep skills land at 180-194 lines against a 200-250 target — the floor, not the middle. The observation that lean-tier muscle memory carries over from Cluster 4 leads to explicit guidance: target the middle of the tier range (~125 lines for lean, ~225 for deep), not the floor. Subsequent clusters honor this calibration.

**Validator-driven discipline compounds.** Phase 3 starts with 3 validators (`qa-skill-frontmatter`, `qa-links`, `qa-template-placeholders`). By Phase 3's close, these validators check 29 SKILL.md files, 368 internal links, and 212 placeholder names. The validators do not catch everything (INTENT-MAP drift proves that), but they catch enough that the pre-push spot-check becomes a genuine quality gate rather than a ritual.

## What this retrospective deliberately does not capture

**Per-skill design retrospectives.** Whether `ascent-health`'s stance ladder is the right abstraction, whether `ascent-vitality`'s 14-day commit threshold is too aggressive — these are per-skill design questions that belong in v0.4.x hardening, not in a phase-level retrospective.

**Phase 4 design decisions.** This retrospective closes Phase 3. Phase 4 opens against the v0.4.1 baseline with its own planning discipline. No Phase 4 design work belongs here.

**Quantitative delivery metrics.** Lines shipped, time per cluster, lines per hour — these numbers exist in git history but are not captured here. The retrospective is about durable lessons, not delivery statistics. The CHANGELOG v0.4.0 Statistics section has the numbers for readers who want them.

---

*This retrospective is an artifact of v0.4.1. It references [`PHASE-3-PLAN.md`](../PHASE-3-PLAN.md) as evidence, [`CHANGELOG.md`](../../../CHANGELOG.md) v0.4.0 for delivery record, and [`patterns.md`](../../../skills/lloydbriantech-ascent/references/patterns.md) for the formal pattern definitions it narrates.*
