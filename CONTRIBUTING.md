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
