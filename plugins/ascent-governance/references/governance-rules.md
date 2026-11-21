# Governance rules

What `ascent-governance` reads, writes and checks, and the rules for it. It answers one question for one environment: is this project ready to go live here? The answer is GO, NO-GO or GO WITH CONDITIONS, and every reason cites a file, a line or a script.

It checks that the evidence exists and is current. It cannot tell whether the system is good: a review can be generous and a test can be weak. The other plugins judge quality; this one keeps the record of what was judged, when, on which commit, and who accepted it.

## The ladder and the floors

`governance.environments` lists the project's environments, lowest first (`[local, beta, prod]` by default; any names work). `governance.floors` says what each one needs. An environment inherits the floor of every environment below it, so each floor lists only what it adds. A floor is a floor, never a ceiling.

A floor has three kinds of item:

| Item | What it is | How it is checked |
|---|---|---|
| `checks` | bash checkers of the other plugins, named `<plugin>/<script>`; `delivery/gate` is the contract's own `delivery.gate` command, run with `sh -c` | run fresh every time, with options taken from the contract (`scripts/lib/adapters.tsv`); a plugin that is not available is unmeasured, never a failure |
| `reviews` | reviews that need Claude's reading, each with the most days its newest record may be old | read from the review log; never run by the script |
| `sign_off` | a person signs the launch record | the newest launch record of the environment, its signer, and what changed since |

With no `floors`, default floors follow `governance.maturity_target` (else the most lenient `maturity_target` in the contract, else `prototype`) and what the repository contains: no UI files, no UX items; no infrastructure code, no operations items. At `prototype` only the local floor applies, and the local floor is `ascent-security/check-env`, plus `delivery/gate` when the contract has a `delivery.gate`.

## The review log

`governance.review_log` (default `docs/governance/review-log.md`) is a Markdown file with one table. Only `launch-readiness` and `review-record` write it, one row at a time, after approval. Rows are only added.

```
| Date | Review | Commit | Rating | High | Medium | Low | Open High rules | Asked by |
|---|---|---|---|---|---|---|---|---|
| 2026-11-28 | sec-posture | 1a2b3c4 | moderate | 1 | 2 | 0 | SEC-L4 | ana-lopez |
```

- **Review** is the name the floor uses. The reviews the default floors name, and the skill that gives each rating:

  | Review | Skill |
  |---|---|
  | `sec-posture` | `ascent-security:sec-posture` |
  | `ux-review` | `ascent-ux:ux-review` |
  | `architecture-review` | `ascent-architecture:architecture-review` |
  | `ops-review` | `ascent-ops:ops-review` |
  | `quality-review` | `ascent-quality:quality-review` |

  A project may name any other review in a floor; its row is recorded the same way.
- **Commit** is the commit the review read, 7 to 40 hex digits.
- **Rating** is the review's own `strong`, `moderate` or `weak`. A review that gives none is recorded from its findings: `weak` with any High, `moderate` with any Medium, else `strong`.
- **Open High rules** is the rule id of every open High finding, one id for each finding (the same id twice when two findings break one rule), separated by spaces, or `-`. A High count above the number of ids is a High finding (GOV-R2). A High finding with no rule id is given a name (`ARCHITECTURE-REVIEW-NO-BACKUP`) and keeps it in later rows.

The newest readable row of a review, by date, is the one that counts. A row that cannot be read never counts, and when it is newer than the review's newest readable row the review is due (GOV-R1): an older record does not stand for a newer one. Every table row below the header is a row of the log, whatever stands between two rows, so none is dropped in silence.

## Waivers

A waiver is an entry of any section's `waivers` list in the contract (`security.waivers`, `governance.waivers`, and so on). Each names an accepted ADR (`id`), what it skips (`skips`) and when it is looked at again (`review_by`). A waiver covers an open High rule of a review when it names that rule id as a whole word, has not expired, and its `review_by` is a real date. `decisions.acknowledged_changes` entries are listed beside the waivers and are not waivers: they never expire.

## The launch record

`<governance.launch_dir>/<date>-<environment>.md`, one per launch. `check-audit.sh --record` writes it, unsigned, only when the working copy is the commit it names. `launch-readiness` adds the plain-words summary. A person adds their name and the date and commits it. Nothing else in it is edited.

```
# Launch record: <project>, <environment>

<date> · commit <short id> · maturity <target> (<where it came from>) · ascent-governance <version>

**Verdict:** GO | GO WITH CONDITIONS | NO-GO

## In plain words
## Evidence            | What | Kind | Result | Source |
## Waivers in force    | Waiver | Section | What it skips | Review by | Days left |
## Conditions          a numbered list, High first
## Sign-off

**Signed:**

**Date:**
```

A signed record holds while nothing but launch records and the review log changes after the commit it names. Any other change needs a new record and a new signature. The same result is written to the CI job summary when `$GITHUB_STEP_SUMMARY` is set, and `--html` writes it, or a record (`--from`), as one page that stands alone.

## Rules

| Id | Severity | Rule | Checked by |
|---|---|---|---|
| GOV-S1 | High | the governance section says what its author thinks: every key is one this version reads, with the kind of value it expects (a misspelled `sign_off`, or `sign_off: yes`, fails instead of dropping the sign-off), every floor is for an environment on the ladder, every check is `<plugin>/<script>`, every review age is a whole number above 0 | `check-audit.sh` |
| GOV-S2 | Medium | every check on the floor could be run: it has an adapter, and its checker accepted the contract's values | `check-audit.sh` |
| GOV-L1 | High | every check on the floor passes; a checker that stops without finishing has not passed. A check that fails with only Medium or Low findings is Medium or Low, as its most severe finding is (ADR-029) | `check-audit.sh` |
| GOV-L2 | Low | every check on the floor is measured: its plugin is available, the contract gives the input it needs, and it had something it could check | `check-audit.sh` |
| GOV-L3 | High | on a rung with sign-off, or above one, the newest launch record of the environment is signed by a person, dated, and not a NO-GO | `check-audit.sh` |
| GOV-L4 | High | the signer is in `governance.approvers`, when that list is not empty | `check-audit.sh` |
| GOV-L5 | High | nothing but launch records and the review log changed since the commit the signed record names | `check-audit.sh` (git) |
| GOV-W1 | High | no waiver is past its `review_by` | `check-audit.sh` |
| GOV-W2 | Low | no waiver is due for review within 14 days | `check-audit.sh` |
| GOV-W3 | Medium | every waiver has a `review_by` that is a real date | `check-audit.sh` |
| GOV-W4 | Medium | every waiver says what it skips, and its `id` is an ADR whose status is Accepted | `check-audit.sh` |
| GOV-R1 | Medium | every review on the floor has a row no older than the floor allows; High when the launch question is asked (`--launch`) | `check-audit.sh` |
| GOV-R2 | High | the newest row of each review names the rule of every open High finding, and none is a rule that no waiver covers; Medium when it is rated weak | `check-audit.sh` |
| GOV-R3 | Medium | every row of the review log can be read | `check-audit.sh` |
| GOV-R4 | Medium | rows of the review log are only added: none was removed or changed since the newest signed launch | `check-audit.sh` (git) |

**Verdict.** NO-GO: any High. GO WITH CONDITIONS: no High, and any Medium, Low or unmeasured item. GO: none. In a project's CI the script exits 1 only for NO-GO, so a review that is due is reported and the run stays green; `launch-readiness` asks the launch question, where it is a NO-GO. N/A is never a pass: it says there was nothing to check.

## Limits

- The checks prove that evidence exists and is current. They cannot tell whether a review was thorough, whether a rating was deserved, or whether a row names every open High finding: the row is in git for a person to read.
- A check is as good as its checker. `check-audit.sh` runs the other plugins' scripts with the contract's values and reports their result; it does not re-judge them.
- A signature is a line a person types. The script checks that it is there, dated, by a listed approver when there is a list, and that the code has not changed since. It cannot tell who typed it: the commit that adds it is the evidence.
- Nothing here blocks a deploy by itself. A project makes it a gate by running `check-audit.sh` in its own CI.
