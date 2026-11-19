# Decision rules

The rules `ascent-adr` checks, the ADR formats it reads, and how a decision is kept. The skills and the agent cite this page; the scripts' headers carry the same rules.

## Formats

An ADR is a Markdown file in the ADR folder named `NNNN-title.md` or `ADR-NNN-title.md`. A numbered template such as `0000-template.md` is not an ADR.

| Format | How it is recognised | Required sections (`## `) | Status | Date |
|---|---|---|---|---|
| `ascent` | a `## Cost implications` section | Context, Decision, Alternatives considered, Consequences, Cost implications | `**Status:** Accepted` | `**Date:** YYYY-MM-DD` (both may share a line, split by a vertical bar; a date in the status line, `Accepted (YYYY-MM-DD)`, counts when there is no date field) |
| `nygard` (and adr-tools) | anything else | Context, Decision, Consequences | the line after `## Status` | `Date: YYYY-MM-DD` |
| `madr` | a `## Decision Outcome`, `## Considered Options` or `## Context and Problem Statement` section | Context and Problem Statement, Considered Options, Decision Outcome | `status:` in the front matter, or `* Status:` | `date:` in the front matter, or `* Date:` |

`decisions.style` names the format every ADR must follow; `auto` takes the format most ADRs use. A repository that mixes formats sets the one it is moving to.

Statuses: `proposed` (or `draft`), `accepted`, `rejected`, `deprecated`, `superseded by ADR-N`. Supersession is recorded both ways: the old ADR's status says `Superseded by ADR-N`, and the new ADR says `supersedes ADR-M` (ASCENT writes "This ADR supersedes ADR-M" at the top of its Context; adr-tools writes `Supersedes [M. Title]` with a link to the old file under its Status).

## Keeping a decision

- **An accepted ADR's body never changes.** Only its status changes, when a later ADR supersedes or deprecates it. A new decision is a new ADR. `DEC-S8` compares each accepted ADR with the commit that first recorded it as accepted, using `git log` and `git show`.
- **A known older change is acknowledged, never hidden.** `decisions.acknowledged_changes` names the ADR and the commit up to which a change is accepted, with the reason; the check then compares with that commit and prints a NOTE, so a later change still fails.
- **Constraints make a decision checkable.** `decisions.constraints` states what an accepted ADR requires of the code: a pattern that must not appear (`forbid`, optionally `under` some paths) or a path that must exist (`require`). A person confirms each one. Only what is declared is checked.

## Rules

| Id | Severity | Rule | Checked by |
|---|---|---|---|
| DEC-S1 | Medium | a decision record exists: an ADR folder holding an ADR | `check-adrs.sh` |
| DEC-S2 | Medium | every ADR has the sections its format requires | `check-adrs.sh` |
| DEC-S3 | Low | ADR numbers are unique, every Markdown file in the folder is named as an ADR, and a number in a title matches its file | `check-adrs.sh` |
| DEC-S4 | Low | the index lists every ADR, links to no missing file, and gives the status the ADR gives | `check-adrs.sh` |
| DEC-S5 | Medium | every ADR has a known status | `check-adrs.sh` |
| DEC-S6 | Medium | supersession is recorded both ways, and the replacement exists | `check-adrs.sh` |
| DEC-S7 | Low | every ADR has a real date, not after today | `check-adrs.sh` |
| DEC-S8 | Medium | an accepted ADR's body is unchanged since it was accepted | `check-adrs.sh` (git) |
| DEC-C1 | Medium | no file matches a `forbid` constraint of an accepted ADR | `check-decision-drift.sh` |
| DEC-C2 | Medium | every path a `require` constraint of an accepted ADR names exists | `check-decision-drift.sh` |
| DEC-C3 | Low | every constraint names an ADR that exists and is accepted | `check-decision-drift.sh` |

At prototype maturity every finding is a NOTE. N/A is never a pass: it says there was nothing to check.

## Limits

- The checks prove that decisions are recorded, complete, linked and kept, and that declared constraints hold. They cannot tell whether a decision is right, or whether the code honours an ADR in ways no constraint states. A reviewer reads for that, and reports it under **Other observations (unrated)**.
- Waivers that other plugins accept (an ADR id in a contract's `waivers`, an accepted threat) are those plugins' checks; `ascent-adr` checks the ADR itself.
