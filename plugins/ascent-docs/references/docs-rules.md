# Documentation rules

What `ascent-docs` checks, and why. A document is useful only if the person who needs it finds it, and it is true when they read it. The checks prove the first and catch the commonest ways the second fails; whether a description is right is for a reader to judge.

## The documents

`docs.paths` (default `README.md`, `CONTRIBUTING.md`, `docs/`) less `docs.exclude`. ADR folders and `ADR-NNN-title.md` files wherever they are kept are `ascent-adr`'s, and operations manuals, runbooks and drill records are `ascent-ops`'s, so they are left out; every Markdown file is still read for headings, so a link into them is checked. Changelogs and release notes are left out of the drift checks, because they name old things on purpose.

## Four kinds of document

Each document does one job for one reader (the Diátaxis model). `doc-stub` writes each with guidance in every section:

| Type | The reader | It answers |
|---|---|---|
| tutorial | someone learning | "show me, start to finish" |
| how-to | someone working | "how do I do this task?" |
| reference | someone looking something up | "what exactly does this option do?" |
| explanation | someone understanding | "why is it like this?" |
| entry | one persona | "where do I start?" |

A stub starts with `<!-- doc-stub: TYPE YYYY-MM-DD -->`; delete the line when the document is written. Until then `DOC-L3` reports it as a stale marker once it is older than `stale_marker_days`.

## Rules

| Id | Severity | Rule | Checked by |
|---|---|---|---|
| DOC-L1 | Medium | every relative link resolves inside the repository | `check-docs.sh` |
| DOC-L2 | Low | every link anchor into a Markdown file names a heading there | `check-docs.sh` |
| DOC-L3 | Low | no stale marker older than `stale_marker_days`, dated by git blame | `check-docs.sh` (git) |
| DOC-L4 | Low | no document lags more than `lag_days` behind a file it links to | `check-docs.sh` (git) |
| DOC-L5 | Medium | a README at the repository root | `check-docs.sh` |
| DOC-P1 | Medium | every persona's entry point exists | `check-docs.sh` |
| DOC-P2 | Low | every document is reachable from the README or a persona entry point | `check-docs.sh` |
| DOC-P3 | Low | the README has a getting-started section (install, setup, quick start, usage, commands, development or running) | `check-docs.sh` |
| DOC-P4 | Low | every document is within `max_clicks` links of the README or an entry point | `check-docs.sh` |
| DOC-R1 | Medium | a path named in inline code, whose folder exists, exists (placeholders such as `phase-N-plan.md` and example names such as `x.sh` are skipped) | `check-doc-drift.sh` |
| DOC-R2 | Medium | every make target named is in the Makefile or a file it includes | `check-doc-drift.sh` |
| DOC-R3 | Medium | every package script named ("npm run", "pnpm run", "yarn run", "bun run") is in a package.json of the repository, workspaces included | `check-doc-drift.sh` |
| DOC-R4 | Low | every environment variable named is in an .env example or read by the code | `check-doc-drift.sh` |
| DOC-R5 | Low | every "Version:" line in a README matches the version file; other documents state their own version | `check-doc-drift.sh` |
| DOC-R6 | Low | every Node.js or Python version stated matches the pinned runtime | `check-doc-drift.sh` |

At prototype maturity every finding is a NOTE. N/A is never a pass: it says there was nothing to check.

## Limits

- The checks prove that documents can be found and name things the repository has. They cannot tell whether a description is right, complete or clear: a reviewer reads for that and reports it under **Other observations (unrated)**.
- `DOC-R1` checks only a path whose folder exists, so a document about another project's layout is not flagged; a whole folder that was removed is not caught either. `DOC-R4` only checks names with an underscore in inline code.
- Operations manuals and runbooks are checked by `ascent-ops` (OPS-M, OPS-Z); ADRs by `ascent-adr`.
