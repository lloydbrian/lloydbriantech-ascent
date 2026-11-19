# Session rules

The records `ascent-session` reads, writes and checks, and the rules for them. They follow the ASCENT session protocol (PRINCIPLES §15), so an ASCENT-scaffolded project and any other repository use the same files; the paths are the contract's `session:` section.

## The three records

| Record | Default path | Who it is for | In git | Changes by |
|---|---|---|---|---|
| Working memory | `docs/delivery/working-memory.md` | the team, every session | tracked | appending a dated entry under `## Decisions`, `## Patterns adopted` or `## Patterns rejected` |
| Session state | `docs/delivery/session-state.md` | one person, the next session | ignored | being overwritten: `Captured: YYYY-MM-DD-HHMM`, then `## Current focus`, `## Active decisions`, `## Blockers`, `## Next actions`, optional `## Phase context` |
| Handoff | `docs/delivery/HANDOFF.md` | the next person | tracked | being regenerated: `Generated: YYYY-MM-DD`, then `## Where to start`, `## Project state`, `## Project conventions` |

A decision entry reads `- YYYY-MM-DD: <the decision, in one line> (see ADR-N)`. Pattern entries may be undated; a dated one follows the same rules. `make session-snapshot` in an ASCENT project writes the session state with `(fill in: ...)` placeholders, which a person replaces.

## Keeping the records

- **The working memory is only appended.** A decision that changes is a new dated entry that says what it replaces; the old entry stays, so the record shows when the team changed its mind. `SES-S3` compares every version of the file in git history with the next.
- **A known older rewrite is accepted openly, never hidden.** `session.memory_since` names the commit after which the file is checked, with the reason in a comment.
- **The session state is personal and transient.** It is never committed: one person's focus would overwrite another's, and a stale one misleads everyone who pulls it.
- **Every claim about a prior session is cited.** `session-resume` says which file and line each statement comes from, and says "not recorded" for anything it cannot cite.

## Rules

| Id | Severity | Rule | Checked by |
|---|---|---|---|
| SES-S1 | Medium | the working memory exists, with a `## Decisions` section | `check-session.sh` |
| SES-S2 | Low | every decision is dated; every date is real, not after today and not before the entry above it | `check-session.sh` |
| SES-S3 | Medium | the working memory's entries are only appended: none is changed or removed later | `check-session.sh` (git) |
| SES-S4 | Medium | once the project keeps session records, the session state is not tracked by git and is in `.gitignore` | `check-session.sh` (git) |
| SES-S5 | Low | the session state has its four sections, no snapshot placeholder, and was captured within `state_max_age_days` | `check-session.sh` |
| SES-S6 | Low | the handoff has its three sections and is no older than the newest working-memory entry; it exists when `handoff_required` is set | `check-session.sh` |

At prototype maturity every finding is a NOTE. N/A is never a pass: it says there was nothing to check.

## Limits

- The checks prove that the records are kept: present, dated, appended, private where they should be, complete and current. They cannot tell whether an entry is accurate, or whether a decision belongs in an ADR instead; `session-capture` asks, and `ascent-adr` records it.
- The session state lives on one person's machine. Nothing checks another person's copy.
