---
name: delivery-loop
description: >-
  Use when taking a feature or fix from decision to production in any repository
  ("run the delivery loop", "ship this change", "get this to prod", "write the
  hand-off runbook", "is this done?"). Runs decide, build with a file-modification
  audit, test with negative controls, gate, independent review checked by a
  finding verifier, fix and re-test, definition of done, an operator runbook,
  beta verification, prod and a release record. Claude never runs git writes or
  deploys: the operator does, from the runbook.
version: 0.1.0
allowed-tools: Read, Grep, Glob
---

# Delivery loop

One change, shipped safely, in any project. Claude builds, tests, reviews, verifies and writes the runbook. The **operator** (the human) owns git, deploys and every credential.

The loop is ASCENT's delivery standard in executable form. It works the same in a scaffolded ASCENT project and in any other repository.

## The operator boundary (always, in every project)

- **Claude NEVER runs git write operations**: commit, push, tag, merge, rebase, reset, revert, cherry-pick, stash, checkout or switch, branch create or delete, add, rm, mv, pull, worktree changes, config writes. It also never runs `gh` writes (pr create or merge, release create, workflow run, secret set, `gh api` writes).
- **Claude NEVER deploys or publishes.** That covers everything under `deploy_beta` and `deploy_prod` in the contract, and well-known deploy verbs (`terraform apply`, `kubectl apply`, `helm upgrade`, `aws s3 sync … s3://`, `npm publish`, `docker push`, `cdk deploy` and the like).
- There is no "unless asked" exception. If the operator asks Claude to push or deploy, Claude writes the runbook step instead.
- The plugin's `PreToolUse` hook enforces this mechanically and blocks such commands. If a command is blocked, do not retry it, rephrase it, or route it through a script, `python -c` or another tool. Put it in the runbook (Step 6).
- Read-only git and gh are fine: `git status`, `diff`, `log`, `show`, `blame`, `fetch`; `gh pr view`, `pr checks`, `run view`.

## Privacy rules (always)

- Never store credentials, tokens, one-time codes, account ids, device identifiers, home paths or personal data in docs, memory, commit messages or chat. If the operator pastes one, say so, do not repeat it, and confirm it was not stored.
- Secrets reach commands through shell variables the operator sets (`read -rs VAR`). Claude never asks for a secret's value.
- Pasted output gets redacted before it is quoted back (see the runbook template's `redact` helper).

## The loop

### Step 0 — Load the project contract

Read `.delivery-loop.yml` at the repository root. Its schema and comments are in [contract-template.yml](references/contract-template.yml).

If it is missing, **detect, don't ask**. Build a proposal from what the repository already declares:

- `package.json` `scripts`: `check`/`verify`/`ci` for `gate`; `test` for `fast_gate`; `e2e`/`test:e2e`/`playwright` for `browser_test`; `deploy*`/`release*` for the deploy lists.
- Makefile targets: `make help`, or the `^[a-z][a-z0-9_-]*:` lines.
- CI config: `.github/workflows/*.yml` `run:` lines, `.gitlab-ci.yml`, `Jenkinsfile`.
- Existing docs: AGENTS.md, CLAUDE.md, CONTRIBUTING.md, `docs/` runbooks.

Show the proposed file once, mark every guess, and ask the operator to confirm or correct it. Write it only after they confirm. Tell them that every command under `deploy_beta` and `deploy_prod` is then blocked for Claude by the hook.

Then read the repository's AGENTS.md and CLAUDE.md. Where they conflict with this skill, they win, except on the operator boundary and the privacy rules, which never relax.

### Step 1 — Decide before building

- Restate the acceptance criteria as a short numbered list, then confirm it with the operator.
- For anything a user will **see**, draft 2–4 options (sketches, mock text or screenshots) and let the operator choose. Record the choice in the ADR: who chose, the date, which option and why.
- For a decision future contributors might question, write or update an ADR before the code.
- Name the risk class: reversible (config, copy) or one-way (migrations, deletions, public API). One-way changes get a rollback plan in Step 6 before any code is written.

### Step 2 — Build with the file-modification audit

For every file edit:

1. Format the file first with the repository's formatter, so anchors match what is on disk.
2. Edit with an exact-match replacement that must match exactly once. Zero or multiple matches is a stop, not a guess.
3. Format again.
4. **Audit the file now, not at the end.** Grep that the new text is present and the old text is gone. On failure, stop, report expected vs found, fix and re-audit.

Before renaming or removing anything, search the whole repository for references with untruncated output (no `head`) and list every hit. Keep a running list of the files you changed; Step 5 checks it against the tree.

### Step 3 — Test with negative controls

- Unit tests for every rule you added. A real-browser test (from `browser_test`) for anything a user touches.
- For any "nothing was sent" or "nothing was stored" claim, record evidence of absence: a network trace or HAR, or a storage dump. A screenshot is not evidence of absence.
- **Negative controls.** For each new rule, break it on purpose and confirm that a **named** test fails. A test that has never failed proves nothing. Restore the rule and confirm the test passes again.
- Iterate on `fast_gate`. Run the full `gate` once before review.

### Step 4 — Gate, then independent review and verification

Run the full `gate` and record the exact totals. A red gate means back to Step 2, not on to review.

Then launch reviewers **in parallel**, one lens each, against the diff and the acceptance criteria. Use the provider for a lens when it is installed, and the built-in fallback prompt when it is not. Detect what is installed from the skills and agents available in this session; do not ask. The table, fallback prompts and finding format are in [review-lenses.md](references/review-lenses.md).

| Lens | Provider if installed | Otherwise |
|---|---|---|
| Correctness | `engineering:code-review` | fallback prompt |
| Security and privacy | `ascent-security:security-auditor` agent | fallback prompt |
| Accessibility | `design:accessibility-review` | fallback prompt |
| UX and navigation | — | fallback prompt |
| Operational and deploy impact | `engineering:deploy-checklist` | fallback prompt |
| Tests | `engineering:testing-strategy` | fallback prompt |

Skip a lens only when it cannot apply (no UI means no accessibility lens), and say so. A provider's output is passed through unedited, under a thin header naming the lens and the provider.

Every finding needs `file:line` and a concrete failure scenario. Then give all findings to the **`finding-verifier` agent** (`ascent-delivery:finding-verifier`). It is read-only and returns CONFIRMED, REJECTED or UNCONFIRMED for each finding, with evidence.

### Step 5 — Fix, re-test, definition of done

- Fix CONFIRMED findings, most severe first, through Steps 2–3 again (audit and controls included).
- Surface judgment calls and UNCONFIRMED findings to the operator with a recommendation. Do not silently drop them.
- Re-run the full gate.

**Done means all of these, each with evidence:**

1. The full `gate` is green, with exact totals recorded.
2. `browser_test` and `mutation` (when the contract has them) are green, with no anchor misses or surviving mutants.
3. Every acceptance criterion from Step 1 maps to a test or a recorded manual check.
4. Every CONFIRMED finding is fixed or explicitly accepted by the operator.
5. The `handoff_docs` reflect the behavior change. If they do not, the loop is not done.
6. The ADR records the decision and its reasons.
7. A hash manifest (`shasum -a 256` or `sha256sum`) lists exactly the intended files, and `git status --porcelain` shows no others.

### Step 6 — Hand-off runbook (the operator runs it)

Write a numbered, copy-paste runbook into the project's docs (`runbook_dir`), from [runbook-template.md](references/runbook-template.md). Every step is a command block, then an **Expect** list, then a **Stop if** line.

- Step 1 of the runbook confirms the tree: branch, HEAD, the exact modified-file list and the manifest check.
- The operator commits, pushes, opens and merges the PR, and tags. Write those commands out; do not run them.
- Every deploy is **dry run → confirm it names the right stage → run**. Scripts in `prompting_scripts` run with their non-interactive flag after the dry run. Never pipe a prompting script through a filter: the prompt is swallowed and reads as "no".
- **Prove the deploy by the artifact.** `build_stamp_check` runs in the same step as the deploy. A passing health check does not prove new code went out.
- Secrets: the operator declares them with `read -rs VAR` or loads them from their secret store into a variable. They are never echoed and never pasted to Claude. The runbook defines the `redact` helper, and pasted output goes through it.
- End with a rollback or switch-off section, and say what must **not** be rolled back (for example, applied migrations).

### Step 7 — Verify beta, then prod, then the release record

- After the operator's beta deploy, check stamps, sizes and smoke results from their redacted output. Then do a live check: browser or HTTP, read-only.
- Ask before any irreversible action, even on beta. Never touch real users' data.
- Write a short results doc: what passed, what was not checked and why, and the verdict.
- Prod comes only after beta is fully verified, and gets its own runbook. Take a snapshot before migrations, and verify prod the same way.
- Append one line to the `release_log`:

```
| <YYYY-MM-DD> | <short sha> | <lead time: first commit → prod> | <none | fix-forward | rollback> | <gate totals> |
```

The fourth column feeds change-failure rate, and lead time feeds delivery speed. Those are two of the four DORA measures; deploy frequency and time to restore come from the log's history.

## Reporting and stopping

Report each step in one line, with its evidence, so the operator can follow the loop and resume it in a new session:

```
Step <N> — <name>: <done | blocked | skipped (reason)> — <evidence: totals, file list, verdict counts, doc path>
```

Stop and hand control to the operator, with a recommendation, when:

- the contract is missing and the operator has not confirmed a proposal (Step 0);
- the acceptance criteria are ambiguous, or a user-visible choice has not been made (Step 1);
- an edit anchor matches zero times or more than once, or an audit fails twice in a row (Step 2);
- a negative control does not make its named test fail (Step 3);
- the verifier marks a Critical or High finding UNCONFIRMED (Step 4);
- any definition-of-done item lacks evidence (Step 5);
- the operator's pasted output shows the wrong stage, an old build stamp or a failed smoke check (Step 7).

## What this skill does not do

- Run git writes, deploys, or anything that needs the operator's credentials. The hook blocks them, and the runbook carries them.
- Rewrite a provider's review output, or merge lenses into one summary before the verifier has run.
- Declare done without the evidence listed in Step 5.
