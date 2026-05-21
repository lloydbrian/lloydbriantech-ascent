---
name: ascent-release-readiness
description: >-
  Pre-release validation gate for <<PROJECT_TITLE>>. Checks CHANGELOG
  entry, version consistency, clean working tree, release branch, and
  tag uniqueness. Detects meta-repo vs scaffolded-project context and
  adapts version-field checks accordingly.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-release-readiness

Pre-release validation gate that answers "is this commit ready to tag and release?" Checks five shipping-discipline concerns: CHANGELOG entry exists with content, version fields are consistent, working tree is clean, branch is release-appropriate, and the target tag doesn't already exist.

The skill detects whether it's running in the framework meta-repo or a scaffolded project and adapts version-field checks accordingly. In the meta-repo, version lives in `Makefile FRAMEWORK_VERSION`; in scaffolded projects, version lives in `package.json`. Template files containing placeholders (`<<FRAMEWORK_VERSION>>`, `<<PROJECT_VERSION>>`) are ignored — they're rendered at scaffold time, not at release time.

This is a sibling skill to [ascent-qa](../ascent-qa/SKILL.md). qa provides a broad quality sweep; release-readiness provides shipping-specific validation. Run qa first for general health, then release-readiness for the go/no-go gate.

## When this skill engages

- Before tagging a release (`git tag vX.Y.Z`)
- When a developer asks "are we ready to ship?" or "can I tag this?"
- At the end of a phase, before the phase-closing tag
- NOT for routine quality checks — use [ascent-qa](../ascent-qa/SKILL.md) for those

## Inputs

- **Target version** — the version to release (required; e.g., "0.4.0"). The skill asks if not provided.
- **`CHANGELOG.md`** — must have an entry for the target version
- **`Makefile`** — version field (meta-repo context) or `package.json` (scaffolded project context)
- **`.ascent-meta.json`** — presence determines context (meta-repo vs scaffolded project)
- **`git` state** — working tree status, current branch, existing tags

## Outputs

- **Per-check report** — each of the 5 checks marked PASS or FAIL with specific blockers
- **Go/no-go summary** — "Release vX.Y.Z: READY" or "Release vX.Y.Z: N blockers found"

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Detect context and confirm target version

**Action:** Determine the execution context:
- If `.ascent-meta.json` does NOT exist at project root AND `Makefile` contains `FRAMEWORK_VERSION`: **meta-repo context**. Version source: `Makefile`.
- If `.ascent-meta.json` exists: **scaffolded project context**. Version source: `backend/package.json` (or `package.json` at root).

Ask the developer for the target version if not provided: "What version are you releasing? (e.g., 0.4.0)"

Report: "Release readiness check for v[version] in [meta-repo | scaffolded project] context."

### Step 2 — CHANGELOG entry

**Condition:** `CHANGELOG.md` contains a section header matching the target version (e.g., `## v0.4.0` or `## [0.4.0]`).

**Action on PASS:** Verify the section has substantive content (at least 2 non-empty lines below the header). Report "CHANGELOG entry — PASS. v[version] section has content."

**Action on FAIL (no header):** Report "CHANGELOG entry — FAIL. No `## v[version]` section in CHANGELOG.md."

**Action on FAIL (empty section):** Report "CHANGELOG entry — FAIL. `## v[version]` exists but has no content. Add release notes before tagging."

### Step 3 — Version consistency

**Condition:** The target version matches the version field in the project's source of truth.

**Meta-repo context:** Check `Makefile` for `FRAMEWORK_VERSION := X.Y.Z`. The value must match the target version.

**Scaffolded project context:** Check `backend/package.json` for `"version": "X.Y.Z"`. If `frontend/package.json` exists, check it too. Both must match the target version.

**Action on PASS:** Report "Version consistency — PASS. [source file(s)] match v[version]."

**Action on FAIL:** Report each mismatch. Example: "Version consistency — FAIL. Makefile has FRAMEWORK_VERSION := 0.3.1 but target is 0.4.0."

### Step 4 — Clean working tree

**Condition:** `git status --porcelain` returns empty (no uncommitted changes, no untracked files in tracked directories).

**Action on PASS:** Report "Clean working tree — PASS."

**Action on FAIL:** Report "Clean working tree — FAIL. [N] uncommitted changes. Commit or stash before tagging."

### Step 5 — Release branch and tag uniqueness

**Condition:** Current branch is `main` or matches `release/*` pattern. The tag `v[version]` does not already exist.

**Action on PASS (both):** Report "Release branch — PASS (on [branch]). Tag v[version] is available."

**Action on FAIL (wrong branch):** Report "Release branch — FAIL. On branch `[branch]` — releases should be tagged from `main` or `release/*`."

**Action on FAIL (tag exists):** Report "Tag uniqueness — FAIL. Tag `v[version]` already exists. Choose a different version or delete the existing tag."

### Step 6 — Aggregate and report

**Action:** Collect results from Steps 2-5. Report summary:

```
Release v0.4.0: READY (5/5 checks passing)
```

Or with blockers:

```
Release v0.4.0: 2 blockers found (3/5 checks passing)
  CHANGELOG entry        PASS
  Version consistency    FAIL — Makefile has 0.3.1, target is 0.4.0
  Clean working tree     PASS
  Release branch         PASS (on main)
  Tag uniqueness         FAIL — tag v0.4.0 already exists
```

If any check fails, the release is blocked. The skill also recommends: "Before tagging, ensure `make test-all` passes and `/ascent-qa` reports no concerns. These are not checked automatically due to runtime cost."

## Examples

### Example 1 — Ready to release

**Context:** Meta-repo, FRAMEWORK_VERSION 0.4.0, CHANGELOG has v0.4.0 section, clean tree on main, no v0.4.0 tag.

**Skill output:**
```
Release v0.4.0: READY (5/5 checks passing)
  CHANGELOG entry        PASS (v0.4.0 section with content)
  Version consistency    PASS (Makefile FRAMEWORK_VERSION := 0.4.0)
  Clean working tree     PASS
  Release branch         PASS (on main)
  Tag uniqueness         PASS (v0.4.0 available)

Recommendation: before tagging, verify `make test-all` passes and `/ascent-qa` reports no concerns.
```

### Example 2 — Version mismatch blocking release

**Context:** Developer wants to release v0.4.0 but Makefile still says 0.3.1.

**Skill output:**
```
Release v0.4.0: 1 blocker found (4/5 checks passing)
  CHANGELOG entry        PASS
  Version consistency    FAIL — Makefile has FRAMEWORK_VERSION := 0.3.1, target is 0.4.0
  Clean working tree     PASS
  Release branch         PASS (on main)
  Tag uniqueness         PASS
```

## Anti-patterns

### Anti-pattern 1 — Releasing without running tests

The release-readiness skill checks structural shipping discipline, not runtime correctness. **Why it's tempting:** all 5 checks pass, so it feels ready. **What to do instead:** run `make test-all` and `/ascent-qa` before tagging. The skill reminds you but cannot enforce this — runtime checks are the developer's responsibility.
