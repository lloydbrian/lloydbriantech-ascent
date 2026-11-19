---
name: doc-stub
description: >-
  Use when asked to "write a doc for this", "start a guide", "add a
  how-to", "create a reference page", "document this feature", "we need a
  page for operators", or when docs-review finds a persona with nowhere to
  start. Asks who reads the document and what they need from it, picks the
  kind (tutorial, how-to guide, reference, explanation, or a persona's
  entry point), places it within the contract's click limit, writes it from
  a stub with guidance in every section after approval, and links it from
  the page its reader starts on. Never overwrites a document and never
  commits.
version: 0.1.0
allowed-tools: Read, Grep, Glob, Bash(git ls-files:*), Bash(git log:*)
---

# doc-stub

Starts one new document of the right kind, in the right place, for one reader, so it is written when someone needs it rather than eagerly, and found once it is.

Shared sources:
- [docs-rules.md](../../references/docs-rules.md): the four kinds and the entry point, and the doc-stub marker
- [contract-template.yml](../../references/contract-template.yml): `docs.dir`, `personas`, `max_clicks`

## Rules

- **Write only after approval, and only two files:** the new document, and one link to it in the page its reader starts on. Never overwrite a document: the script refuses, and so do you. Never commit.
- **One reader, one job.** Push back once on "it's for everyone" and on a page that would be both a tutorial and a reference; propose two pages instead.
- **No documentation theater.** Write a stub only when someone will read it soon. If the answer fits in an existing page, propose that edit instead.
- **No secrets or personal data** in the document.
- **Scripts.** The scripts are in `scripts/`, two directories above this skill's base directory (shown when the skill loads). Below, `PLUGIN_ROOT` means that directory: set it with `PLUGIN_ROOT="<skill base directory>/../.."`. Quote every value you pass to a script.

## Steps

### Step 0 — Load the contract

Follow docs-review Step 0 for `docs.dir`, `personas` and `max_clicks`.

### Step 1 — Who reads it, and why

Ask who reads this first and what they are trying to do. Map the answer to a persona from the contract, or propose one. Then pick the kind: learning (tutorial), doing a task (how-to), looking something up (reference), understanding why (explanation), or finding their way in (entry).

### Step 2 — Check it is needed

Search the existing documents (`Grep` for the topic's key terms). If a page already covers it, propose an edit to that page instead and stop.

### Step 3 — Place it

Propose the path: the script's default under `docs.dir` for the kind, or a path next to related pages. Check it is within `max_clicks` links of the persona's entry point once linked, and name the page that will link to it.

### Step 4 — Preview, then write

```bash
bash "$PLUGIN_ROOT/scripts/doc-stub.sh" --type '<kind>' --title '<title>' --persona '<persona>' [--out '<path>'] --dry-run .
```

Show the preview and the link line to add. After confirmation only, run the same command without `--dry-run`, then add the link. In this repository, `make doc-stub TYPE=<kind> TITLE="<title>"` runs the same script.

### Step 5 — Check and hand over

Run docs-review Step 2: the new document must be reachable (DOC-P2) and its links must resolve (DOC-L1). Say: "Started <path> for <persona>; fill in each section and delete the doc-stub line when it is written. Nothing is committed."
