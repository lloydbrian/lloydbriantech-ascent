# ADR-010: Delivery-loop plugin and operator-boundary hook

**Status:** Proposed
**Date:** 2026-10-18 (America/New_York)
**Decider:** lloydbriantech

## Context

The owner ships changes with a personal "delivery loop" skill: decide, build with a file-modification audit, test with negative controls, gate, independent parallel review with a verifier, fix, re-test, definition of done, a hand-off runbook the operator runs, beta verification, prod and a release record. Loops 1 and 2 of the October 2026 skill hardening were delivered with it.

As a personal skill, it has four weaknesses:

- **It is not reusable or tested.** It lives in one account and has no gate, no tests and no version. Other projects cannot install it, and nothing shows when it drifts.
- **The operator boundary is advisory.** The skill says Claude "does not run git or deploys on the operator's machine unless explicitly asked". That is an instruction, so a long session, a misread request or a compound command (`npm test && git push`) can cross it. The boundary matters most exactly when the model is least reliable.
- **It rebuilds what already exists.** The review step describes its own reviewers, although installed skills (`engineering:code-review`, `engineering:testing-strategy`, `engineering:deploy-checklist`, `design:accessibility-review`) and the `ascent-security:security-auditor` agent (ADR-009) already cover most lenses, and are maintained elsewhere.
- **The project contract is implicit.** Each project's gate, deploy commands and hand-off docs are found by asking the operator every time.

ADR-009 established plugins in this repository, with skills *generated* from the template so there is one source of truth. The delivery loop is not a template skill: no scaffolded project ships it, so there is nothing to generate it from. ADR-009 deferred a project contract file "until a second plugin needs one", and this plugin is the second.

## Decision

1. **A new plugin, `ascent-delivery`**, contains:
   - the `delivery-loop` skill, with Steps 0–7;
   - a read-only `finding-verifier` agent (Read, Grep, Glob);
   - a `PreToolUse` hook on the Bash tool;
   - references for the contract schema, the runbook format and the review lenses.

   It works in any repository, in Claude Code (CLI and VS Code) and in Cowork. ASCENT owns the delivery standard, and the plugin is its executable form.
2. **Hand-written plugin skills are allowed** when the skill is not a project-embedded template skill. ADR-009's generation rule still governs every skill that has a template source. A hand-written skill carries no GENERATED marker, so T1 (drift) does not apply to it. Every other `make test-plugins` check does: placeholders, names and versions, read-only agents, read-only skill pre-approvals, links, frontmatter, agent step references, and `claude plugin validate`.
3. **The operator boundary is enforced mechanically, not only by instructions.** In the plugin, Claude NEVER runs git writes or deploys, and there is no "unless asked" exception. The hook (`hooks/operator-boundary.sh`) parses each Bash command before it runs, and blocks with exit code 2 and a reason that points Claude at the runbook. It blocks:
   - git writes, using an allow-list of read-only subcommands, so unknown subcommands and aliases are blocked;
   - gh writes, including `gh api` calls with a write method or fields;
   - every command under `deploy_beta` and `deploy_prod` in `.delivery-loop.yml`;
   - well-known deploy and publish verbs.

   It looks through compound commands, subshells, substitutions (including heredocs inside them), `bash -c`, `eval`, `find -exec`, shells that read stdin (heredoc, here-string or a pipe), and wrapper prefixes. It treats quoted text and quoted-delimiter heredoc bodies as data. Unquoted heredoc bodies are checked for substitutions, and a shell fed by a pipe it cannot read is blocked. A contract entry matches by command name plus its positional words, ignoring flags and order. For an `&&` chain, only the last command is a deploy rule. Commands over 512 KB are blocked, so a slow check never times out into an allow. `git fetch` is allowed, because it changes only remote-tracking refs, except with a refspec that writes a local ref. The hook is portable bash and POSIX awk with no jq, and it is tested on mawk, gawk and BWK awk.
4. **Hook behavior is tested and guarded.** `tests/plugins/<plugin>/test-*.sh` feed real PreToolUse JSON to a plugin's hooks. `make test-plugins` T11 runs them for every plugin that has `hooks/`. T11 fails when such a plugin has no tests, when a test passes without an `N/N PASS` summary, or when `hooks.json` runs a script that does not exist. Fifteen negative controls (P15–P29) in `make test-mutants` must each fail on the check they name.
5. **Wrap, don't rebuild.** At the review step the skill detects installed providers, and uses a built-in single-lens fallback prompt when a provider is absent. Provider output is passed through unedited under a thin header. The skill never hard-wires a call to another skill (the sibling pattern). It tells Claude which providers to use if present (detect-don't-ask). Every finding then goes to the `finding-verifier` agent before anyone fixes it.
6. **A project contract file, `.delivery-loop.yml`.** It holds the gate, fast gate, browser and mutation tests, smoke, the deploy lists, the build-stamp check, prompting scripts, hand-off docs, the runbook directory and the release log. When it is missing, the skill proposes one detected from `package.json` scripts, Makefile targets and CI config, and asks the operator to confirm it once. The hook reads only the two deploy lists.
7. **Secrets never pass through Claude.** Runbooks have the operator declare secrets into shell variables (`read -rs VAR`) or load them from a secret store, and include a portable `redact` helper for output pasted back.

## Alternatives considered

- **Keep the boundary as an instruction only.** Zero cost, but instructions are exactly what fails under long context or ambiguous requests, and a single unintended `git push` or `terraform apply` costs far more than the hook. Rejected.
- **Deny rules in `settings.json` permissions** (for example `Bash(git push:*)`). These are prefix matches, so they miss `cd x && git push`, `git -C dir push`, `env A=1 git push` and `bash -c "…"`. They cannot read a per-project deploy list, and every repository would have to configure them. Rejected as the primary mechanism. Operators may still add them as a second layer.
- **Block every git command except an allow-list, with no parsing.** Simpler, but it blocks harmless reads inside pipelines and cannot tell `git commit -m "push later"` from a push. That makes the hook noisy enough that people disable it.
- **Write the hook in Python or Node.** Easier parsing, but it adds a runtime dependency to every project that enables the plugin. Bash and awk are present on stock macOS and Linux, which matches ADR-008 and ADR-009.
- **Rebuild all reviewers inside the plugin.** Self-contained, but it duplicates maintained skills and drifts from them. Fallback prompts cover only the absent case.
- **Generate the skill from a new template skill.** That would put a delivery-loop skill into every scaffolded project, which is a separate product decision. It could come later, and ADR-009's generation rule would then apply.

## Consequences

**Easier:**
- Any repository can install the loop with two commands, and gets the boundary with it.
- A compound command, a substitution or a contract-listed deploy is blocked before it runs. The reason tells Claude what to do instead.
- Review quality improves as the wrapped providers improve, with no change here.
- A project's delivery facts live in one reviewed file, instead of being re-asked every session.

**Harder:**
- The hook runs on every Bash call in every session where the plugin is enabled, including sessions that are not doing delivery work. Harmless git aliases and unknown git subcommands are blocked until they are run by hand.
- The hook is a parser. Every new bypass shape found in use needs a test case, and a fix in the awk.
- `allowed-tools`: the skill pre-approves Read, Grep and Glob only, because `qa-skill-frontmatter` requires the field. Claude still asks before every Bash command.

**Neutral:**
- The hook is a guard rail for an honest assistant, not a sandbox. It does not resolve commands hidden inside scripts, make targets or npm scripts unless the contract lists them. It does not inspect run-time command words, brace expansion, arrays used as commands, or other interpreters (`python -c`). The README lists these limits.
- Dry runs of deploy verbs (`npm publish --dry-run`, `kubectl apply --dry-run=client`) are blocked. This is conservative by design: flags are not trusted to make a deploy harmless, so the dry run belongs in the runbook too.
- An independent adversarial review (174 cases) found heredoc, stdin-shell, `find -exec`, contract-matching and wrapper bypasses in the first version. The fixes and a test case for each are in the plugin, and five further controls (P25–P29) guard the main ones.
- The personal skill can be retired once the plugin is installed where it was used.

## Cost implications

- About a day for the plugin, hook, tests, controls and docs. Each later bypass fix is a test case plus a few lines of awk.
- Each hook call costs about 10–30 ms on typical commands, and about 2 s for a 400 KB command on BWK awk, which is the slowest awk tested. Commands over 512 KB are blocked before parsing. The hook timeout is 10 s.
- `make test-plugins` gains about 20 s (199 hook cases on each of three awks), and `make test-mutants` about 45 s (15 controls, using the default awk only).
- Context cost, from `claude plugin details` (CLI estimates, not measured usage):
  - about 309 tokens always-on per session where the plugin is enabled (about 180 for the skill's description and 130 for the agent's);
  - about 3.9k tokens each time the skill runs, and 1.2k each time the verifier runs;
  - the hook costs no model context.

  Re-check these when the skill grows.
