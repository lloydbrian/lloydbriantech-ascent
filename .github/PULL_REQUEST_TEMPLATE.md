# Pull request

## What this PR does

One or two sentences. The diff shows the *what* — this section explains the *intent*.

## Why

Why now? What problem does this solve, and what was the path that led to this proposal?

If this PR addresses an issue, reference it: `Closes #NN` or `Refs #NN`.

## Type of change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] Documentation (typo, broken link, clarification)
- [ ] Documentation (substantive — new content or restructure)
- [ ] Reference module addition or change
- [ ] Skill behavior change
- [ ] Template asset change
- [ ] Tooling / CI / build change
- [ ] Architectural change (requires ADR — included in this PR)
- [ ] Breaking change (would break existing scaffolded projects)

## Checklist

### For all PRs

- [ ] One concern per PR — if this touches multiple unrelated areas, split it
- [ ] Conventional Commits format on every commit
- [ ] PR description explains the *why*, not just the *what*
- [ ] Branch is up-to-date with `main`
- [ ] No merge commits (rebase, then push)

### For doc PRs

- [ ] Prose reads as if written by a seasoned engineer for other seasoned engineers
- [ ] Internal links use repo-relative paths
- [ ] Persona-segmented navigation preserved
- [ ] CHANGELOG.md entry added under `[Unreleased]`

### For skill or reference module PRs

- [ ] Slug taxonomy followed (kebab-case, 2–4 segments)
- [ ] Naming convention followed
- [ ] Frontmatter validated (Phase 1+)
- [ ] If this affects scaffolded projects' `ascent-*` skills, migration path documented
- [ ] CHANGELOG.md entry added under `[Unreleased]`

### For architectural PRs

- [ ] ADR included in this PR, using the canonical template
- [ ] ADR includes "Alternatives considered" with at least two real alternatives
- [ ] ADR includes "Cost implications"
- [ ] If superseding a prior ADR, both are updated
- [ ] CHANGELOG.md entry added under `[Unreleased]`

## Testing

- [ ] Manual verification performed (describe below)
- [ ] CI passes
- [ ] If this changes skill behavior, an eval scenario covers the change (Phase 5+)

**What I tested:**

(describe)

## Screenshots / output

If this PR affects user-facing output, paste before/after. Use code fences.

## Anything else

Anything reviewers should know that isn't obvious from the diff?

---

*Reviewer guidance: focus on (1) does this preserve prior intent? (2) does this earn its complexity? (3) does this fit the framework's character?*
