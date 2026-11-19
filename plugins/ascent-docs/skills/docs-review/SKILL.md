---
name: docs-review
description: >-
  Use when asked "review our docs", "are our docs current?", "can a new
  person find what they need?", "check our documentation", "find broken
  links in the docs", "are the docs out of date?", or before a release or
  after a large change. Finds the documents in any repository, checks links
  and anchors, stale markers and documents older than what they describe
  (dated by git), the README and persona entry points and how many links
  away each document is (DOC-L1–L5, DOC-P1–P4), and what the documents name
  that the repository no longer has (DOC-R1–R6, with doc-drift); reads the
  newest documents for what scripts cannot judge; and rates the
  documentation strong, moderate or weak with file:line evidence. Read-only.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# docs-review

The entry point of `ascent-docs`. It answers one question: can each person who needs a document find it, and is what it names still there?

Shared sources:
- [docs-rules.md](../../references/docs-rules.md): the documents, the four kinds, DOC-L, DOC-P and DOC-R, and their limits
- [contract-template.yml](../../references/contract-template.yml): the `docs:` section

## Rules

- **Read-only.** Never edit a document here. Fixes are proposed as text; `doc-drift` applies approved fixes, `doc-stub` writes new documents, and the operator commits.
- **Evidence for every finding:** `file:line`, the rule id, and a failure scenario (who is misled, and how).
- **Rate only with the severity table below.** A concern that matches no row goes under **Other observations (unrated)**: a description that looks wrong, a page that mixes a tutorial with reference, a persona with no page of its own.
- **Never judge a description right or wrong as a finding.** The checks prove documents can be found and name what exists. Say so in the report.
- **Stay in scope.** ADRs are `ascent-adr`'s; operations manuals, runbooks and drill records are `ascent-ops`'s. Recommend those plugins rather than reviewing those files.
- **No secrets or personal data** in the report. A credential found in a document is reported by its location, never its value, with `ascent-security:security-audit` recommended.
- **Scripts.** The scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`. Quote every contract value you pass to a script.

## Severity

<!-- doc-severity:start -->
| Finding | Severity |
|---|---|
| A relative link to a file or folder that does not exist, or that leaves the repository (DOC-L1) | Medium |
| No README at the repository root (DOC-L5) | Medium |
| A persona entry point from the contract that does not exist (DOC-P1) | Medium |
| A path in a document that does not exist although its folder does (DOC-R1) | Medium |
| A make target a document names that the Makefile does not have (DOC-R2) | Medium |
| A package script a document names that package.json does not have (DOC-R3) | Medium |
| A link anchor that names no heading in its target (DOC-L2) | Low |
| A TODO, TBD, FIXME, "coming soon" or doc-stub marker older than the contract allows (DOC-L3) | Low |
| A document that lags far behind a file it links to (DOC-L4) | Low |
| A document no link reaches from the README or a persona entry point (DOC-P2) | Low |
| A README with no getting-started section (DOC-P3) | Low |
| A document more links from its entry point than the contract allows (DOC-P4) | Low |
| An environment variable a document names that nothing defines or reads (DOC-R4) | Low |
| A "Version:" line that differs from the version file (DOC-R5) | Low |
| A Node.js or Python version stated that differs from the pinned runtime (DOC-R6) | Low |
| A docs value missing from the contract ("unmeasured") | Low |
<!-- doc-severity:end -->

**Rating:** strong: no Medium. moderate: one to three Medium. weak: four or more Medium, or DOC-L5 (no README).

## Steps

### Step 0 — Load the contract

Read `.ascent/contract.yml` (or `.claude/contract.yml`): `docs.paths`, `exclude`, `personas`, `max_clicks`, `stale_marker_days`, `lag_days`, `version_file`, `ignore_env`, `ignore` and `maturity_target`. Add the `ops:` section's manuals, runbooks and drill folder to the exclusions when they are not at ascent-ops's defaults. If the `docs:` section is missing, propose it from what the repository has (detect, don't ask): the documentation folders, and personas only where the repository already names them. Mark every guessed value `# guess` and use the proposal for this run, saying it is unconfirmed.

### Step 1 — Map the documentation

List the documents by folder and, where you can tell from the title and first paragraph, by kind (tutorial, how-to, reference, explanation, entry) and reader. Name the README's getting-started section and each persona's entry point. Name every path you used.

### Step 2 — Run the checks

```bash
bash "$PLUGIN_ROOT/scripts/check-docs.sh" --path '<docs.paths>'... --exclude '<docs.exclude>'... --persona '<name>=<entry>'... --max-clicks '<docs.max_clicks>' --marker-days '<docs.stale_marker_days>' --lag-days '<docs.lag_days>' --maturity '<maturity_target>' .
```

Pass `--path`, `--exclude` and `--persona` once per entry, and leave out an option whose value the contract does not set. Then run doc-drift Step 1. Exit 2 is bad input: fix the arguments, never rate it.

### Step 3 — Read what the scripts cannot

Read the README and the five documents changed most recently (`git log --format='%h %cs' -n 1 -- <file>`). Report under **Other observations (unrated)**: a description that contradicts the code you see, a page doing two jobs (a tutorial full of option tables), a persona with nowhere to start, and a getting-started section that would not work on a clean machine. These are leads for a person, never rated.

### Step 4 — Report

```
## Documentation — <strong | moderate | weak>
Documents: N (in <paths>) · Personas: <names and entry points, or none> · README: <getting-started section or none>

| Rule | Severity | Evidence | Failure scenario | Fix |
|---|---|---|---|---|

N/A: <rule — why>
Notes: <recent stale markers, from the NOTE lines>
Other observations (unrated)
Recommended next: <doc-drift to fix what documents name; doc-stub for a missing page; onboard to walk a persona's path; ascent-adr or ascent-ops for their files>
```

The checks prove that documents can be found and name what exists, not that they are right: end the report with that sentence.
