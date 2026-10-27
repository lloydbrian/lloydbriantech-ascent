# Runbook template

The delivery-loop skill writes one runbook per hand-off (Step 6) into the project's `runbook_dir`. The operator runs it; Claude never does. Copy the shape below and fill in every `<…>`.

## Step format

Every step has the same three parts:

1. **One command block**, copy-paste ready, with no prose inside it.
2. **Expect**, a short list of what the output must show.
3. **Stop if**, one line. When it is true, the operator stops and pastes the redacted output back.

A step that changes anything (commit, push, tag, deploy) comes right after a step that shows what it will change.

---

## Runbook: <change title> — <YYYY-MM-DD>

**Change:** <one sentence>
**Branch:** `<branch>`  **Expected HEAD after commit:** set in step 2
**Stages:** beta, then prod (prod has its own runbook)

### 0. Prepare the shell (secrets and redaction)

Secrets go into variables. They are never typed into a command line, never echoed, and never pasted to Claude.

```bash
read -rs DEPLOY_TOKEN && export DEPLOY_TOKEN    # paste at the prompt; nothing is shown
# or load it from your secret store into a variable, e.g.:
# DEPLOY_TOKEN="$(<your secret-store CLI> read <item>)" && export DEPLOY_TOKEN

redact() {
  sed -E \
    -e 's/[0-9]{12}/<account-id>/g' \
    -e 's/arn:aws[a-z-]*:[^ "]*/<arn>/g' \
    -e 's#(/Users|/home)/[^/ ]+#\1/<user>#g' \
    -e 's/[A-Za-z0-9.-]+\.(internal|corp|lan|local)/<host>/g' \
    -e 's/([Tt][Oo][Kk][Ee][Nn]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Kk][Ee][Yy])([=:] *)[^ ]+/\1\2<redacted>/g'
}   # portable: GNU and BSD sed -E
```

**Expect**
- no output from `read`; `echo "${DEPLOY_TOKEN:+set}"` prints `set`

**Stop if** the token prints anywhere on screen.

### 1. Confirm the tree

```bash
git status --short --branch
git rev-parse --short HEAD
git diff --name-only <base>...HEAD
shasum -a 256 -c MANIFEST.sha256     # Linux: sha256sum -c MANIFEST.sha256
```

**Expect**
- branch `<branch>`; no unexpected files
- exactly these files: `<file list from the definition of done>`
- every manifest line ends in `OK`

**Stop if** any extra file appears or any manifest line fails.

### 2. Commit and push

```bash
git add <exact files>
git commit -m "<type>(<scope>): <subject>"
git push -u origin <branch>
```

**Expect**
- one commit, with the files from step 1
- push accepted

**Stop if** the commit includes a file not in step 1.

### 3. Pull request and merge

```bash
gh pr create --fill --base main
gh pr checks --watch
# after review: gh pr merge --squash --delete-branch
```

**Expect**
- all checks green, with the same gate totals as the definition of done

**Stop if** any check fails, or the totals differ from the local gate.

### 4. Deploy to beta — dry run, confirm stage, run, prove

```bash
<deploy_beta command> --dry-run 2>&1 | redact
```

**Expect**
- the plan names stage **beta**, and only beta
- the changes listed match this change

**Stop if** it names prod, or any resource you did not expect.

```bash
<deploy_beta command> <non-interactive flag from prompting_scripts> 2>&1 | redact
<build_stamp_check> beta | redact
```

**Expect**
- deploy exits 0
- the build stamp equals `git rev-parse --short HEAD` from step 2, and the artifact sizes are in the expected range

**Stop if** the stamp is the old commit, however healthy the health check looks.

### 5. Smoke on beta

```bash
<smoke> beta 2>&1 | redact
```

**Expect**
- every smoke check passes

**Stop if** any check fails. Go to Rollback.

Paste the redacted output of steps 4–5 back to Claude for beta verification (delivery-loop Step 7).

### 6. Tag (after prod is verified, in the prod runbook)

```bash
git tag -a v<version> -m "<release summary>"
git push origin v<version>
```

---

## Rollback / switch-off

```bash
<the previous artifact's deploy, or the feature flag off>
<build_stamp_check> beta | redact
```

**Expect**
- the stamp shows the previous commit

**Do not roll back:** <applied migrations, sent messages, anything else one-way, and why>.

---

## Rules for whoever writes the runbook

- Claude writes every git, gh and deploy command here, and never runs them. The plugin hook blocks them anyway.
- One deploy per step, always dry run → confirm stage → run, and proved by the artifact in the same step.
- Prod gets its own runbook, with a snapshot or backup step before any migration.
- **Stacked pull requests.** Build each change on `main` after the previous one merges, when you can. When a pull request must stack on another:
  - CI that runs only on pull requests into `main` does not run on it. Retarget it to `main` (`gh pr edit <PR> --base main`) before its base PR merges, because that merge deletes the base branch.
  - Retargeting does not start CI. Close and reopen the pull request (`gh pr close <PR>` then `gh pr reopen <PR>`) so the checks run.
  - After the base PR is squash-merged, the stacked branch still carries the base's original commits and GitHub reports a conflict. Replay only its own commits: `git rebase --onto origin/main <old base tip> <branch>`, check `git diff --stat <old tip> HEAD` prints nothing, then `git push --force-with-lease`. Flag the force push as destructive in the runbook.
- No secret, account id, private hostname or personal path appears in the runbook. Use variables and `redact`.
