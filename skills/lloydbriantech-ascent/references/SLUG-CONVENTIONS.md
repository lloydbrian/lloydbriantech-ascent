# SLUG-CONVENTIONS

> Slug taxonomy and derivation rules. [ADR-004](../../../docs/framework/DECISIONS/ADR-004-slug-conventions.md) is authoritative.

## The single input

The user provides **one** slug at scaffold time. Every other variant — uppercase env-var prefix, container labels, package name, image tags — is derived mechanically. The framework never asks for a separate package name, env-var prefix, or label.

## Validation rules

The input slug must satisfy all of:

- **Kebab-case** — lowercase letters, digits, hyphens. No spaces, no underscores, no capitals.
- **2 to 4 hyphen-separated segments** — `lawn-care-app` ✓, `lawn-care` ✓, `lawn-care-app-platform` ✓; `lawncareapp` ✗ (one segment), `lawn-care-app-platform-v2` ✗ (five segments).
- **Total length 6–40 characters.**
- **First character is a letter** — not a digit, not a hyphen.
- **Last character is a letter or digit** — not a hyphen.
- **No consecutive hyphens.**

Validating regex: `^[a-z][a-z0-9-]{4,38}[a-z0-9]$` plus an additional check that the slug splits into 2–4 segments and contains no `--`.

## Derivation table

From the single input, the framework derives every variant.

| Variant | Rule | Example for `lawn-care-app` |
|---|---|---|
| `PROJECT_SLUG` | Input as-is | `lawn-care-app` |
| `PROJECT_SLUG_UPPER` | Uppercase, hyphens → underscores | `LAWN_CARE_APP` |
| `PROJECT_TITLE` | Title-case each segment, join with spaces | `Lawn Care App` |
| `PROJECT_PKG` | Same as `PROJECT_SLUG` (kebab is npm-valid) | `lawn-care-app` |
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

## Recording

The canonical slug lives in `.ascent-meta.json` under `project_slug`. The skill never asks the user for any derived variant — they are always computed from the slug.

## Anti-patterns

- **Multiple separate inputs.** Asking for `project_slug`, `package_name`, `container_prefix` separately invites inconsistency. The framework asks once.
- **Snake_case or camelCase canonical form.** Kebab is the broadest-compatible — works as npm package, Docker image, DNS name, container label, URL path segment. Other cases fail one or more of these.
- **Slug entered without derivation.** Even when a user knows what container name they want, they must derive it from the slug, not enter it directly. Consistency is the property worth preserving.
- **Single-segment slugs.** `app` is too generic to be useful as a container label or env-var prefix. Two-segment minimum forces distinctiveness across a developer's set of projects.
- **5+ segments.** Unwieldy as a label or env-var prefix. If a name needs 5 segments to describe, pick a shorter codename.
- **Leading digit.** Some downstream tools (npm package names, certain DNS resolvers) treat leading digits oddly. Letter-first is safe.

## Worked example

User input at scaffold time: `lawn-care-app`

Derived state across a generated project:

```
.ascent-meta.json:  project_slug = "lawn-care-app"
package.json:       "name": "lawn-care-app"
docker-compose:     container_name: lawn-care-app-dev
                    image: lawn-care-app:dev
                    labels: project=lawn-care-app
.env.example:       LAWN_CARE_APP_PORT=
                    LAWN_CARE_APP_DB_URL=
Dockerfile:         ENV LAWN_CARE_APP_INSIDE_CONTAINER=1
README.md:          # Lawn Care App
GitHub:             lloydbrian/lawn-care-app
```

Every appearance of the slug or its variants traces back to the single input.

## Overriding the convention

A project that genuinely needs a name that doesn't fit (e.g., 5 segments, leading digit) writes a project-level ADR titled `ADR-NNN-supersede-slug-convention` explaining the exception and what replaces the standard derivation.
