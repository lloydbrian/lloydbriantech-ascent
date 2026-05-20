---
name: ascent-make-target
description: >-
  Proposes and creates new make targets for <<PROJECT_TITLE>> following
  the MAKE-NAMING convention (<area>-<sub-area>-<action>), places them
  in the correct SDLC-sectioned .mk file, and validates the naming
  against existing targets to prevent aliases or collisions.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
  - Edit
---

# ascent-make-target

Proposes correctly-named make targets per the `MAKE-NAMING` reference module convention and places them in the right `.mk` file. Prevents naming violations (aliases, abbreviations, wrong section, camelCase) before they accumulate into vocabulary drift. Write-capable: uses Write for new `.mk` files and Edit to append targets to existing `.mk` files with section-aware placement.

## When this skill engages

- When a developer needs to add a new operation to the project's vocabulary
- When explicitly asked to "add a make target for X"
- When a new feature requires operational commands (deploy, migrate, seed, etc.)
- During code review to validate proposed target names
- NOT for renaming existing targets (that's a manual refactor with grep-and-replace)

## Inputs

- **Plain-language description** — what the target should do (required)
- **Target area** (optional) — dev, test, qa, sec, validate, docs, infra. If not provided, the skill infers from the description.
- **Recipe** (optional) — the actual shell commands. If not provided, the skill creates a stub.

## Outputs

- **Proposed target name** following `<area>-<sub-area>-<action>` convention
- **The `.mk` file** where the target belongs (by SDLC section)
- **The target block** including `.PHONY` declaration, section annotation, and recipe (or `[STUB]`)
- **Confirmation** that the target was written to the `.mk` file

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Catalog existing targets

**Condition:** `make/*.mk` files exist.

**Action on PASS:** Read all `.mk` files. For each file, extract: file name, section name (from the `# SECTION —` header comment), and all target names (lines matching `<name>:  ##`). Build a catalog: `{file: "dev.mk", section: "DEV", targets: ["dev-up", "dev-down", ...]}`.

**Action on FAIL:** No `make/` directory. Report: "No make/ tree found. This project may not use SDLC-sectioned make targets yet. Consider scaffolding the make/ tree first."

### Step 2 — Parse description into area and action

**Action:** Extract the area (dev, test, qa, sec, validate, docs, infra) and action from the developer's plain-language description:

- "run database migrations" → area: `data`, action: `migrate`
- "deploy to ECS in production" → area: `aws-ecs`, action: `deploy-prod`
- "lint the frontend code" → area: `qa`, action: `lint-frontend`
- "start the monitoring stack" → area: `infra`, action: `monitor-up`

Apply the `MAKE-NAMING` reference module rules: lowercase, hyphen-separated, area-first (never verb-first). No abbreviations (`ci` → `ci-up`, not just `ci`). No camelCase.

For AWS targets, include the resource segment: `aws-<resource>-<action>-<environment>`.

Report: "Proposed name: `<area>-<sub-area>-<action>`. Derived from: [description]."

### Step 3 — Propose canonical name

**Condition:** Area and action are identified.

**Action:** Assemble the full target name. Present it to the developer: "Proposed target: `<name>`. Does this name accurately describe the operation?"

If the developer proposes a different name, validate it against MAKE-NAMING rules. Reject if it violates:
- Verb-first ordering (`deploy-aws-ecs-prod` → should be `aws-ecs-deploy-prod`)
- Abbreviations (`db-mig` → should be `data-migrate`)
- CamelCase (`dataBackup` → should be `data-backup`)
- Missing area prefix (`migrate` → should be `data-migrate`)

### Step 4 — Check for alias collision

**Action:** Search the catalog from Step 1 for targets that do the same thing under a different name. An alias collision is: two names for the same operation.

Detection heuristic: extract the action verb and object from both the proposed name and existing targets. If two targets share the same action+object but differ only in area prefix or synonym (`build` vs `compile`, `start` vs `up`, `stop` vs `down`), flag as a potential alias.

**Action on collision:** "Potential alias: `<proposed>` may duplicate `<existing>`. These targets appear to do the same thing. Use the existing target or rename to differentiate."

**Action on no collision:** Proceed.

### Step 5 — Check for name collision

**Action:** Check the catalog for an exact name match.

**Action on collision:** "Target `<name>` already exists in `<file>`. Options: (A) Abort — the target is already defined. (B) Rename — choose a different name that differentiates."

**Action on no collision:** Proceed.

### Step 6 — Identify correct .mk file

**Action:** Map the area prefix to the correct `.mk` file per SDLC section:

| Area prefix | SDLC section | File |
|---|---|---|
| `dev-*` | DEV | `make/dev.mk` |
| `test-*` | TEST | `make/test.mk` |
| `qa-*` | QA | `make/quality.mk` |
| `sec-*` | SEC | `make/security.mk` |
| `validate-*` | VALIDATE | `make/validate.mk` |
| `doc-*` | DOCS | `make/docs.mk` |
| `infra-*`, `aws-*` | INFRA | `make/infra.mk` |
| `data-*` | DEV | `make/dev.mk` (data operations are dev workflow) |
| `engine-*` | DEV | `make/engine.mk` |
| `session-*` | DEV | `make/session.mk` |

If the area doesn't map to an existing file, propose creating a new `.mk` file following the naming convention.

### Step 7 — Recipe or stub

**Action:** Ask the developer: "Do you have the recipe (shell commands) for this target, or should I create a [STUB] placeholder?"

**If recipe provided:** Validate that container-invoking commands use `$(ENGINE)` prefix. Validate that the recipe doesn't embed hidden side-effects (e.g., a `dev-up` that secretly runs migrations — per MAKE-NAMING anti-patterns).

**If no recipe:** Generate a stub per the MAKE-NAMING stub-first rule:
```make
<name>:  ## SECTION: <description> [STUB lands in <phase>]
	@printf "[STUB] make <name> lands in <phase>\n"
```

### Step 8 — Generate target block

**Action:** Build the complete target block:

```make
<name>:  ## SECTION: <description>
	<recipe lines>
```

Include the `.PHONY` declaration. If the target file already has a `.PHONY` line, the new target name appends to it. If not, generate a new `.PHONY` line.

For `$(ENGINE)` targets, apply the engine prefix to every line that invokes containers.

### Step 9 — Present target for review

**Action:** Present the complete target block to the developer, including which file it will be written to and where in the file it will be placed. Report:

```
Target: <name>
File: make/<file>.mk
Placement: after the last existing target in the <SECTION> section
Recipe: [real | STUB]

[target block]
```

**Gate:** Developer must approve before writing.

### Step 10 — Write target to .mk file

**Condition:** Developer has approved.

**Action — appending to an existing `.mk` file (the common case):**

Use **Edit** with section-aware placement. The mechanism:

1. Find the section header comment matching the target's SDLC section (e.g., `# TEST —` for a test target). Each `.mk` file has exactly one section — the file IS the section.
2. Find the last target block in the file. A target block is: the recipe lines of the last `<name>:  ##` entry, identified by finding the last line that starts with a tab character (recipe line) before either the next target header or end of file.
3. Append the new target block (blank line + `.PHONY` update + blank line + target) after the last target block.

This means appending at the end of the file in practice, because each `.mk` file contains one SDLC section and targets within that section are ordered chronologically (new targets append). The section-awareness matters when the `.mk` file has a trailing comment block or footer — the new target goes before those, after the last recipe line.

**If the section header is missing** (the `.mk` file exists but doesn't have the expected `# SECTION —` header): append at the end of the file and emit a warning: "Warning: [file] is missing its section header comment. Consider adding `# SECTION — description.` at the top."

**Action — creating a new `.mk` file:**

Use **Write** to create the file with the standard structure:
```make
# SECTION — description.
#
# [context comment]

.PHONY: <name>

<name>:  ## SECTION: <description>
	<recipe>
```

Then **Edit** the root `Makefile` to add the `include make/<new-file>.mk` line, placed in alphabetical order among existing includes.

**Valid paths:** This skill writes to `make/*.mk` and edits the root `Makefile` (for `include` lines only). Any other path is a step failure.

Report: "Target `<name>` written to `make/<file>.mk`. Run `make help` to verify it appears in the [SECTION] section. Consider running [ascent-self-audit](../ascent-self-audit/SKILL.md) to validate Makefile structure."

## Examples

### Example 1 — Dev target with recipe

**Input:** "Add a target to seed the database with sample data." Recipe: `$(ENGINE) compose exec backend node storage/seed.js`

**Skill output:**
```
Proposed name: data-seed
File: make/dev.mk
Section: DEV
```

```make
data-seed:  ## DEV: Seed database with sample data
	@$(ENGINE) compose exec backend node storage/seed.js
```

### Example 2 — AWS deploy target (area-resource-action-env pattern)

**Input:** "Add a target to deploy the backend to ECS in staging."

**Skill output:**
```
Proposed name: aws-ecs-deploy-staging
File: make/infra.mk
Section: INFRA
```

The developer hasn't provided the recipe, so the skill generates a stub:
```make
aws-ecs-deploy-staging:  ## INFRA: Deploy backend to ECS staging [STUB]
	@printf "[STUB] make aws-ecs-deploy-staging — add ECS deploy commands\n"
```

### Example 3 — Stub promotion

**Input:** "Promote the test-mutation stub to a real target." Recipe: `cd backend && npx stryker run`

**Skill action:** Reads `make/test.mk` → finds existing stub `test-mutation` → replaces the stub recipe with the real recipe. Uses **Edit** to replace the stub printf line with the actual command.

### Example 4 — Alias rejection

**Input:** "Add a `dev-start` target to start the dev stack."

**Skill output:** "Potential alias: `dev-start` duplicates `dev-up` (both start the dev stack). The existing `dev-up` already does this. Use `make dev-up` instead, or explain how `dev-start` differs."

## Anti-patterns

### Anti-pattern 1 — Verb-first naming

`deploy-aws-ecs-prod` instead of `aws-ecs-deploy-prod`. **Why it's tempting:** English reads verb-first. **What to do instead:** operators search by area. Area-first naming groups related targets in `make help` output and in tab completion.

### Anti-pattern 2 — Abbreviations and shorthand

`db-mig` instead of `data-migrate`, `ci` instead of `ci-up`. **Why it's tempting:** less typing. **What to do instead:** `make help` renders full names; tab completion fills them. Abbreviations create vocabulary drift — two developers independently abbreviate differently.

### Anti-pattern 3 — Hidden side-effects

A `dev-up` that secretly runs migrations, seeds data, and rebuilds the frontend. **Why it's tempting:** one command that "does everything." **What to do instead:** explicit composition via prerequisites. `dev-up: data-migrate data-seed frontend-build` declares its dependencies; `dev-up` with hidden inline commands doesn't.

### Anti-pattern 4 — Accepting developer-proposed names without validation

A developer says "let's call it `deploy`" and the skill creates it. **Why it's tempting:** the developer knows what they want. **What to do instead:** the skill always proposes the canonical name. `deploy` should be `aws-ecs-deploy-prod` (area-first, resource-segmented, environment-suffixed). The canonical name is longer but unambiguous.
