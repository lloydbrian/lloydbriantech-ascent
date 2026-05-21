# patterns

> Recurring interaction shapes that emerged from Phase 3's implementation of 28 project-embedded skills. These are descriptive conventions, not invariants — [PRINCIPLES.md](../../../docs/framework/PRINCIPLES.md) governs what a project must do; this module describes how skills relate to each other in practice.

Patterns are named shapes. They describe how skills interact with shared data sources and with each other. A pattern earns its own entry when it recurs across at least two clusters with consistent structure. Phase 3 produced four patterns across Clusters 4-8.

## What patterns are (and aren't)

Patterns are conventions that emerged from design decisions. They are descriptive ("this is a shape we use") not prescriptive ("you must use this shape"). A future phase could introduce a fifth pattern without violating any principle.

Principles are invariants — breaking one is either a bug or a deliberate supersession via ADR. Patterns are conventions — not using one is a design choice, not a violation. The distinction matters: principles are enforced by `ascent-self-audit`; patterns are documented here for reference, not enforced by tooling.

## Sibling pattern

### Definition

Two or more skills that read overlapping project sources but operate independently at runtime. Neither invokes the other. Each skill's opening prose documents the relationship explicitly: which skills are siblings, what data they share, and how their outputs differ.

### When to use

When two skills check overlapping domains but serve different purposes — one provides detailed findings, the other provides a summary or gate. The key signal: if skill A's output format would need to change when skill B's check logic evolves, they are too tightly coupled. Siblings avoid this coupling by reading sources directly rather than consuming each other's output.

### Concrete Phase 3 examples

**Cluster 4:** `ascent-adr-conformance` and `ascent-skills-doctor` are siblings to `ascent-self-audit`. Self-audit provides the structural §7 gate; adr-conformance provides deeper ADR analysis. Both read ADR files and `INDEX.md` directly. Neither invokes the other. The decision preserves self-audit's 1:1 step-to-principle mapping (15 steps for 15 principles) without expanding it to accommodate deeper sub-domain analysis.

**Cluster 5:** `ascent-reflect`, `ascent-handoff`, and `ascent-onboard` share §15 artifacts (`session-state.md`, `working-memory.md`) as a data layer. reflect writes; handoff and onboard read. The data flows through files, not through skill invocation.

**Cluster 7:** `ascent-security-audit` enumerates specific security findings; `ascent-sec-posture` summarizes the security stance. Both read the same project sources (`.gitignore`, source files, Docker configs, nginx configs). Neither invokes the other.

### When NOT to use

When one skill genuinely needs another skill's computed output — not its raw data sources — to function. If skill A cannot produce its output without first running skill B's logic, the sibling pattern forces duplication. In Phase 3, this situation did not arise (all skills can read project sources directly), but a future phase with skills that produce intermediate computed artifacts may need a different pattern.

### Where this might recur

Phase 4's scaffolder scripts may produce intermediate state (e.g., a resolved template tree) that multiple post-scaffold skills need to read. If those skills need the resolved tree rather than the raw template, they may need a data-flow pattern rather than pure sibling reads.

## Hybrid pattern

### Definition

An aggregator skill that self-executes lightweight surface checks across multiple domains, then conditionally recommends deeper sub-skills when a surface check flags a concern. No runtime invocation of sub-skills — recommendations are advisory, not orchestrated.

### When to use

When a skill's purpose is to answer "is everything OK?" across multiple domains, but the skill cannot (and should not) replicate the full depth of each domain's dedicated skill. The hybrid pattern keeps the aggregator lean while preserving the sibling precedent (no runtime cross-invocation).

### Concrete Phase 3 examples

**Cluster 6:** `ascent-qa` runs surface checks across 5 quality areas (structural integrity, ADR discipline, dependency discipline, documentation health, skill collection integrity). Each surface check maps to a deeper sub-skill: structural → self-audit, ADR → adr-conformance, dependency → dependency-health, documentation → doc-sweep, skills → skills-doctor. Recommendations appear only when concerns are flagged — clean areas show PASS with no additional output.

The three-reason rationale for hybrid over component (qa invoking sub-skills) or pure sibling (qa duplicating sub-skill logic): (1) preserves sibling precedent, (2) keeps qa within the specialized-lean line count, (3) avoids result drift between qa's conclusions and sub-skills' conclusions.

### When NOT to use

When the aggregator genuinely needs to compose sub-skill outputs into a computed result — not just recommend them. `ascent-health` (Cluster 8) was considered for the hybrid pattern but uses enumerate/summarize instead, because health produces a composite stance rating that requires reading sub-domain sources directly rather than just recommending sub-skills.

### Where this might recur

Phase 4's scaffolder may need a "scaffold readiness" gate that checks multiple pre-conditions. If each pre-condition has its own skill or validator, the hybrid pattern (surface check + conditional recommendation) fits naturally.

## Detect-don't-ask

### Definition

A skill that infers execution context from project state rather than prompting the developer to provide it. The skill reads indicators (file existence, file content, directory structure) and adapts its behavior accordingly.

### When to use

When a skill needs context that the developer shouldn't have to provide explicitly — project maturity, execution environment (meta-repo vs scaffolded project), subsystem presence (design system, AI eval suite). The key signal: if the developer would need framework-specific knowledge to answer the question correctly, the skill should detect rather than ask.

### Concrete Phase 3 examples

**Cluster 5:** `ascent-onboard` detects project maturity from three indicators: `working-memory.md` entry count, `PHASE-PLAN.md` checked items, and ADR count beyond the baseline 7. A fresh scaffold (no history) gets heavier framework orientation; an established project gets heavier project-specific context. The developer never selects a "mode."

**Cluster 6:** `ascent-release-readiness` detects whether it runs in the meta-repo (no `.ascent-meta.json`, `FRAMEWORK_VERSION` in Makefile) or a scaffolded project (`.ascent-meta.json` present), adapting version-field checks for each context.

**Cluster 8:** `ascent-design-system-audit` and `ascent-ai-evals` detect whether their respective subsystems exist (design tokens, `tests/evals/` directory) before running. Absent subsystems produce a clean no-op exit, not an error.

### When NOT to use

When the developer's intent genuinely matters and cannot be inferred from state. `ascent-adr-write` asks the developer what decision they made — the skill cannot infer this from project files. Detect-don't-ask applies to context (where am I?), not to content (what do you want?).

### Where this might recur

Phase 4's scaffolder will likely need to detect the target project's state (fresh directory vs existing code vs prior ASCENT scaffold) to choose between scaffold/enhance/migrate modes. The detect-don't-ask pattern applies directly.

## Enumerate/summarize sub-pattern

### Definition

A specialization of the sibling pattern where one skill enumerates detailed findings and another skill summarizes stance over the same domain. Both read the same project sources. The enumerator produces actionable findings; the summarizer produces a stance rating. The distinction is abstraction level, not data source.

### When to use

When a domain needs both detailed analysis (what specifically is wrong?) and stance assessment (how does this domain look overall?). The enumerate/summarize split keeps each skill focused: the enumerator can grow its check list without affecting the summarizer's output format, and vice versa.

### Concrete Phase 3 examples

**Cluster 4 (1:1 fan-in):** `ascent-adr-conformance` enumerates ADR-level findings (missing sections, orphaned entries, supersession-link gaps). `ascent-self-audit`'s §7 check provides the stance-level gate (ADR discipline: PASS or FAIL). One enumerator, one summarizer.

**Cluster 7 (1:1 fan-in):** `ascent-security-audit` enumerates point-in-time security findings across 5 surfaces. `ascent-sec-posture` summarizes the security stance (strong/moderate/weak with severity distribution). The pattern reinforces at the same 1:1 ratio with distinct nouns: audit uses "issues" and "findings"; posture uses "stance" and "coverage."

**Cluster 8 (1:4 fan-in):** `ascent-health` summarizes stance across four Cluster 4 enumerators: `ascent-data-health`, `ascent-dependency-health`, `ascent-doc-sweep`, and `ascent-adr-conformance`. Each enumerator produces domain-specific findings; health produces a composite stance with a mechanical 3-signal-per-domain classification ladder. The abstraction distinction is documented explicitly: health asks "how does this sub-domain look overall?"; enumerators ask "what specifically is wrong?"

### When NOT to use

When a single skill can serve both purposes without growing unwieldy. Not every domain needs the enumerate/summarize split — `ascent-env-audit` both enumerates and summarizes .env discipline in a single skill because the domain is narrow enough.

### Where this might recur

Phase 5's eval framework may produce both detailed eval results (per-prompt pass/fail) and an eval-suite stance (coverage percentage, regression count). The enumerate/summarize split would apply naturally.

## Adding a fifth pattern

If a future phase introduces an interaction shape that doesn't fit the four patterns above, document it here following the same structure: definition, when to use, concrete examples, when NOT to use, where it might recur. A new pattern should recur across at least two clusters or two distinct skill pairs before earning its own section — a one-off interaction shape is a design decision, not a pattern.

## Cross-references

- [PRINCIPLES.md](../../../docs/framework/PRINCIPLES.md) — the invariants these patterns complement (but do not replace)
- [PHASE-3-PLAN.md](../../../docs/framework/PHASE-3-PLAN.md) — the plan that produced the skills from which these patterns emerged
- [RETROSPECTIVES/PHASE-3.md](../../../docs/framework/RETROSPECTIVES/PHASE-3.md) — the narrative account of how the patterns emerged
- [CHANGELOG.md](../../../CHANGELOG.md) v0.4.0 Decided section — per-pattern introduction/reinforcement attribution
