# Runbook standard

A runbook is a list of commands an operator can follow under pressure without guessing. `runbook-check` reads every runbook against this standard; the operator scripts it calls are checked by `check-ops-scripts.sh` (Z1–Z9).

## Shape

1. **Purpose and scope:** one paragraph: what it changes, in which environment, and what it does not touch.
2. **Inputs:** every value the operator supplies, declared as a shell variable. Secrets are read with `read -rs VAR`, other values with `read -r VAR`. A runbook never contains a credential, an account id, an email address or another personal value.
3. **Pre-flight:** state checks before any change: identity, clean working tree, the current version, current health, the change set (`--dry-run`, a plan, a change set).
4. **Steps:** numbered. Each step has:
   - **the command**, copied as written
   - **Expect:** what a good result looks like
   - **Stop if:** the output that means stop, and what to do then (usually the rollback)
5. **Destructive steps** are flagged and explained before they run: what is deleted, whether it can be undone, and the confirmation the command asks for.
6. **Post-flight:** verification after the change: readiness at the contract path, a smoke check, the version now running, the drift check.
7. **Rollback:** the commands that restore the previous state, with their own Expect and Stop if.

## Rules

- **Zero-touch.** Every value comes from a flag, the stack, the configuration store or a prompt. No step says "open the console and change…".
- **Same commands everywhere.** A runbook step names a `make` target or a script in the repository, the same one CI runs. No one-off shell pipelines that exist only in the runbook.
- **Read-only diagnostics.** Commands in the Troubleshooting Manual only read; anything that changes the system is a runbook step with pre-flight and post-flight checks.
- **Dated.** The runbook records the date and release it was last run against.

## Severity of gaps

| Gap | Severity |
|---|---|
| no rollback path for a production deploy | High |
| a destructive step with no flag, explanation or confirmation | High |
| a secret or personal value written in the runbook (→ ascent-security) | High |
| no pre-flight or post-flight section, or steps without Expect and Stop if | Medium |
| a step that changes something by hand in a console | Medium |
| no date or release recorded | Low |

These rows map onto the [ops-review](../skills/ops-review/SKILL.md) severity table, which is the one used for the rating.
