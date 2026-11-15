# ADR-022: UX as four principles: flow integrity, reliability and verifiable pleasantness in `ascent-ux` 0.3.0

**Status:** Accepted
**Date:** 2026-11-12 (America/New_York)
**Decider:** lloydbriantech

## Context

`ascent-ux` 0.2.0 ([ADR-012](ADR-012-ux-plugin-design-directions-and-plugin-dependencies.md)) rates a web UI through five lenses: accessibility, design system, usability heuristics, states and content, and performance UX. Accessibility is covered in depth (WCAG 2.2 AA criterion by criterion, UX-U1–U12, token contrast, a Playwright browser pass). The other qualities a user feels are covered only in part:

- **Functional.** Nothing checks that a flow completes. A broken link, a missing anchor target or a step with no way forward is found only if a reviewer happens to read it. [ADR-014](ADR-014-testing-ownership-and-dependency-scan.md) gave navigational integrity and the cross-browser pass to `ascent-ux` 0.3.0, and `OWNERSHIP.md` lists both domains as planned.
- **Reliable.** States are checked to exist, but not what happens when the user double-clicks, reloads a half-filled form, goes Back, or loses the network. Offline is described in the heuristics reference and never rated.
- **Pleasant.** Deliberately left out, so the review never says anything about feedback, motion consistency or dark patterns, even where those can be checked.

On 2026-11-05 the operator agreed to frame UX as four principles in dependency order, functional, reliable, accessible, pleasant, as a hierarchy over the existing lenses. Two constraints came with it: uptime stays with `ascent-ops`, and pleasantness is never rated "met", because the rule "never met without a target" applies and taste has no target.

## Decision

1. **Four principles, as a ladder over the lenses.** The report gains a principles line (functional → reliable → accessible → pleasant) and names the lowest principle at risk, listing the unmeasured ones apart. The ladder orders the report and its headline; it never changes a finding's severity, which still comes only from the `ux-severity` table.
2. **Seven lenses in four groups.** Two lenses are added, **Flow integrity** under functional and **Reliability** under reliable. The five existing lenses stay and sit under the principle they serve. The pleasant group's status is "observed" or "at risk", never "met".
3. **Three rule families, all plugin-qualified ([ADR-015](ADR-015-ownership-registry-and-gate.md)):**
   - `UX-F1`–`UX-F7`, flow integrity: links, form actions and router targets resolve; in-page and ARIA id targets exist; each core-flow step has a way forward and a way out; a not-found route exists; a browser walk of each core flow sees no same-origin 4xx or 5xx and no uncaught error; the core flows pass the browser checks in every engine the contract lists; build targets match the contract's browsers.
   - `UX-R1`–`UX-R7`, reliability as experienced: double-submit protection; a visible failure path for every request on a core flow; retry after failure; drafts kept across reload on long forms; listed view state kept in the URL across Back and refresh; an offline notice when the contract requires one; rollback of optimistic updates.
   - `UX-P1`–`UX-P4`, pleasantness as verifiable observation: progress feedback on async actions; motion through tokens; no consent or marketing option checked by default; a way to cancel or unsubscribe where there is a way to sign up. Tone is not a rule; unclear copy goes to `design:ux-copy` as an unrated observation.
4. **Static first, browser authoritative, as in 0.2.0.** Two new read-only scripts, `check-flow-integrity.sh` (UX-F) and `check-ux-resilience.sh` (UX-R, UX-P), in bash and awk, read HTML, JSX, Vue, Svelte and three router styles. The browser pass gains a walk of each core flow and an engine loop. The walk submits a form only on localhost and only when the operator supplies `test_data` in the contract, never with real data; otherwise it navigates only. For the engine loop, the operator's per-engine Playwright MCP runs are authoritative; a project's own Playwright `projects` config is read as supporting evidence and never run.
5. **Severity.** A core flow that cannot be completed, for any user and for any of the reasons above, is High, extending the existing High row for keyboard and screen-reader users. A broken link on a core flow is therefore High. Reliability gaps on core flows that lose or hide the user's work (a double submit, a hidden failure, a lost draft, lost view state: UX-R1, R2, R4, R5), a missing required offline notice (UX-R6), broken links elsewhere and a pre-checked consent option (UX-P3, kept in `ascent-ux`) are Medium. No retry after a failure (UX-R3) and no rollback of an optimistic update (UX-R7) are Low: the user can still try again by hand. Off the core flows, a same-origin error or dead script on the walk (UX-F5) is Medium, since the page is broken wherever it is, and an unreachable page or one with no way back (UX-F3) and lost view state (UX-R5) are Low. Everything else is Low. The exact rows are added to the `ux-severity` table in the skill and the agent, which T5 keeps identical.
6. **Contract.** The `ux:` section gains `core_flows[].steps`, `core_flows[].test_data`, `engines`, a `reliability` block (`draft_fields`, `url_state`, `offline`) and a `pleasant` block. Every 0.2.0 contract stays valid; a missing key makes its rule unmeasured, never met.
7. **One new deeper skill, `flow-check`,** recommended by `ux-review` when the functional or reliable group is at risk, in the hybrid pattern of 0.2.0.
8. **Ownership.** `UX-F`, `UX-R` and `UX-P` are registered as rule families; `navigational integrity` and `cross-browser compatibility` move from planned to released; a new domain, "UI reliability (as experienced)", is owned by `ascent-ux` for both target and test-present. The families are registered in the release change itself, with no earlier reservation. Their rules are defined in one reference, `references/flow-and-reliability.md`, which both scripts, the skills and the agent follow, as `OPS-S` is defined in `secure-config-rules.md`.
9. **Release.** `ascent-ux` 0.3.0 ships as framework v0.4.15, after the harness fix in v0.4.14. The 0.2.0 trial calibration candidates (delegated listeners across files, box-shadow ring contrast) are left to 0.3.1.
10. **Negative-control job limit: 25 minutes in fast mode.** CI on 2026-11-12 took the macOS `ascent-ops-drills` job 4, 10 and 14 minutes on the same code, and a fourth run was cancelled at the 15-minute limit with every finished control killed. The limit from [ADR-017](ADR-017-faster-negative-controls.md) decision 5 ("every macOS group under 10") no longer holds on slow runners, and this release adds two groups. Fast mode gets 25 minutes on both platforms; full mode keeps 40. A group that needs more than 25 is split, not given more time.

## Alternatives considered

- **Keep five lenses and add the rules to them.** Rejected. Flow integrity has no home in the five lenses, and reliability spread across "states and content" and "performance UX" would hide that it is a separate question the user asks: "will it lose my work?"
- **Replace the five lenses with four principle lenses.** Rejected. Every 0.2.0 report, the severity table and the `accessibility-audit` and `design-system-check` skills are built on the five lenses; a rename breaks report parsers for no new evidence.
- **Rate pleasantness against a score.** Rejected. There is no measurable target for taste; a score would be invented and would invite "met" without evidence.
- **Give UI reliability to `ascent-ops`.** Rejected. `ascent-ops` owns whether the service is up; whether the page keeps a draft or survives a double click is read in front-end code, which `ascent-ux` already parses.
- **Run the project's own end-to-end suite for flow integrity.** Rejected. Running tests belongs to the operator ([ADR-014](ADR-014-testing-ownership-and-dependency-scan.md) decision 1), and `ascent-quality` already checks that such a suite exists and that CI runs it.
- **Cross-browser evidence from one source only.** Restarting the browser per engine alone leaves projects with an existing cross-browser suite unused; reading the project's Playwright `projects` alone proves only that a suite is configured, not that the flows pass. Rejected in favour of both, with the operator's runs authoritative.
- **A navigation-only walk with no form submission ever.** Rejected: most core flows end in a submit, so the walk could never confirm completion. Submission is allowed on localhost with operator-written `test_data` only.
- **Rate a broken core-flow link Medium.** Rejected: the user cannot finish the task, which the severity table already rates High for keyboard users.
- **Rate a pre-checked consent box Low and hand it to `ascent-security`.** Rejected: it is a deceptive interface pattern the user sees, read from the same markup `ascent-ux` already parses; privacy law questions stay out of scope.
- **Fold the 0.2.0 trial calibrations into this release, or reserve the new ids in a separate planning commit.** Rejected to keep 0.3.0 to the four principles and one change; the calibrations follow as 0.3.1.
- **Crawl the running site for broken links.** Rejected as the main check: it needs a running server for every review and misses links behind state. The static check runs always; the browser walk confirms the core flows.

## Consequences

- A review now says whether the core flows work and hold up, not only whether they are accessible, and names the lowest principle at risk.
- Reports gain a principles line and two lenses. Anyone who parses report output must update, as with the rule-id change in v0.4.8.
- Projects gain optional contract keys; a project that declares no flow steps gets UX-F3 and the browser walk as unmeasured (Low), not as failures.
- The cross-browser pass needs the operator's help when the Playwright server runs one engine per launch.
- Two more control groups run on two platforms in CI, so four more jobs exposed to macOS runner shortages.
- **(uncertain)** Static reading of request handlers and router tables across files will produce false positives in some frameworks until a real-repository trial calibrates them, as the 0.1.0 trial did for click handlers. The 0.3.0 trial on five real repositories (2026-11-13) found about 15 such false positives and fixed each at the source, with a test and a negative control; one limit remains, a guard or failure path in a shared hook or service, which `flow-check` reads by hand before rating (CHANGELOG [0.4.15], Notes).

## Cost implications

- **Build:** about 1,100 plugin lines, 900 test lines and some 100 negative controls in two new groups, `ascent-ux-flows` and `ascent-ux-resilience`, each inside the CI job limit (25 minutes in fast mode, decision 10). Roughly twice the size of v0.4.13: four to six working sessions to build, one or two to trial and calibrate, one to review and release.
- **Recurring:** keep the router readers and request-library patterns current as React Router, Vue Router, SvelteKit, Next.js and the data-fetching libraries change.
- **Runtime:** bash and awk for the static checks; the existing Playwright companion for the browser walk. Nothing is installed or run in the reviewed project.
