# Contributing to lloydbriantech-ascent

Thank you for your interest in contributing. ASCENT is currently a single-author framework, but it's designed to grow. This document explains how contributions work and the bar a contribution must meet.

---

## Who maintains this

- **Owner:** lloydbriantech
- **Decision authority:** Currently sole. As the project matures, governance may formalize into a small group.

All architectural decisions are captured as ADRs in [`docs/framework/DECISIONS/`](docs/framework/DECISIONS/). If you disagree with a decision, the path forward is a new ADR that proposes superseding the existing one — not a PR that reverses behavior unilaterally.

---

## What contributions look like

ASCENT accepts these contribution types:

| Type | Examples | Bar |
|---|---|---|
| **Bug fix** | Scaffold generates wrong slug derivation; eval scenario flakes | One fix per PR; passing tests; clear root-cause analysis in PR description |
| **Documentation fix** | Typo, broken link, stale reference | Lowest bar; merged quickly |
| **Documentation improvement** | Clarifying example, expanded rationale, new diagram | Single concern per PR; preserves prior intent |
| **Reference module addition** | New pattern document under `references/` | Must cite real-world use case; must align with existing principles or include an ADR explaining the divergence |
| **Project-embedded skill addition** | New `ascent-<name>` SKILL.md scaffold | Must fill a documented gap; intent must fit one of the existing taxonomy categories or propose a new one via ADR |
| **Role module change** | Changing what a parent-skill role owns | Requires ADR; affects framework version (minor or major) |
| **New parent-skill role** | A tenth role | High bar; requires ADR demonstrating gap is large enough; affects framework version (major) |
| **Architectural change** | Mode detection mechanism, slug rules, naming convention | Requires ADR superseding the relevant existing decision; affects framework version (major) |

---

## Versioning

ASCENT follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html):

- **MAJOR** version (1.0 → 2.0): Breaking changes — old `.ascent-meta.json` files won't work, naming conventions changed, role inventory changed, or any change that would break a scaffolded project's existing skill invocations.
- **MINOR** version (0.1 → 0.2): Backward-compatible additions — new reference modules, new project-embedded skills, new role capabilities, new template content.
- **PATCH** version (0.1.0 → 0.1.1): Backward-compatible bug fixes, doc improvements, internal refactors.

The framework version is shared lockstep between:

- This repository's git tags (`v0.1.0`, `v0.2.0`, etc.)
- The `version:` field in `skills/lloydbriantech-ascent/SKILL.md` frontmatter (Phase 1+)
- The starter repo's tagged release (`lloydbriantech-ascent-starter v0.1.0`)
- The `framework_version` field that scaffolded projects write into their `.ascent-meta.json`

Mismatched versions are a CI failure.

---

## Cross-linking in reference modules

Reference modules under `skills/lloydbriantech-ascent/references/` form a navigable document map. Each module is internally self-sufficient but cross-links to siblings, ADRs, and framework documents where the topic naturally branches.

The rules:

1. **First mention per module gets linked.** Subsequent mentions of the same target stay as code spans or plain text. This keeps prose readable while ensuring every referenced document is one click away.
2. **Link to sibling modules** in `references/` when mentioned in another reference module — within a reference module, the link text and the relative target are typically identical (e.g., visible text `ENV-DISCIPLINE.md`, target `ENV-DISCIPLINE.md`).
3. **Link to ADRs** once per module (first mention), at `../../../docs/framework/DECISIONS/ADR-NNN-<slug>.md`.
4. **Link to `docs/framework/` documents** once per module (first mention of PRINCIPLES.md, ARCHITECTURE.md, ROADMAP.md, etc.), at `../../../docs/framework/<doc>.md`.
5. **Don't link to files outside the framework** — no GitHub URLs, no third-party sources, no external library docs.
6. **Don't link `make/*.mk` files, scripts, or code paths** — those stay as inline-code spans. The path is documentation in itself.
7. **Don't link skill mentions** (e.g., `` `ascent-self-audit` ``) — their SKILL.md files live in scaffolded projects, not in this repo.

Header citation links (the 1–2 authoritative links at the top of each module under a `> ` blockquote) are exempt from the first-mention rule — they're provenance metadata, not in-flow references.

Forward references to modules that haven't yet landed stay as code spans until the target exists. Promotion to a markdown link happens as a surgical edit in the chunk's PR that introduces the target.

---

## How to propose a contribution

### For small fixes (typos, broken links, single-file improvements)

1. Open a PR directly. Reference the issue number in the description if one exists.
2. Confirm in PR description that the change preserves prior intent.
3. Wait for review.

### For new content (reference modules, project-embedded skills, role additions)

1. **Open an issue first** using the appropriate template:
   - `new-skill-proposal` for a new project-embedded skill
   - `enhancement` for a role module change or new reference module
   - `skill-bug` for skill behavior fixes
2. Wait for maintainer acknowledgement and direction.
3. Open a PR that references the issue.
4. If the change requires an ADR, include the ADR in the same PR.

### For architectural changes (new ADR territory)

1. **Open an issue first** describing the problem and proposed direction.
2. Wait for maintainer to confirm the change is in scope.
3. Draft an ADR using the canonical template.
4. Open the PR with the ADR and the implementing changes together.

---

## The contribution bar

A contribution that meets this bar is more likely to be merged quickly:

### For all contributions

- [ ] One concern per PR. Mixed-concern PRs are sent back to be split.
- [ ] Conventional Commits format on every commit message.
- [ ] PR description explains the *why*, not just the *what*. The diff shows the what.
- [ ] If the change is non-obvious, the description includes a concrete example.

### For documentation contributions

- [ ] Prose reads as if a seasoned engineer wrote it for other seasoned engineers — no marketing language, no "simply just," no obvious-stating.
- [ ] Tables used for comparison; prose used for rationale; bullets used sparingly.
- [ ] Internal links use repo-relative paths, not absolute URLs to github.com.
- [ ] Doc changes preserve the persona-segmented navigation (see [`docs/framework/PRINCIPLES.md`](docs/framework/PRINCIPLES.md)).

### For skill and reference module contributions

- [ ] Slug taxonomy followed (kebab-case, 2–4 segments, see [ADR-004](docs/framework/DECISIONS/ADR-004-slug-conventions.md)).
- [ ] Naming convention followed (see [ADR-005](docs/framework/DECISIONS/ADR-005-skill-naming.md)).
- [ ] Frontmatter validated against the schema (Phase 1+ has `make qa-skill-frontmatter`).
- [ ] If the change affects an existing project's `ascent-*` skills, the migration path is documented in the same PR.

### For architectural contributions

- [ ] ADR is in place, using the canonical template.
- [ ] ADR includes the "Alternatives considered" section with at least two real alternatives.
- [ ] ADR includes the "Cost implications" section.
- [ ] If the change supersedes a prior ADR, both ADRs are updated (the new one references the old; the old one's status changes to "Superseded by ADR-XXX").

---

## What "review" looks like

For now, review is by the owner (lloydbriantech). The review focuses on three questions:

1. **Does the change preserve prior intent?** If the existing behavior was deliberate, is the rationale for changing it explicit?
2. **Does the change earn its complexity?** Every addition is a maintenance burden forever. Is the value clear?
3. **Does the change fit the framework's character?** ASCENT is opinionated; PRs that water down opinions to suit edge cases are usually rejected in favor of explicit project-level overrides.

If a contribution is rejected, the rejection includes a specific reason and (where possible) an alternative path.

---

## Code of conduct

Be respectful. Engage with substance, not personality. Disagreements are resolved by examining the evidence and the principles. The project is small enough that this works without formal machinery; if it grows, formal codes will be adopted.

---

## Lessons codified from Phase 3

Three workflow disciplines emerged from Phase 3's implementation of 28 skills across 8 clusters. They are codified here as contribution guidance for future phases. See [`docs/framework/RETROSPECTIVES/PHASE-3.md`](docs/framework/RETROSPECTIVES/PHASE-3.md) for the narrative account of how each discipline emerged.

### Cluster-based contribution discipline

When a phase delivers multiple related artifacts, group them into clusters and ship each cluster as a single reviewed PR. The cluster is the unit of review — one proposal, one implementation, one review packet, one merge.

**The workflow:**

1. **Propose** — surface design decisions as lettered questions (Decision A, Decision B, etc.) with options and rationale. Wait for approval before implementation.
2. **Implement** — build all artifacts in the cluster on a feature branch.
3. **Review packet** — before pushing, ship a review packet containing:
   - Verbatim file content for every new or modified file (not summaries, not "read the file" placeholders)
   - Validator outputs (`make qa-skill-frontmatter`, `make qa-links`, `make qa-template-placeholders`)
   - Confirmations checklist naming each design decision by letter and confirming it landed
4. **Pre-push spot-check** — run validators locally, run tests locally, export files to `/tmp/ClaudeCodeResponses/` AFTER the final amend (not before — Cluster 2's stale-file incident established this discipline).
5. **Push and PR** — open the PR with a substantive description capturing architectural decisions, validator output, and phase-progress update.

**What this does NOT prescribe:** Cluster size, skill count per cluster, or PR description format. The discipline is about the propose → approve → implement → review → push flow. Phase 4 clusters may be larger or smaller than Phase 3 clusters.

### Cross-cutting artifact verification

Some artifacts are updated across multiple PRs or phases. When a plan claims a file will be updated, the implementation must actually touch that file. Phase 3 identified two instances where this discipline failed:

- **INTENT-MAP.md** — every Cluster 1-8 proposal stated INTENT-MAP would gain rows; none of the 8 PRs updated it. The gap compounded across 8 PRs and was caught only in the closing chunk.
- **ASCENT-INVARIANTS.md** — v0.3.1 introduced Principle §15 but did not update ASCENT-INVARIANTS.md from "fourteen" to "fifteen." The catch-up landed in v0.4.0's closing chunk.

**The cross-cutting files that need verification:**

- `INTENT-MAP.md` — when skills are added or renamed
- `ASCENT-INVARIANTS.md` — when principles are added or changed
- `PRINCIPLES.md` — when principles are added (including the relate-to-framework table)
- `README.md` — when skill counts, version, or phase status change
- `CHANGELOG.md` — when a release ships

**The verification mechanism:** Run `make qa-claimed-vs-actual PLAN=<plan-file>` against the phase plan at the closing chunk. The validator checks that every artifact path claimed in the plan's artifact catalog table exists in the repo. It does not verify content — only structural existence.

**When to run:** At the closing chunk of each phase or release, not at every PR. Per-PR verification is optional but recommended when the PR touches cross-cutting files.

### Phase-plan discipline

Commit a durable plan before implementation begins. Reference the plan by section number in PRs. Append amendments to the plan rather than rewriting it.

**The practice:**

1. **Commit the plan first.** The plan is a separate PR that merges before any implementation work. It contains: artifact inventory, design decisions, chunk breakdown, exit criteria, and out-of-scope clarifications.
2. **Reference by section number.** Implementation PRs cite the plan: "Per §6 Cluster 4 scope, ~920 lines estimated." This prevents re-litigation of decisions already captured in the plan.
3. **Append amendments, never rewrite.** If the plan's estimates or decisions change during implementation, capture the change as an amendment at the bottom of the plan document. The original text is preserved as a comparison baseline.

**What this does NOT prescribe:** Plan length, section structure, or level of detail. Phase 3's plan was ~500 lines across 10 sections because the work was inventory-heavy (28 skills). A future phase plan may be lighter if the work is more design-driven. The discipline is about committing a durable reference and working against it, not about matching a template.

Phase 3's retrospective dogfoods this discipline: [`PHASE-3-RETRO-PLAN.md`](docs/framework/PHASE-3-RETRO-PLAN.md) commits before any retrospective content, and Chunks 1-3 reference it by section number.

---

## License of contributions

By contributing, you agree your contributions are dual-licensed under the same terms as the project itself: MIT OR Apache-2.0 at the consumer's option. This matches the Rust ecosystem convention and is stated formally in [ADR-006](docs/framework/DECISIONS/ADR-006-dual-licensing.md).

No CLA is required. The dual-license-by-contribution convention handles attribution and patent grant cleanly.

---

## Acknowledgements

This framework borrows generously from:

- The Rust ecosystem's dual-licensing convention
- Michael Nygard's "Documenting Architecture Decisions" essay (the ADR pattern)
- The Keep a Changelog convention
- Conventional Commits specification
- The Twelve-Factor App methodology (concerns, not all twelve factors)
- The author's own multi-year accumulation of patterns from telecom delivery work, agentic AI experimentation, and side projects across the home-lab and family-software space

Where a pattern is borrowed, it is documented as such. Where a pattern is novel to ASCENT, the ADR explains the deviation from common practice.

---

*If something in this document is unclear, open an issue with the `docs` label and we'll fix it.*
