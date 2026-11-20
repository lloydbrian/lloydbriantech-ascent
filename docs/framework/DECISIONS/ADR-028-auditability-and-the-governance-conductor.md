# ADR-028: Auditability and the governance conductor: launch readiness in ascent-governance

**Status:** Accepted
**Date:** 2026-11-19 (America/New_York)
**Decider:** lloydbriantech

## Context

A project goes live three times: locally, where the operator or owner uses it; in beta, where other people do; and in production, with real users. Before v0.4.24 the evidence that a project was ready for any of these lived in nine plugins' chat reports, in waiver lists spread over the contract's sections, and in the operator's memory. Nobody could answer "are we ready for beta?" without opening every report and deciding by feel. An auditor's first two questions, "what have you knowingly not done, and until when?" and "when was each area last reviewed?", had no answer on disk.

[ADR-015](ADR-015-ownership-registry-and-gate.md) committed two follow-ups (decisions 7 and 8) and reserved their names: auditability for projects, and a governance conductor, `ascent-governance` (code `GOV`). [PILLARS.md](../PILLARS.md) rated "Change audit trail" Partial because its rule had no behavior tests or negative controls. A third follow-up was pending since 2026-10-27: a review's "Recommended next" line should name a plugin the repository needs and the session lacks. ADR-015 decision 6 binds all of it: required evidence is a floor and never a ceiling, a missing plugin is unmeasured and never blocks, and nothing blocks a project except the operator-boundary hook and a gate the project opts into.

In nearly every project the operator is the only builder and the only approver.

The operator approved the design on 2026-11-19: the ladder of local, beta and prod; approach C below; one result in three views; and that a review which is due is a condition in CI and a NO-GO only when the launch question is asked.

## Decision

1. **One question per environment.** `ascent-governance` answers "are we ready for this environment?" with GO, NO-GO or GO WITH CONDITIONS, and every reason cites a file, a line or a script. The environments are a ladder in a new contract section, `governance` (`environments`, default `[local, beta, prod]`). Each environment has a floor and inherits the floors below it. A floor is a floor, never a ceiling. A key of the section that this version does not read, or a value of the wrong kind, is a High finding (GOV-S1): a misspelled `sign_off` would otherwise drop the sign-off in silence.
2. **Evidence in two kinds.** Scripted checks are the other plugins' bash checkers, named `<plugin>/<script>` in the floor and run fresh every time by `check-audit.sh`, at no token cost. Reviews that need judgement leave one dated row in a review log, with a maximum age in the floor. A checker whose plugin is not available is unmeasured (GOV-L2, Low), never a NO-GO.
3. **The review log is only added to, and only `ascent-governance` writes it.** A row names the date, the review, the commit, the rating, the counts of High, Medium and Low findings, the rule ids of open High findings, and who asked. The review plugins stay read-only. A removed or changed row is found from git history (GOV-R4). Every table row below the log's header is a row, and a row that cannot be read never counts: when it is newer than a review's newest readable row, that review is due. A row names one rule id for each open High finding.
4. **One view of every waiver.** Each contract section's `waivers` list is read where it already is. A waiver needs an id that is an accepted ADR, what it skips, and a `review_by` date: past the date it is High (GOV-W1), within 14 days Low (GOV-W2), with no date, without saying what it skips, or with no accepted ADR Medium (GOV-W3, GOV-W4). `decisions.acknowledged_changes` entries are listed apart: they are not waivers and never expire. A waiver covers a review's open High finding by naming its rule id.
5. **The launch record: the script writes it, Claude adds a summary, a person signs.** `check-audit.sh --record` writes `<launch_dir>/<date>-<environment>.md` with the commit, the verdict, the evidence table, the waivers in force and the conditions, only when the working copy is that commit, and never over an existing record. `launch-readiness` adds two or three sentences in plain words. Only a person writes after `Signed:` and `Date:`. On a rung with `sign_off`, the newest record must be signed and not NO-GO (GOV-L3), by a listed approver when the contract lists any (GOV-L4), and nothing but launch records and the review log may have changed since the commit it names (GOV-L5).
6. **One result, three views.** The launch record in the repository; the same result added to `$GITHUB_STEP_SUMMARY` when CI sets it; and one HTML page (`--html`, or `--html --from <record>` for a signed record) with no script and nothing fetched, a dark theme and a print style. The page is generated, never edited, and never written into the launch folder or through a link. Text from the contract or from a checker is escaped in all three, so it cannot forge a table cell, a link or a tag.
7. **What CI fails on.** A project that runs `check-audit.sh` in its own CI gets a non-zero exit only for what the script can check itself: a failing check, an expired waiver, an open High finding of a recorded review, or a rung with `sign_off` and no valid signed record. A review that is due is Medium there, so a weekly run stays green and says what is due; with `--launch` it is High, so `launch-readiness` answers NO-GO.
8. **The plugin.** `ascent-governance` 0.1.0, hand-written: skills `launch-readiness` (entry point, the `gov-severity` table), `governance-review` (every environment, read-only) and `review-record` (one row, after approval); agent `governance-conductor` (Read, Grep, Glob; it reports "blocked" or "no blocker found by reading" and never says GO); `scripts/check-audit.sh` with rule families `GOV-S` (the section can be read and run), `GOV-L` (floors and sign-off), `GOV-W` (waivers) and `GOV-R` (review records).
9. **Checkers are run from the contract through one adapter table.** `lib/adapters.tsv` says, for each checker, which contract keys become which options. A behavior test holds every option in the table against that checker's own usage line, so a renamed option fails the gate instead of silently skipping a check. A checker that refuses its options (exit 2) is a broken adapter (GOV-S2, Medium), never a NO-GO; one that stops any other way has not passed (GOV-L1). A checker that had nothing it could check is unmeasured, never a pass. A check whose input the contract does not give is unmeasured: with no `ux.pages`, the flow check does not run, because a scan of every file in the repository reports generated pages as the product.
10. **Defaults when the contract has no `governance` section.** The maturity is `governance.maturity_target`, else the most lenient `maturity_target` among the contract's sections, else prototype; the output says which. Prototype gets the local floor only. Default floor items are kept only where the repository shows that plugin's signal: no UI files, no UX items.
11. **The `.env` check belongs to `ascent-security`.** `scripts/check-env.sh` (SEC-E1–E3: no tracked `.env`, every `.env` ignored, every `.dockerignore` excludes it) ships in `ascent-security` 0.4.0 and is the local floor's first check. Security checks live in the security plugin.
12. **Holding production is opt-in.** A project holds a deploy by making its deploy job need the CI step; there is no contract flag. `ascent-delivery` 0.2.2: when the contract has a `governance` section, the prod runbook's second step runs `check-audit.sh --env prod`, labelled C, and stops on NO-GO; when `ascent-governance` is not available, the loop says so and skips it.
13. **"Recommended next" names missing plugins.** Every hand-written skill whose Output has a "Recommended next" line also names a plugin whose signal the repository shows and whose skills the session lacks. Because an installed plugin has no `docs/framework/`, `make plugins` writes the registry's signals table into each such plugin as `references/plugin-signals.md`, and the whole registry into `ascent-governance` as `references/registry.md`. Gate check T1 compares every generated file with a fresh build.
14. **The framework uses it.** This repository's contract gains `governance` with the ladder `[local, release]` and a release floor of `ascent-adr/check-adrs`. Gate check T17 runs `check-audit.sh --env release` and fails on a NO-GO or any failure other than a waiver that is due soon.
15. **`ascent-node-stack` moves to last** on the roadmap, after this work.

## Alternatives considered

- **A. Every review plugin leaves its own record.** Full history, but all eight review plugins change, lose their read-only promise or gain a write step, and a forgotten record looks like a stale review. Rejected.
- **B. Nothing is recorded: the conductor reruns what a rung needs on every ask.** Always current and nothing to forget, but every "ready for prod?" costs six or more full reviews in tokens, CI can cover only the scripts, and there is no audit history. Rejected.
- **C. A mix: scripted checks run fresh, and only judgement reviews leave a record, written by `ascent-governance`.** Most evidence is free and cannot go stale, history exists where judgement is the evidence, and the review plugins stay read-only. Chosen by the operator.
- **A claude.ai page as the record.** It lives outside the repository, CI cannot produce it, and it can drift from the signed file. Rejected for the record; the HTML page is generated from the record instead.
- **Fail CI when a review is due.** A weekly job would turn red for something only a Claude session can fix. Rejected: due reviews are conditions in CI.
- **Move every waiver into one new file.** Each plugin already reads its own list; a migration would break existing contracts. Rejected: the lists stay and are read together.
- **A `.env` check inside `ascent-governance`.** It would put a security rule outside the security plugin. Rejected.
- **A contract flag that makes the check a gate.** A second place to configure what the CI file already says. Rejected.

## Consequences

- Easier: "are we ready for beta?" has one answer, from evidence on disk, and the same answer in a session, in CI and on a page a person can be sent.
- Easier: waivers and reviews come back as findings when their dates pass; nothing is waived forever by accident.
- Easier: the change audit trail has checked records: who accepted each change (ADR-024), who signed each launch and on which commit, and when each review last ran.
- Limit: it checks that the evidence exists and is current, not that the system is good. A review row records a rating a session gave; the script cannot tell whether the row names every open High finding.
- Limit: GOV-L5 compares commits, not the working copy, and a signed launch starts a new window for GOV-R4. One launch record is kept per environment per day.
- Limit: `delivery/gate` runs the contract's own `delivery.gate` command with `sh -c`, so a change to that line deserves the review a build script gets.
- Harder: decision traceability stays Partial. Waivers now name accepted ADRs, but [ADR-027](ADR-027-decision-session-and-documentation-plugins.md)'s limit holds: only declared constraints are checked against the code.
- Harder: a change to `OWNERSHIP.md` now needs `make plugins` and a version bump of `ascent-governance`, whose `registry.md` is a copy of it; a change to the signals table needs a bump of the eight plugins that carry `plugin-signals.md`.
- Harder: the adapter table must follow every checker's options. The test that holds it fails the gate when one moves.
- Neutral: the registry, the capability map and the README banner grow by one plugin; the gate has seventeen sections.

## Cost implications

- **Time:** three skills, one agent, one script with six awk libraries and an adapter table, a checker in `ascent-security`, nine behavior-test suites and 426 negative controls; the largest single plugin so far.
- **Complexity:** `check-audit.sh` depends on the option names of nine checkers in seven plugins. The generated registry copies couple plugin versions to `OWNERSHIP.md`.
- **Money:** none directly. A launch-readiness run with every review current costs about as much as a focused check; each review that is due adds that review's cost. The scripted checks cost no tokens, in a session or in CI.
- **Future flexibility:** keeps open more than one approver per launch, a review log entry written by a review plugin's own script, and building the scaffold's release-readiness skill from this plugin. It closes none of them.
