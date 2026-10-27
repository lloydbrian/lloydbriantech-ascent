# ADR-015: An ownership registry and gate for framework integrity; auditability and the conductor deferred

**Status:** Accepted (2026-10-27; T13 fails on `main` at v0.4.7 for the lens drift and passes on v0.4.8)
**Date:** 2026-10-27 (America/New_York)
**Decider:** lloydbriantech

## Context

ASCENT ships five plugins, with more on the roadmap, and [ADR-014](ADR-014-testing-ownership-and-dependency-scan.md) sets one owner for each testing type. Nothing checks that ownership. Design-time documents (ADRs, [PILLARS.md](../PILLARS.md), the sibling pattern) record it in prose, and the plugin gate (T1–T12) checks each plugin on its own, never across plugins.

An inventory of `main` at v0.4.7 found the drift this allows:

- **The delivery loop's lens tables are stale.** They list no provider for UX and navigation, and never mention `architecture-reviewer` or `ops-reviewer` (`plugins/ascent-delivery/skills/delivery-loop/SKILL.md`, `references/review-lenses.md` and the plugin README, at v0.4.7). Those agents and `ux-reviewer` all describe themselves as "a delivery-loop review lens".
- **Rule-id families are unique only by luck.** The first ADR-014 drafts proposed three families whose letters were already taken: D (ux design directions), H (ux heuristics) and O (architecture deployment options). A bare id such as `S3` does not say which plugin raised it.
- **Cross-plugin markers** (`→ ascent-security`, `→ ascent-architecture`) and the README plugin version table have no check.

During scoping the operator also asked whether ASCENT should govern how *projects* use the plugins, and how owners who do not know which plugins to install can be sure none is missing, without limiting what operators can use.

## Decision

1. **An ownership registry, [`docs/framework/OWNERSHIP.md`](../OWNERSHIP.md).** It is both a document and data: seven marked tables (repository signals, plugins, components, rule-id families, reserved names, domains and testing types, review lenses), parsed by awk. Planned plugins and families get rows before they are built, so their names, codes and prefixes are reserved.
2. **Gate check T13 in `make test-plugins`**, from `make/check-ownership.sh` (`make ownership` runs it alone). The tables are checked, not generated.

   | Rule | Fails when |
   |---|---|
   | T13.0 | the checker's own fixture tests (`tests/meta/test-check-ownership.sh`) fail |
   | T13.1 | a marked table is missing, repeated, empty, or has a row with the wrong number of cells |
   | T13.2 | plugin directories, marketplace entries and released rows disagree; a planned plugin has a directory; a released plugin has no signal row |
   | T13.3 | a skill, agent or hook of a released plugin is not registered, or a registered one does not exist |
   | T13.4 | two plugins share a code or two families a prefix; a family's prefix does not start with its plugin's code; its defining file never mentions its first id; a reserved name is used by another plugin |
   | T13.5 | a plugin's contract template declares a section other than its own, or two plugins claim one section |
   | T13.6 | a `→ ascent-<name>` marker names no released plugin |
   | T13.7 | a domain has two rows, or an owner that is not a registered plugin, `operator` or a template skill |
   | T13.8 | a delivery lens table differs from the registry; an `ascent-*` provider is not a registered agent or skill; an agent that calls itself a "delivery-loop review lens" provides none |
   | T13.9 | the README plugin table disagrees with a `plugin.json` version, or PILLARS.md's "Checked by" column names a plugin or component that does not exist |
   | T13.10 | a rule-table id or script-header id in a plugin is not plugin-qualified, or a qualified id names no registered or reserved family |

3. **Plugin-qualified rule ids, `<CODE>-<family><n>`** (decided by the operator, 2026-10-27).
   - **Codes:** `SEC`, `DEL`, `ARC`, `UX`, `OPS`; `QA` and `GOV` reserved. For example `OPS-S3` or `UX-D2`.
   - **Existing ids migrate in this release:** `ARC-C`, `ARC-P`, `ARC-O`, `ARC-B`; `OPS-S`, `OPS-Z`, `OPS-M`; `UX-U`, `UX-H`, `UX-D`. That covers every definition, emitter, reference, test and negative control. Report output changes, so `ascent-architecture`, `ascent-ops` and `ascent-ux` move to 0.2.0. No aliases are kept.
   - **Planned families** are born qualified and reserved now: `SEC-D`; `QA-I`, `QA-T`, `QA-H`; `OPS-R`, `OPS-X`.
   - **Not renamed:** accepted ADRs, closed plans and past CHANGELOG entries, which are immutable history (the v0.4.8 CHANGELOG entry carries the mapping). Also the internal ids (T gate checks, P controls, V validator cases), registered as `internal`, and test-case ids local to one test file.
   - Scripts keep short internal keys and add the code where they print, so a finding reads `FAIL  OPS-S3 …`.
4. **The delivery loop's lenses become provider lists, ASCENT agents first**, in all three lens tables, as `ascent-delivery` 0.1.2:
   - `ux-reviewer` for accessibility and for UX and navigation, run once when it serves both
   - `ops-reviewer` for operational and deploy impact
   - a new architecture and cost lens served by `architecture-reviewer`, with its own fallback prompt
5. **Discovery for project owners.** The registry's `signals` table ("Which plugins do I need?") maps what a repository contains to the plugin that checks it, with the reason. The README links to it. Each plugin's "Recommended next" line will also name an uninstalled plugin whose signals are present; this is a follow-up, not part of this release.
6. **Rules that protect operators**, binding on every future governance or auditability feature:
   - Required plugins are a floor, never a ceiling. There is no allowlist, and every agent and plugin, ASCENT or not, stays usable.
   - A missing plugin makes its lens "unmeasured". It never blocks anything.
   - Nothing blocks except the operator boundary hook and gates a project opts into.
   - Prototype maturity requires almost nothing.
7. **Project-facing governance is auditability work, recorded as a committed follow-up under Compliance**, scoped when it starts: a waiver ledger with expiry dates, dated review records, a required-plugin floor in the contract, and a bash checker a project can run in its own CI. It closes the Partial rows "Decision traceability" and "Change audit trail".
8. **The conductor is deferred.** `ascent-governance` (code `GOV`, reserved), with agent `governance-conductor` and skills `governance-review` and `launch-readiness`, ships when launch readiness is scoped. It will read the registry, which `make plugins` will copy into it as a generated file, and the auditability evidence. Launch readiness belongs to it, not to `ascent-delivery`.
9. **Release order:** v0.4.8 this governor and the id migration; v0.4.9 `ascent-security` 0.2.0 (dependency check); v0.4.10 `ascent-quality` 0.1.0; v0.4.11 `ascent-ops` 0.3.0 (recovery drills and readiness exercises).
10. **Tests:** T13 is proven in five layers:
    - fixture tests for the parser and every rule, including formatting edge cases (T13.0)
    - a run against `main` at v0.4.7 with the registry added, which fails T13.4, T13.8 and T13.10 on the real drift and the unqualified ids
    - negative controls in a new `ownership` mutant group
    - the full gate
    - portability across `/bin/bash` 3.2, BWK awk (macOS), mawk and gawk

## Alternatives considered

- **A governing agent that every other agent reports to.** Rejected. It would break the sibling pattern (`skills/lloydbriantech-ascent/references/patterns.md`), become the overlap it is meant to prevent, and still not stop a bad change from merging. A gate does.
- **A YAML registry.** Rejected for now. The repository's tools are portable bash and awk under `/bin/bash` 3.2, with no YAML parser. Marked markdown tables are already parsed this way (T5).
- **Generate the lens tables and the README table from the registry.** Rejected. `make plugins` only writes files carrying the GENERATED marker, and the delivery skill is hand-written. Checking is simpler, and T13 names the missing row.
- **Two-letter prefixes for new families only, existing single letters kept.** Rejected by the operator. A bare id would still not say which plugin raised it, and reports would mix formats.
- **Migrate the existing ids in each plugin's next minor release.** Rejected. Reports would mix formats for several releases. With the plugins days old and used only in trials, this is the cheapest time to change.
- **Qualify ids only where several plugins meet (registry, waivers, conductor).** Rejected. A short id seen on its own would stay ambiguous.
- **Build the conductor and project governance now.** Rejected. With five plugins, the delivery loop's lenses already give a per-change review, and project governance needs the auditability evidence first. Building them now would add a plugin before its inputs exist.
- **Check that every marker points at the owner of its domain.** Rejected for now. Markers carry no domain label, so the check would guess.

## Consequences

- Adding a plugin, skill, agent, hook, rule family, contract section or lens now starts with a registry row. CONTRIBUTING says so, and T13 enforces it.
- The delivery loop uses the ASCENT reviewers whenever they are installed. Operators with the plugins installed get the specialised reviews they expected.
- The registry becomes the first place to look for "who owns this?", and PILLARS.md's plugin names cannot go stale.
- Every rule id says which plugin raised it. Waivers, audit trails and the future conductor can cite an id without a plugin name beside it.
- Report output changes in three released plugins (0.2.0). Anyone parsing the old ids must update; the CHANGELOG gives the mapping.
- Ids are longer (`OPS-S3` instead of `S3`). Tables and report lines stay readable, and ranges are written `OPS-S1–S10`.
- The rename had to tell rule ids from look-alikes such as "S3" the AWS service and "C4" the diagram model, so it was done from definition and emitter sites, with every replacement logged and reviewed.
- T13 cannot judge semantics. It can tell that a domain has one owner, not that the owner is the right one. Ownership decisions stay in ADRs; T13 keeps them from drifting.

## Cost implications

- **This release:** about 300 lines of checker, a registry of about 170 lines, about 400 lines of fixture tests (69 cases), 36 ownership controls (P205–P240), the delivery lens changes, and the id migration (about 1,000 occurrences in about 50 files, each logged).
- **CI:** one new mutant group, expected well under the job limit at about 7 seconds per control (ADR-013), to be measured. T13 adds a few seconds to `make test-plugins`.
- **Recurring:** every structural change to a plugin also edits the registry. That is the point: T13 says exactly which row is missing.
- **Future flexibility:** when the conductor ships, the registry is copied into it unchanged. If a YAML parser ever becomes available, the tables can move to YAML behind the same T13 rules.
