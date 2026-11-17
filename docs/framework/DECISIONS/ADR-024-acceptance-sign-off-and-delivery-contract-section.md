# ADR-024: Acceptance sign-off and the `delivery:` contract section in `ascent-delivery` 0.2.0

**Status:** Accepted
**Date:** 2026-11-16 (America/New_York)
**Decider:** lloydbriantech

## Context

[ADR-014](ADR-014-testing-ownership-and-dependency-scan.md) split user acceptance in two. `ascent-quality` 0.1.0 owns criterion → test traceability (QA-T1), and `ascent-delivery` 0.2.0 owns the sign-off record. Until now, the sign-off had no record:

- **The definition of done said "every acceptance criterion maps to a test or a recorded manual check"**, but there was nowhere to record it. The evidence lived in chat or in a pull request description, and a change could reach prod without anyone saying, in writing, that it does what was asked.
- **Nothing separated who drafts from who accepts.** Claude restates the criteria (Step 1) and finds their evidence (Steps 3 and 5). Acceptance is a person's judgment about the running change. If Claude can write "accepted", the record proves nothing.
- **The delivery contract was a file of its own.** [ADR-010](ADR-010-delivery-loop-plugin-and-operator-boundary-hook.md) created `.delivery-loop.yml` for the delivery loop alone. [ADR-011](ADR-011-architecture-plugin-and-project-contract.md) then made `.ascent/contract.yml` the project contract, with a section per plugin, and said `ascent-delivery` 0.2.0 would read a `delivery:` section there and keep accepting `.delivery-loop.yml`. The acceptance settings (where records go, who may accept) need a home, and adding them to the older file would deepen the split.
- **Runbook steps did not say who runs them.** The operator runs every step that writes. Read-only steps (confirm the tree, smoke, the acceptance check) could be run by Claude and reported, but the runbook did not mark which were which.

## Decision

1. **An acceptance record per change.** The definition of done drafts `<acceptance_dir>/<YYYY-MM-DD>-<slug>.md` (default `docs/delivery/acceptance/`) from the plugin's `acceptance-template.md`. Its table has one row per criterion from Step 1, with the columns Criterion, Evidence, Accepted by and Accepted on (a `#` column is optional). Evidence is a test at `path:line` (or `path:line-line`) inside the repository, or `manual: <what was checked, where>`; several items are separated by `;`.
2. **Only a person accepts.** Claude fills the Criterion and Evidence columns. "Accepted by" and "Accepted on" are filled by the person who checked the criterion on beta, and the operator commits the record through its own pull request. Claude never fills either column, even when asked, and never accepts on anyone's behalf.
3. **`check-acceptance.sh` checks the record, read-only, rule family `DEL-A`.** All three checks are High:
   - **DEL-A1**: every criterion has evidence, and each `path:line` exists inside the repository (no absolute path, no `..`, the line within the file). A record with no criteria fails.
   - **DEL-A2**: every criterion is accepted by a person, by name, on a real date that is not after today. A placeholder, an empty cell, Claude, an assistant or a bot is not a person.
   - **DEL-A3**: when the contract lists `delivery.acceptors`, every "Accepted by" is one of them (case and spacing ignored). With no list, any person counts.

   Output is a `FAIL` line per finding with `record:line`, a `PASS` or `N/A` line per check, and a summary line. Exit 0, 1 on any failure, 2 on bad input.
4. **The check runs twice.** The definition of done runs it with `--draft`, which checks DEL-A1 only, before anyone has signed. Before prod, it runs in full, with `--acceptor` once per listed acceptor. The prod runbook's first step is that check, labelled [C], and its Stop-if is any `FAIL`: **an incomplete record stops prod.**
5. **The contract is the `delivery:` section of `.ascent/contract.yml`** (or of `.claude/contract.yml`), with the keys `.delivery-loop.yml` had plus `acceptance_dir` and `acceptors`. The plugin's `references/contract-template.yml` declares that section alone, as T13.5 requires. `.delivery-loop.yml` keeps working: the skill reads it when there is no `delivery:` section. When both exist, the skill uses the section, names every key whose value differs, and tells the operator the older file can go once they agree.
6. **The operator-boundary hook blocks the union.** It reads `deploy_beta` and `deploy_prod` from every contract it finds: `.delivery-loop.yml`, and the `delivery:` section of `.ascent/contract.yml` and of `.claude/contract.yml`. A key outside the `delivery:` section (a top-level key, or one in another plugin's section) is not read. Neither file can unblock what the other lists, and the block message names the file and key that listed the command.
7. **Runbook steps are labelled [C] or [O].** [C] is read-only and needs no credential: Claude may run it and report the result, or the operator runs it. [O] writes, deploys or needs the operator's credentials, and only the operator runs it. A step with any write in it is [O]. The runbook template gains an [O] acceptance step on beta and the [C] prod pre-flight.
8. **Tests and controls.** `tests/plugins/ascent-delivery/test-check-acceptance.sh` covers each check with negative cases that fail it and no other check, `--draft`, acceptor matching, the evidence forms, paths outside the repository, escaped bars, CRLF, column order, the shipped template and bad input, on every awk found. `test-operator-boundary.sh` covers the union (CRLF, keys outside the section, both files, `.claude/contract.yml`). `test-delivery-rules.sh` adds D4 to D8: only a person accepts, the record is checked at done and before prod, the contract text, the [C]/[O] labels, and the template's columns. The `ascent-delivery` control group adds P881 to P907, one or more per rule.

## Alternatives considered

- **Let Claude record acceptance when the operator says who accepted.** Rejected. The record would then show only that someone typed a name into a chat. Asking the person to write their own name and date is a small cost, and it is the point of the record.
- **Accept in the pull request (an approving review) instead of a file.** Rejected for now. It ties acceptance to one forge, and the reviewer of the code is often not the person who accepts the behavior on beta. A record in the repository also travels with the change and is checked offline.
- **Put `acceptance_dir` and `acceptors` in `.delivery-loop.yml`.** Rejected. ADR-011 already chose one contract file with a section per plugin; extending the older file would leave two homes for delivery settings.
- **Drop `.delivery-loop.yml` in 0.2.0.** Rejected. Projects that use it would lose their deploy blocks on upgrade. The union keeps every listed deploy blocked while a project moves.
- **Have the hook read only the file the skill reads.** Rejected. A stale `.delivery-loop.yml` could list a deploy that the new section dropped, and the hook would stop blocking it. The hook's job is to block, so it takes the union.
- **Make acceptance Medium (a warning) and let the operator decide.** Rejected. A prod deploy without a person's acceptance is what the record exists to prevent.

## Consequences

- A change reaches prod only with a committed record in which a person, by name, accepted each criterion on a date, against evidence that exists in the repository.
- The definition of done gains one item; the runbook gains one [O] step on beta, one [C] step before prod, and a label on every step.
- Projects on `.delivery-loop.yml` keep working unchanged. The skill offers to move them to the `delivery:` section when it next runs; until they agree, both are honoured and both are blocked.
- The record names people. The plugin asks for the name or handle they sign with, never an email address or phone number, and a handle is enough where a name should not be committed.
- Acceptance is now a step a person must do. A change can wait on beta for that person; this is intended.

## Cost implications

- **Time per change:** a few minutes for the accepting person to check the criteria on beta and sign, plus one small pull request for the record. Drafting the record and running the check are part of Steps 5 and 7.
- **Compute:** `check-acceptance.sh` is a single awk pass; it runs in well under a second.
- **Gate:** one new behavior suite under T11, five new rule groups in `test-delivery-rules.sh`, and 27 negative controls in the `ascent-delivery` group, which CI runs only when the plugin changes ([ADR-023](ADR-023-ci-runs-what-a-change-can-affect.md)).
- **Money:** none.
- **Flexibility:** the record format is plain Markdown, so a project can sign in any editor. A forge-based sign-off can be added later as another evidence form without changing the record.
