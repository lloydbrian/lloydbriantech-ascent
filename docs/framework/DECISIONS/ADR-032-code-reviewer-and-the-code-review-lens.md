# ADR-032: An ASCENT code reviewer, and the Code review lens

**Status:** Accepted
**Date:** 2026-11-25 (America/New_York)
**Decider:** lloydbriantech

## Context

The delivery loop (`ascent-delivery`, Step 4) reviews every change through one reviewer per lens. Every lens but one had a read-only `ascent-*` agent first in its provider list. Correctness did not: it used `engineering:code-review` when that skill was installed, and a one-paragraph fallback prompt otherwise. A project that installed ASCENT alone got its weakest review on the lens that catches the most bugs.

On 2026-11-22 an outside review of ASCENT against a 12-stage AI lifecycle named the official `code-review` plugin as the provider to trial. Reading it on 2026-11-25 showed it reviews only a GitHub pull request (`gh pr diff`), stops on a closed or draft pull request or one already reviewed, and posts through `gh pr comment` and an MCP inline-comment tool. The delivery loop reviews at Step 4, before a pull request exists, so that plugin cannot run there.

ASCENT's own history shows where the bugs that reach a release are: rarely in the changed lines alone. The exit-2 rule of v0.4.26 ([ADR-030](ADR-030-exit-2-usage-errors-and-test-only-variables.md)) was visible only in the checkers a change did not touch; the OPS-S8 path bug of v0.4.12 was a contract another script relied on; several fixes were bash 3.2, BSD sed or BWK awk differences.

The operator weighed four routes on 2026-11-25 and chose an ASCENT reviewer. The same day they defined "widen": everything a code review covers, and nothing another ASCENT plugin or lens reviews.

## Decision

1. **`ascent-delivery:code-reviewer`**, a read-only agent (`tools: Read, Grep, Glob`, `model: inherit`), in `ascent-delivery` 0.3.0. It reads the change in seven passes, each kept apart until the filter:
   - intent, against the acceptance criteria;
   - the changed lines;
   - callers and contracts in files the change did not touch;
   - the project's own rules (`CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md` covering each changed file), broken only where the rule can be quoted and the breaking line shown;
   - environments: OS, shell and its version, BSD and GNU tools, locale, time zone, line endings, file-name case;
   - performance on a hot path: N+1 queries, quadratic work, I/O repeated in a loop;
   - maintainability a reviewer would act on: misleading names, functions doing unrelated things, duplicated logic that will drift, dead code left behind, error messages that don't say what to do next, a simpler way to write the change. Formatting and what a linter reports stay out.
2. **The filter.** A finding is reported only with a `file:line`, a concrete failure scenario and a reason to believe its inputs can happen. Five kinds are dropped: what was there before the change, what a linter or compiler reports, nitpicks, what another lens owns, and what the code silences on purpose. A doubtful finding goes under "Noticed, not rated".
3. **Severity from the scenario's impact**, the rule `finding-verifier` already uses; maintainability findings are Low unless they hide a wrong result. There is no marked severity table, so the plugin has no severity marker.
4. **No overlap.** Security and privacy, architecture and cost (timeouts, retries, limits), accessibility, UX, operations and deploys, tests, AI behavior (prompts, tools, evals, model calls), decisions and documentation each keep their own reviewer.
5. **The lens is renamed Correctness → Code review** in all four tables (the ownership registry, the skill, `review-lenses.md`, the README). Providers, first installed wins: `ascent-delivery:code-reviewer`, `engineering:code-review`, then the fallback prompt, which now names the seven passes and the filter, for surfaces that cannot run plugin agents.
6. **A review never writes.** The agent never posts, comments, approves or opens anything, and never asks the main session to. `review-lenses.md` forbids passing any provider an option that posts, comments or edits (`--comment`, `--post`, `--fix`), and running a provider that needs a pull request at Step 4. The operator-boundary hook blocks GitHub writes through MCP tools ([ADR-031](ADR-031-ascent-ai-and-the-ai-lifecycle.md) decision 9).
7. **Tests and controls.** `test-delivery-rules.sh` D10 pins the seven passes, the five drops, the finding format, the per-pass count line, the never-post rule, the lenses left to others and the review-lenses rule; the gate's T4 (read-only), T9 (step references) and T13.3/T13.8 (registry and lens tables) check the rest. Controls P2060–P2087.
8. **A measured trial before release:** seeded correctness bugs from ASCENT's own history, two seeded maintainability defects scored apart, and a correct past change as the false-positive control. The new reviewer must catch at least 4 of the 5 correctness bugs and no fewer than either other reviewer, find at least 1 of the 2 maintainability defects, and report no High or Critical finding on the clean case that `finding-verifier` confirms. The cases and answer key stay outside git; the CHANGELOG records the result.

## Alternatives considered

- **The official `code-review` plugin as a second opinion, once the operator opens the pull request.** Rejected: about seven agents per review, two of them on Opus; GitHub only; stops on draft or already-reviewed pull requests; and in GitHub Actions it can post through an MCP tool the hook did not see then.
- **The official plugin as the provider.** Not possible at Step 4: it needs a pull request.
- **A stronger fallback prompt only.** Rejected: still one paragraph in a table, nothing to make it read-only and no tests on its method.
- **Keeping the name Correctness.** Rejected: the seventh pass is maintainability, and a lens named for one pass would invite a second lens for the other.
- **Claude Code's built-in `/code-review` in the provider list.** Left out for now: it is version-dependent and has a `--fix` option; the new review-lenses rule already forbids passing it.

## Consequences

- Every project with `ascent-delivery` gets a full code review at Step 4, with no other plugin installed.
- The review looks where release bugs have been: callers, contracts and platforms, not only the diff.
- Maintainability findings reach the verifier at Low, so they inform without blocking.
- The lens name changes in four tables at once; the registry gate (T13.8) fails if any drifts.
- The reviewer's quality is measured once, by the trial, not continuously; Phase 5's eval harness is where that trial becomes a repeatable eval.

## Cost implications

- One agent file, one rule group in a test, 28 controls, and a reviewer run per delivery loop: the same number of agents as before, since the lens already ran one.
- `model: inherit`, as every ASCENT agent, so the review costs what the session's model costs; pinning a larger model is the operator's choice per session.
- The trial costs about 21 agent runs, plus up to 12 for each calibration round, once.
