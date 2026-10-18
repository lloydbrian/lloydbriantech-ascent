# ascent-delivery

The ASCENT delivery loop as a plugin, for any repository. It takes a change through these steps:

decide → build with a file-modification audit → test with negative controls → gate → independent parallel review checked by a finding verifier → fix and re-test → definition of done → a hand-off runbook **the operator runs** → beta verification → prod → release record.

It is part of the [ASCENT framework](../../README.md), and you don't need an ASCENT project to use it. ASCENT owns the delivery standard, and this plugin is its executable form.

| Component | Type | What it does |
|---|---|---|
| `delivery-loop` | skill | The loop, Steps 0–7, with the project contract, the definition of done and the release record. Use it with "run the delivery loop", "ship this change" or "write the hand-off runbook". |
| `finding-verifier` | agent (read-only) | Re-checks every reviewer finding against the code. Returns CONFIRMED, REJECTED or UNCONFIRMED with `file:line` evidence. |
| `operator-boundary` | hook (`PreToolUse`, Bash) | Blocks git writes, gh writes and deploys before they run, and tells Claude to put them in the runbook. |
| `contract-template.yml`, `runbook-template.md`, `review-lenses.md` | references | The `.delivery-loop.yml` schema, the runbook step format, and the review lenses with their fallback prompts. |

## Install

Claude Code CLI, or the Claude Code extension in VS Code:

```
/plugin marketplace add lloydbrian/lloydbriantech-ascent
/plugin install ascent-delivery@lloydbriantech-ascent
```

From a local clone, use the clone's path instead of `lloydbrian/lloydbriantech-ascent`.

Cowork: Customize → Plugins → Add marketplace → `lloydbrian/lloydbriantech-ascent`, then install `ascent-delivery`.

Call the skill as `/ascent-delivery:delivery-loop`. Claude also loads it when your request matches its description. To turn the plugin on for everyone working in a repository, add it to that repository's `.claude/settings.json` under `enabledPlugins`.

## The operator boundary

Claude **never** runs git write operations or deploys, in any project where this plugin is enabled. The operator commits, pushes, merges, tags and deploys, from the runbook Claude writes. There is no "unless asked" exception.

This is enforced by a hook, not just by the instructions. **The hook applies to every session where the plugin is enabled, whether or not the delivery loop is running.** It inspects each Bash command before it runs, and blocks with a reason (exit code 2) when the command contains any of these:

- **git writes**: commit, push, tag creation or deletion, merge, rebase, reset, revert, cherry-pick, am, apply, stash, checkout or switch, branch create/delete/rename, clean, restore, rm, mv, add, pull, worktree add/remove, update-ref, config writes, and any git subcommand or alias that is not on the read-only list.
- **gh writes**: pr create/merge/close/edit/review, release create/delete/edit, repo create/delete/edit, workflow run, secret set, `gh api` with a write method or fields (which imply POST), GraphQL mutations, and `gh auth token`, which would print a credential.
- **deploys**: every command under `deploy_beta` and `deploy_prod` in the project's `.delivery-loop.yml`, and well-known deploy and publish verbs. These include terraform/tofu apply, destroy and import; kubectl/oc writes and `rollout restart`; helm install, upgrade, uninstall and rollback; aws cloudformation deploy and `*-stack`; `aws s3 cp|sync|mv` to `s3://`; npm/pnpm/yarn/bun publish; docker/podman push; cdk, sam and serverless deploy; `vercel --prod`; `netlify deploy --prod`; firebase, fly and wrangler deploy; `gcloud … deploy`; cargo publish; twine upload; gem push; and mvn deploy.

It **allows** read-only git (status, diff, log, show, blame, grep, ls-files, rev-parse, describe, branch and tag listing, `remote -v`, config reads, `stash list`, and `fetch` without a refspec that writes a local branch) and read-only gh (pr view/list/checks/diff/status; issue, run, workflow, release and repo view and list; search; `gh api` GET).

It looks through compound commands (`&&`, `||`, `;`, `|`, newlines), subshells, `$( )` and backticks (including heredocs inside them), `$(( ))`, `bash -c`, `su -c`, `script -c`, `trap '…'`, `eval`, `find -exec`, `parallel`, `env` and `VAR=x` prefixes, and wrappers such as `sudo`, `time`, `timeout`, `nice`, `stdbuf`, `setsid`, `flock`, `xargs`, `npx`/`npm x`/`uvx` and `python -m`. It also sees through `git -C dir`, `git -c key=cmd` for keys that run a command, `hub` and `git-push`-style binaries.

Quoted text and quoted-delimiter heredoc bodies (`<<'EOF'`) are data, so `git commit -m "push later"` is reported as a commit, and writing a runbook that contains `git push` is allowed. Unquoted heredoc bodies (`<<EOF`) are checked for `$( )` and backticks, because the shell runs those.

A shell that reads commands from stdin is checked too. This covers `bash <<'EOF'`, `bash <<< '…'`, `cat <<'EOF' | bash` and `echo '…' | sh`. When the input piped into a shell cannot be read, as in `curl … | bash`, the command is blocked.

Commands over 512 KB are blocked with a request to split them, so a slow check can never time out and let a command through.

**Known limits.** The hook is a guard rail for an honest assistant, not a sandbox:

- Commands hidden inside scripts, make targets or npm scripts are blocked only when the contract lists them. Add your deploy entry points to `deploy_beta` and `deploy_prod`.
- A command word built at run time (`$GIT push`, shell aliases, functions) is not resolved.
- Other interpreters (`python -c`, `node -e`) and tools that are not Bash (MCP servers) are not inspected.
- Dry runs of deploy verbs (`npm publish --dry-run`, `kubectl apply --dry-run=client`) are blocked too. That is conservative by design: the hook does not trust flags to make a deploy harmless, so the runbook carries the dry run as well.
- Contract entries match by command name plus the entry's positional words, wherever they appear and whatever flags surround them. For an `&&` or `;` chain, only the last command is a deploy rule. A command that reaches the deploy under a different name, or a make target that depends on the deploy target, is not caught.
- Not resolved: brace expansion (`{git,push}`), arrays used as commands (`"${cmd[@]}"`), commands built from variables, and `xargs`/`parallel` input that supplies the subcommand.
- If the hook itself fails, it reports an error and does not block (exit 1). The behavior tests run on mawk, gawk and BWK awk (the macOS awk).

To lift the boundary you have to disable the plugin. There is no bypass variable.

## Review providers it wraps

At the review step, the skill uses these when they are installed, and a built-in single-lens prompt when they are not. Provider output is passed through under a thin header, not rewritten:

| Lens | Provider |
|---|---|
| Correctness | `engineering:code-review` |
| Security and privacy | `ascent-security:security-auditor` (agent, from [ascent-security](../ascent-security/README.md)) |
| Accessibility | `design:accessibility-review` |
| Operational and deploy impact | `engineering:deploy-checklist` |
| Tests | `engineering:testing-strategy` |
| UX and navigation | built-in prompt only |

## The project contract

The skill reads `.delivery-loop.yml` at the repository root. The file lists the gate, the fast gate, the browser and mutation tests, smoke, the deploy commands, the build-stamp check, prompting scripts, the hand-off docs and the release log. If the file is missing, the skill proposes one, detected from `package.json` scripts, Makefile targets and CI config, and asks you to confirm it once. Schema: `skills/delivery-loop/references/contract-template.yml`.

## Privacy

- Secrets never pass through Claude. Runbooks have the operator declare them into shell variables (`read -rs VAR`) or load them from a secret store, and include a `redact` helper for any output pasted back.
- The skill and the agent never store credentials, account ids, hostnames, home paths or personal data in docs, memory or chat.
- The agent's tools are limited to Read, Grep and Glob. The skill pre-approves only those same read tools; Claude asks before anything else.

## How this plugin is built

Unlike `ascent-security`, the skill is **hand-written**. The delivery loop is not a project-embedded template skill, so there is no template source to generate it from. Every other plugin gate check still applies to it, and the hook has its own behavior tests in `tests/plugins/ascent-delivery/`, run by `make test-plugins` (T11) and guarded by negative controls in `make test-mutants`. See [ADR-010](../../docs/framework/DECISIONS/ADR-010-delivery-loop-plugin-and-operator-boundary-hook.md).
