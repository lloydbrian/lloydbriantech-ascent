# ascent-session

Session continuity for any repository. It keeps the answer to "where were we?" in the repository instead of in someone's head:
- a session starts from the project's records, with every claim cited to the line it came from, and the person confirms it before work starts
- a session ends with its state and its decisions written down, after approval
- the decisions the team keeps are only ever appended to, so the record shows when the team changed its mind
- one person's working state stays out of git; a handoff gives the next person one page to start from

It makes the ASCENT session protocol (PRINCIPLES §15) usable and checkable in any repository, with the same files an ASCENT-scaffolded project has ([ADR-027](../../docs/framework/DECISIONS/ADR-027-decision-session-and-documentation-plugins.md)). You don't need an ASCENT project to use it.

```
/plugin marketplace add lloydbrian/lloydbriantech-ascent
/plugin install ascent-session@lloydbriantech-ascent
```

Start a session with `/ascent-session:session-resume`, or ask "where did we leave off?". End one with "capture the session". When work changes hands: "write a handoff".

## What's inside

| Part | Kind | What it does |
|---|---|---|
| `session-resume` | skill, entry point | contract, the four-state classification, SES-S1–S6, and a cited resumption summary to confirm |
| `session-capture` | skill | the session state and the session's decisions, from a short interview, written after approval; the working memory is only appended to |
| `handoff` | skill | one page for the next person, from the records, the README, the contract, the ADRs and git, written after approval |
| `check-session.sh` | script | SES-S1–S6 on the three records and, for S3 and S4, `git log`, `git show`, `git ls-files` and `git check-ignore` |
| `references/` | references | the session rules and the contract template |

There is no agent: the records are read at the start of a session by the session itself. In the delivery loop, decisions are reviewed by the Decisions lens (`ascent-adr:decision-reviewer`) and documents by the Documentation lens (`ascent-docs:docs-reviewer`).

## Boundaries

- **Whether an entry is accurate** is a person's call. The checks prove the records are kept; `session-resume` cites what it read and asks the person to confirm.
- **Commits** are the operator's: `session-capture` and `handoff` write files after approval and never commit.
- **Architecture decisions** belong in ADRs (`ascent-adr`); the working memory cites them. Other documentation is `ascent-docs`'s.

## Maturity targets

| Item | Prototype | Standard | Enterprise (default) |
|---|---|---|---|
| Working memory (SES-S1, S2) | notes only | present, decisions dated | the same, in date order |
| Append-only (SES-S3) | notes only | entries kept | every version in git history checked |
| Session state (SES-S4, S5) | notes only | out of git | out of git, complete and fresh |
| Handoff (SES-S6) | notes only | current when present | current; required when the contract says so |

## Evidence, strongest first

1. **The script:** exact, repeatable, `file:line`, labelled with its rule id.
2. **Reading** the records and what they point to: the only view of whether they are still true.

## Tests

`make test-plugins` runs `tests/plugins/ascent-session/`, on every awk installed:
- `test-check-session.sh`: a good set of records passes SES-S1–S6; one broken copy per control fails that check and no other; history and ignore rules in scratch git repositories, with `--since` and a shallow clone
- `test-session-rules.sh`: the skill rules, the severity table against the script, the contract keys, and bash 3.2

`make test-mutants GROUP=ascent-session` adds negative controls that must each make a named check fail.
