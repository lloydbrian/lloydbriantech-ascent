# ADR-004: Slug taxonomy — kebab-case, 2–4 segments, mechanical derivation

**Status:** Accepted
**Date:** 2026-05-14 (America/New_York)
**Decider:** lloydbriantech

## Context

A scaffolded project carries a name that appears in many places: the directory, the container labels, the image tags, environment variable prefixes, the title shown in the README, the package name, the Make target prefixes, the container hostnames. Without discipline, the name appears in slightly different forms in each place — `LawnCareApp` here, `lawn_care_app` there, `lawn-care` somewhere else — and the project becomes a low-grade cognitive tax forever after.

Two failure modes are common:

**Manual transliteration drift.** The user types "lawn-care-app" once, then types variations into other config files, occasionally getting it slightly wrong. The downstream tooling can't cross-reference reliably because the strings don't match.

**Multi-variable interview fatigue.** A scaffolder asks for `project_slug`, `project_name`, `package_name`, `container_prefix`, and `env_var_prefix` separately. Users enter inconsistent combinations because they don't understand which is which.

The framework needs one canonical input — a single slug — from which all variants derive mechanically. The user provides one word at scaffold time; the framework produces consistency forever.

## Decision

The user provides one project slug at scaffold time. The slug must satisfy these rules:

- **Kebab-case** — lowercase letters, digits, hyphens; no spaces, no underscores, no capitals
- **2 to 4 hyphen-separated segments** — `lawn-care-app` ✓, `lawn-care` ✓, `lawn-care-app-platform` ✓, `lawncareapp` ✗, `lawn-care-app-platform-v2` ✗
- **Total length 6–40 characters**
- **First character is a letter** (not a digit, not a hyphen)
- **Last character is a letter or digit** (not a hyphen)
- **No consecutive hyphens**

From the user's single input, the framework derives every other variant mechanically:

| Variant | Rule | Example (`lawn-care-app`) |
|---|---|---|
| `PROJECT_SLUG` | Input as-is | `lawn-care-app` |
| `PROJECT_SLUG_UPPER` | Uppercase, hyphens → underscores | `LAWN_CARE_APP` |
| `PROJECT_TITLE` | Title-case each segment, join with spaces | `Lawn Care App` |
| `PROJECT_PKG` | Same as `PROJECT_SLUG` (kebab-case is npm-valid) | `lawn-care-app` |
| `PROJECT_LABEL` | Same as `PROJECT_SLUG` | `lawn-care-app` |
| `CONTAINER_DEV` | `<slug>-dev` | `lawn-care-app-dev` |
| `CONTAINER_PROD` | `<slug>-prod` | `lawn-care-app-prod` |
| `IMAGE_DEV` | `<slug>:dev` | `lawn-care-app:dev` |
| `IMAGE_PROD` | `<slug>:prod` | `lawn-care-app:prod` |
| `NETWORK_NAME` | `<slug>-net` | `lawn-care-app-net` |
| `VOLUME_DATA` | `<slug>-data` | `lawn-care-app-data` |
| `INSIDE_CONTAINER_MARKER` | `<PROJECT_SLUG_UPPER>_INSIDE_CONTAINER` | `LAWN_CARE_APP_INSIDE_CONTAINER` |
| `ENV_PREFIX` | `<PROJECT_SLUG_UPPER>` | `LAWN_CARE_APP` |
| `GH_REPO` | `<gh_owner>/<slug>` | `lloydbrian/lawn-care-app` |

The slug is recorded in `.ascent-meta.json` under `project_slug`. The skill never asks the user for any of the derived variants — they are always computed from the slug.

## Alternatives considered

**Multiple separate inputs.** Ask the user for each variant separately. Rejected because of interview fatigue and inevitable inconsistency. Users get bored answering five questions when one would do; they enter slightly different things.

**Snake_case or camelCase canonical form.** Considered. Rejected because kebab-case is the broadest-compatible: works as npm package name, works as Docker image name, works as DNS name, works as container label, works as URL path segment. Snake_case fails some of these; camelCase fails almost all of them.

**Free-form slug with no constraints.** Rejected because lack of constraints produces inconsistency. The 2–4 segment limit and the character-class rules are constraints that produce uniformly clean output.

**Slug entered without derivation — user enters each variant directly when needed.** Rejected as the same as multiple separate inputs but spread over time. Same problem, slower onset.

**Allow segments of one.** A single-segment slug like `app` is too generic to be useful as a container label or environment variable prefix. Two-segment minimum forces enough specificity to be distinctive across a developer's set of projects.

**Allow more than 4 segments.** Rejected because 5+ segment slugs get unwieldy as container labels and environment variable prefixes. If a project name needs 5 segments to describe, the project probably needs to pick a shorter codename.

**Permit digits as first character.** Rejected because some downstream tools (npm package names, some DNS resolvers) treat leading digits oddly. Letter-first is the safe rule.

## Consequences

**Easier:**

- One question at scaffold time, dozens of consistent variants forever
- Cross-reference works reliably (any string in any file referencing the project can be derived from the slug)
- Cleanup commands filter precisely by container label
- Environment variable namespacing is predictable
- Multi-project developers can have many ASCENT projects coexisting on one machine without slug collisions in container names

**Harder:**

- A user who wants a project name that doesn't fit the rules (e.g., one that starts with a digit, or has 5 segments) must pick a different name or accept an ADR-superseding-this-decision in their project
- The mechanical derivation has to be implemented carefully in the skill — a buggy `slug_to_title()` is a frustrating bug

**Neutral:**

- The slug rules are simple enough to enforce with a regex; documented in `references/SLUG-CONVENTIONS.md`

## Cost implications

**Time:** Saves ongoing time across every interaction with the project. Pays for the modest up-front cost of choosing a conforming name.

**Complexity:** Low. The derivation rules are a small table; the validation regex is a few characters.

**Future flexibility:** The rules can be loosened later (allow 5 segments, allow leading digits) without breaking existing projects. Tightening would be breaking.

**Money:** None.
