# ADR-007: Template repo paired with skill via CI generation

**Status:** Accepted
**Date:** 2026-05-14 (America/New_York)
**Decider:** lloydbriantech

## Context

ASCENT's primary user experience is scaffolding new projects. There are two distinct user expectations for how scaffolding should work, and they imply different product surfaces:

**Expectation A — "I want a working project in five seconds."** The user types `gh repo create --template ...` and gets a personalized, running project before they can finish their coffee. This is GitHub's template-repository pattern; it's how Next.js, Vite, and most modern starters work. The user doesn't even need to install a tool — just hits "Use this template" on GitHub.

**Expectation B — "I want full customization at scaffold time."** The user invokes the parent skill in Claude Code, runs through a six-question architect interview, and gets a project built to their precise specifications — choice of runtime, deploy target, agent inclusion, AI provider, frontend framework. The skill makes choices and emits files based on the interview answers.

These are not the same product. Expectation A trades customization for speed; Expectation B trades speed for customization. Both have legitimate audiences. A framework that only serves one of them loses the other.

The naive way to support both is to write the assets twice — once in the skill (for Expectation B), once in the template repo (for Expectation A). This produces immediate drift: a fix landed in one isn't reflected in the other; the two diverge until they're effectively different products.

## Decision

ASCENT ships two paired artifacts that share a **single source of truth**:

- **`lloydbrian/lloydbriantech-ascent`** (this repo) — contains the parent skill, including the full template asset tree under `skills/lloydbriantech-ascent/assets/template/`. This is the source of truth for all template content.
- **`lloydbrian/lloydbriantech-ascent-starter`** — a separate GitHub repository marked as a Template repository. **Generated** from the skill's asset tree, not authored directly.

The pairing works as follows:

1. The skill's `assets/template/` contains template files with slug placeholders (`<<PROJECT_SLUG>>`, `<<PROJECT_TITLE>>`, etc.)
2. A build tool (`tools/build-starter.sh`) takes the asset tree, substitutes a default slug (`ascent-starter`) for all placeholders, and produces a complete project tree
3. The release CI workflow (`release.yml`) runs the build tool on every framework tag and **force-pushes** the result to the starter repo with a matching tag
4. The starter repo is marked as a GitHub Template repository so users can `gh repo create --template`

After cloning the template, users run a `bootstrap` mode of the parent skill that replaces the `ascent-starter` slug with their chosen slug. The bootstrap also offers to run the architect interview if the user wants to customize beyond the default options.

## Alternatives considered

**One repo, no separate template repo.** Users always go through the parent skill. Rejected because:

1. Loses the five-second GitHub-template experience entirely
2. Forces every user to install Claude Code and the skill before they can start a project
3. Discoverability suffers — GitHub Template repos are browseable; skills are not

**One repo, dual-purpose — meta-repo is also a template.** Mark the meta-repository itself as a GitHub Template. Rejected because:

1. The meta-repo is the framework, not a project — its README, structure, and files are wrong for a scaffolded project
2. The meta-repo includes things scaffolded projects shouldn't have (`skills/`, `docs/framework/`, `tools/build-starter.sh`)
3. A starter repo's structure must match what a scaffolded project looks like — that requires a different repo

**Two repos, both authored directly.** Edit the meta-repo's skill assets; edit the starter repo's files. Rejected because of immediate drift, as described in the Context. This is the option naive approaches default to; it's the option that fails.

**Two repos, manual sync.** Edit one, manually copy the change to the other. Rejected because manual sync always loses to drift; it depends on discipline that erodes over time.

**Two repos, sync via Renovate-style automation.** Rejected because that machinery is heavier than the problem requires. CI-on-tag is simpler and only needs to run on releases, not continuously.

**One repo with two roots.** Use a monorepo with separate `framework/` and `starter/` directories. Rejected because GitHub Template repositories are repo-level, not directory-level. The starter has to be its own repo to be a Template.

**Skill includes the starter as a git submodule.** Rejected because submodules are operationally awkward and don't solve the drift problem unless the submodule is itself generated.

## Consequences

**Easier:**

- Users get both experiences (instant template clone OR full interview) from one framework
- Drift between skill and starter is structurally impossible — the starter is generated, never authored
- The starter repo can be force-pushed without remorse because it has no commit history of its own (everything in it came from the skill)
- A bug fix in template content gets fixed once (in the skill) and the next release propagates to the starter automatically
- The starter repo serves as documentation — a user can browse it on GitHub to see what an ASCENT project looks like before installing anything

**Harder:**

- Two GitHub repositories to administer instead of one
- The CI workflow must have write permission to push to the starter repo (handled via GitHub Actions deployment key or fine-grained PAT)
- Users who fork the starter repo and edit it directly will be confused when their changes vanish — the starter repo's README must clearly state "this repo is generated, edit the skill in lloydbriantech-ascent"
- The build tool must produce a clean tree; bugs in the tool produce visible breakage in the starter repo
- The starter repo can't accept PRs directly — PRs against it must be redirected to the meta-repo

**Neutral:**

- Both repos have the same version (lockstep) — the starter's tag matches the framework's tag

## Cost implications

**Time:** Up-front cost: writing the build tool and the CI workflow (Phase 6 — moderate effort, days). Ongoing cost: near-zero — every release tag triggers the regeneration automatically.

**Complexity:** Two repos to administer, one build tool to maintain. Both costs are manageable.

**Future flexibility:** The pattern extends cleanly. If ASCENT later adds a Python-stack variant, a third repo (`lloydbriantech-ascent-starter-python`) could be generated from a different asset tree in the same skill, on the same CI workflow.

**Money:** None. Both repos are free under GitHub's standard plans.

## A note on the force-push pattern

Force-pushing to the starter repo is *the right call* given that it's a generated artifact. Conventional wisdom against force-pushing applies to repos with collaborative human history; the starter repo has no such history. The force-push pattern is identical to how `gh-pages` branches, generated documentation sites, and other build-artifact repos are conventionally maintained.

The starter repo's README will explicitly warn against direct edits. Users who clone and modify it for their own project are creating their own derivative work — that's expected and supported, and their fork's divergence is none of the framework's concern. The force-push affects only the canonical starter repo, never user forks.
