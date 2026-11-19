# ascent-docs

Documentation that the people who need it can find, and that names what the repository still has:
- every document is reachable from the README or the page its reader starts on, within a few links
- links and anchors resolve; TODOs, "coming soon" and unfinished stubs are dated by git, so the old ones surface
- the paths, make targets, package scripts, environment variables, version and runtimes a document names are checked against the repository
- a new document starts as the right kind for one reader, with guidance in every section, only when someone needs it

It makes ASCENT's persona-segmented, lazily generated documentation usable and checkable in any repository ([ADR-027](../../docs/framework/DECISIONS/ADR-027-decision-session-and-documentation-plugins.md)). You don't need an ASCENT project to use it.

```
/plugin marketplace add lloydbrian/lloydbriantech-ascent
/plugin install ascent-docs@lloydbriantech-ascent
```

Start with `/ascent-docs:docs-review`, or ask "are our docs current?". After a refactor: "do the docs still match the code?". For a new page: "start a how-to for rotating keys". For a newcomer: "onboard me as a developer". For an independent pass: "Use the ascent-docs:docs-reviewer agent to review our docs."

## What's inside

| Part | Kind | What it does |
|---|---|---|
| `docs-review` | skill, entry point | contract, map of the documents, DOC-L, DOC-P and DOC-R; strong, moderate or weak |
| `doc-drift` | skill | DOC-R1–R6, each mismatch traced to the commit that changed the name, exact edits applied after approval |
| `doc-stub` | skill | one new tutorial, how-to, reference, explanation or entry point, placed and linked for its reader, after approval |
| `onboard` | skill, read-only | one persona's first hour, from the repository's own documents, with the gaps it hit |
| `docs-reviewer` | agent, read-only | independent review; the delivery loop's Documentation lens |
| `check-docs.sh` | script | DOC-L1–L5 and DOC-P1–P4: links, anchors, stale markers by `git blame`, lag by `git log`, README, personas, reachability |
| `check-doc-drift.sh` | script | DOC-R1–R6: paths, make targets, package scripts, environment variables, version, runtimes |
| `doc-stub.sh` | script | writes one new document from `references/stubs/`; never overwrites; this repository's `make doc-stub` runs it |
| `references/` | references | the documentation rules, the stubs and the contract template |

## Boundaries

- **Whether a description is right** is a reader's call. The checks prove documents can be found and name what exists; a reviewer's doubts are reported unrated.
- **Commits** are the operator's: `doc-drift` and `doc-stub` write documents after approval and never commit.
- **ADRs** are `ascent-adr`'s; **operations manuals, runbooks and drill records** are `ascent-ops`'s. Both are left out of the checks, though links into them are still checked.
- **Secrets in documents** are `ascent-security`'s.

## Maturity targets

| Item | Prototype | Standard | Enterprise (default) |
|---|---|---|---|
| Links and README (DOC-L1, L2, L5) | notes only | links resolve, a README | anchors too |
| Currency (DOC-L3, L4) | notes only | no stale marker past the limit | documents keep up with what they link to |
| Findability (DOC-P1–P4) | notes only | every document reachable | persona entry points, within the click limit |
| Drift (DOC-R1–R6) | notes only | paths, targets and scripts exist | variables, version and runtimes match too |

## Evidence, strongest first

1. **The two check scripts:** exact, repeatable, `file:line`, labelled with their rule id.
2. **Reading** the documents and the code: the agent's view, and the only view of whether a description is right.

## Tests

`make test-plugins` runs `tests/plugins/ascent-docs/`, on every awk installed:
- `test-check-docs.sh`: a good documentation set passes DOC-L1–L5 and DOC-P1–P4; one broken copy per control fails that check and no other; git dates in scratch repositories for DOC-L3 and DOC-L4
- `test-check-doc-drift.sh`: the good set passes DOC-R1–R6; one broken copy per control; what is never checked (prose, other code fences, changelogs, ADR folders) and the ignore lists
- `test-doc-stub.sh`: each kind written in place with every section, never an overwrite, bad input, the stub found by check-docs, and `make doc-stub`
- `test-docs-rules.sh`: the skill rules, the severity table against the scripts, the contract keys, and bash 3.2

`make test-mutants GROUP=ascent-docs` adds negative controls that must each make a named check fail.
