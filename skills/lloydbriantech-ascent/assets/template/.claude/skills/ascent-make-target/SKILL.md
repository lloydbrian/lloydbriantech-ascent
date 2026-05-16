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

Proposes correctly-named make targets per the MAKE-NAMING convention and places them in the right `.mk` file. Prevents naming violations (aliases, abbreviations, wrong section, camelCase) before they accumulate into vocabulary drift.

## When this skill engages

- When a developer needs to add a new operation to the project's vocabulary
- When explicitly asked to "add a make target for X"
- When a new feature requires operational commands (deploy, migrate, seed, etc.)
- During code review to validate proposed target names

## Inputs

- What the target should do (the operation, in plain language)
- Optional: the target area (dev, test, qa, sec, infra, etc.)
- Optional: existing context about where it fits in the SDLC

## Outputs

- A proposed target name following `<area>-<sub-area>-<action>` convention
- The `.mk` file where it belongs (by SDLC section)
- The `## SECTION: description` annotation for `make help` rendering
- The implementation (real or `[STUB]` depending on whether the operation can be implemented now)

## Operational logic

The skill reads the existing `make/*.mk` tree to understand current targets and sections, proposes a name following the convention (lowercase, hyphen-separated, area-first), checks for collisions or aliases with existing targets, and places the new target in the correct `.mk` file with the proper section annotation. After creation, [ascent-self-audit](../ascent-self-audit/SKILL.md) can validate the naming conforms. The full naming-validation decision tree (reserved suffixes, AWS resource segments, composition patterns) lands in Phase 3.

## Examples

Examples land in Phase 3. Each example will show a plain-language operation description, the proposed name, and the placement in the .mk tree.

## Anti-patterns

The primary failure mode is **accepting developer-proposed names without validation** — a developer says "let's call it `deploy`" and the skill creates it without checking that it should be `aws-ecs-deploy-staging` (area-first, resource-segmented, environment-suffixed). The skill should always propose the canonical name, even when the developer's shorthand feels natural.
