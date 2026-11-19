# ascent-adr

Architecture decision records for any repository. It keeps the answer to "why is it like this?" findable and true:
- each decision is written down with its context, the options turned down, its consequences and what it costs
- the record is complete and linked: sections, numbers, index, status, and supersession both ways
- an accepted decision is never quietly rewritten: only its status changes, and git history proves it
- the code is checked against what accepted decisions require of it, where a person has declared that

It makes the ASCENT architect's decision discipline checkable in an existing repository, in the format the repository already uses: ASCENT, Nygard and adr-tools, or MADR ([ADR-027](../../docs/framework/DECISIONS/ADR-027-decision-session-and-documentation-plugins.md)). You don't need an ASCENT project to use it.

```
/plugin marketplace add lloydbrian/lloydbriantech-ascent
/plugin install ascent-adr@lloydbriantech-ascent
```

Start with `/ascent-adr:adr-check`, or ask "do our ADRs conform?". To record a decision: "write an ADR for this". For an independent pass: "Use the ascent-adr:decision-reviewer agent to review our decisions."

## What's inside

| Part | Kind | What it does |
|---|---|---|
| `adr-check` | skill, entry point | contract, map of the record, DEC-S1–S8 and the constraints; strong, moderate or weak |
| `adr-write` | skill | the next ADR in the repository's format, from an interview, written after approval with its index row; supersedes by changing only the old status line |
| `decision-drift` | skill | proposes constraints from accepted ADRs, and checks the code against the declared ones: DEC-C1–C3 |
| `decision-reviewer` | agent, read-only | independent review; the delivery loop's Decisions lens |
| `check-adrs.sh` | script | DEC-S1–S8 on the ADR folder, its index and, for S8, `git log` and `git show` |
| `check-decision-drift.sh` | script | DEC-C1–C3: forbid patterns and required paths from accepted ADRs |
| `references/` | references | the decision rules and formats, and the contract template |

## Boundaries

- **Whether a decision is right** is a person's call. The checks prove decisions are recorded and kept; a reviewer's doubts about a decision are reported unrated.
- **Commits** are the operator's: `adr-write` writes files after approval and never commits.
- **Waivers in other plugins** (an ADR id in a contract's `waivers`, an accepted threat) are checked by those plugins; `ascent-adr` checks the ADRs themselves.
- **Other documentation** is `ascent-docs`'s; operations manuals are `ascent-ops`'s.

## Maturity targets

| Item | Prototype | Standard | Enterprise (default) |
|---|---|---|---|
| Record and sections (DEC-S1, S2, S5) | notes only | an ADR folder; every ADR complete, with a status | the same |
| Links (DEC-S3, S4, S6) | notes only | supersession both ways | numbers, index and supersession all consistent |
| Dates and history (DEC-S7, S8) | notes only | real dates | accepted bodies unchanged since acceptance |
| Constraints (DEC-C1–C3) | notes only | declared constraints hold | the same, with no constraint left on a superseded ADR |

## Evidence, strongest first

1. **The two scripts:** exact, repeatable, `file:line`, labelled with their rule id.
2. **Reading** the ADRs and the code: the agent's view, and the only view of whether a decision still makes sense.

## Tests

`make test-plugins` runs `tests/plugins/ascent-adr/`, on every awk installed:
- `test-check-adrs.sh`: good records in the three formats pass DEC-S1–S8; one broken copy per control fails that check and no other; history in a scratch git repository for DEC-S8, with an acknowledged change
- `test-check-decision-drift.sh`: the good fixture passes DEC-C1–C3; one broken copy per control; `--under`, the 20-match cap, a superseded ADR's constraint and bad input
- `test-adr-rules.sh`: the skill rules, the severity table against the scripts, the contract keys, and bash 3.2

`make test-mutants GROUP=ascent-adr` adds negative controls that must each make a named check fail.
