# ADR-027: Decision, session and documentation plugins: ascent-adr, ascent-session and ascent-docs, hand-written for any repository

**Status:** Accepted
**Date:** 2026-11-18 (America/New_York)
**Decider:** lloydbriantech

## Context

The plugin roadmap ranks `ascent-session`, `ascent-adr` and `ascent-docs` fifth to seventh ([ROADMAP.md](../ROADMAP.md)). Their ground is already covered inside scaffolded projects by embedded skills: `ascent-adr-write` and `ascent-adr-conformance`; `ascent-reflect`, `ascent-standup`, `ascent-handoff` and `ascent-onboard`; `ascent-doc-stub`, `ascent-doc-sweep` and `ascent-persona-coverage`. Those skills only work in an ASCENT scaffold: their paths are fixed (`docs/architecture/decisions/`, `docs/delivery/`, `.ascent-meta.json`), their personas are ASCENT's five, and they are prose, with no script, rule id or negative control. [PILLARS.md](../PILLARS.md) rates decision traceability "Partial: scaffolded projects only, no negative controls yet".

A first run of the new ADR checker on this repository's own record (2026-11-18) found two real gaps on `main`: ADR-026 was missing from INDEX.md, and ADR-009's body had gained a paragraph in v0.4.3, after it was accepted and released in v0.4.2, against the rule that an accepted ADR's body never changes.

The operator approved the bundle on 2026-11-18: (a) the three plugins are hand-written, not generated; (b) codes `DEC`, `SES` and `DOC`; (c) a "Decisions and docs" review lens in the delivery loop; (d) one release, v0.4.23; (e) a "What a run costs" section from a token estimate, with no limit on description length, because full descriptions are what let builders and operators use a plugin well.

## Decision

1. **Three hand-written plugins that work in any repository.** Each finds the repository's own layout, or reads it from its section of `.ascent/contract.yml`, and checks with scripts that print rule ids, behind behavior tests and negative controls, like `ascent-quality`. The embedded skills stay as they are for scaffolded projects. Generating the plugins from them (ADR-009's pattern) would carry the scaffold's fixed paths into every repository.
2. **`ascent-adr` (`DEC`, section `decisions`).** Skills `adr-check` (entry point), `adr-write` and `decision-drift`, agent `decision-reviewer`. `check-adrs.sh` reads the ASCENT, Nygard and adr-tools, and MADR formats and checks DEC-S1–S8: a record exists, sections, numbers and names, the index, status, supersession both ways, dates, and that an accepted ADR's body is unchanged since the commit that first recorded it as accepted (`git log`, `git show`). A known older change is acknowledged in `decisions.acknowledged_changes` with its commit, never hidden: the check then compares with that commit and prints a NOTE. `check-decision-drift.sh` checks DEC-C1–C3 against `decisions.constraints`, which a person confirms: a pattern the code must not contain, or a path that must exist, for an accepted ADR. Only declared constraints are checked, so decision traceability moves to Partial with negative controls, not to Strong.
3. **`ascent-session` (`SES`, section `session`).** Skills for capturing and resuming a session and for a handoff, with a check of the records: present, fresh, complete, transient state ignored by git, decisions only appended. The records live in the repository and are shared by the team, unlike Claude's private memory.
4. **`ascent-docs` (`DOC`, section `docs`).** A rated documentation review, drift checks (paths, make targets, scripts, environment variables and versions a doc names that the repository no longer has), links, audience and stale markers dated by `git log` rather than file times, persona entry points from the contract, a stub generator that implements this repository's `make doc-stub`, and a read-only onboarding walkthrough. Operations manuals stay `ascent-ops`'s and ADRs `ascent-adr`'s.
5. **Two review lenses** in `ascent-delivery`'s delivery loop: **Decisions**, provided by `ascent-adr:decision-reviewer`, and **Documentation**, provided by `ascent-docs:docs-reviewer`, each with a fallback prompt. The operator approved one "Decisions and docs" lens; it is two because a lens runs only its first installed provider, so one lens would never run the second reviewer. `ascent-delivery` moves to 0.2.1.
6. **What a run costs** is documented as ranges with their assumptions (characters per token, small and medium repositories). Token savings come from how evidence is gathered and what is loaded, never from shortening descriptions, and any trim needs a before-and-after check that no finding is lost.
7. **The framework checks its own decision record.** This repository gets its first `.ascent/contract.yml`, with only a `decisions` section, and the plugin gate runs `check-adrs.sh` on `docs/framework/DECISIONS` as T16. The ADR-009 change is acknowledged at commit 0ac9d34, after a person read it, so any later change to an accepted ADR still fails; CI's gate job checks out the full history so DEC-S8 can compare. The operator approved this on 2026-11-18.

## Alternatives considered

- **Generate the plugins from the embedded skills (ADR-009).** One source, but the generated skills would assume an ASCENT scaffold's paths and personas, and would still have no scripts. Rejected.
- **Build the scaffold's skills from the plugins instead.** The right direction later, and recorded as a consequence; doing it now would change every scaffolded project in the same release as three new plugins. Deferred.
- **Three releases in one pull request,** as v0.4.20 to v0.4.22. Three changelog sections and tags for one design. Rejected for one release.
- **Rate decision traceability Strong.** The drift check sees only declared constraints; Strong would overstate it. Rejected.
- **Skip the new lenses.** A change that rewrites an accepted ADR or breaks a documented command would pass review unseen. Rejected.

## Consequences

- Easier: decisions, session records and documentation are checked in any repository, with rule ids and file:line evidence; the release record and the gate cover three more plugins.
- Easier: a rewritten accepted ADR is caught from history, not from memory.
- Harder: the embedded skills and the plugins overlap and can drift apart until the scaffold is built from the plugins.
- Harder: the delivery loop has nine lenses; a change that records a decision or touches what documents name runs one or two more reviewers.
- Easier: the framework's own ADRs are held to the rule they set for others, on every gate run.
- Neutral: the ownership registry, the capability map and the README banner grow by three plugins.

## Cost implications

- **Time:** ten skills, two agents, six scripts and their tests and negative controls; several working sessions, and the largest release so far.
- **Complexity:** three more plugins in the gate and in CI's control groups; two more delivery lenses.
- **Future flexibility:** keeps open building the scaffold from the plugins, and adding constraint kinds to `decision-drift`.
- **Money:** none directly. A reviewer run costs tokens; the README states the ranges. The gate's full-history checkout adds a few seconds to each gate job.
