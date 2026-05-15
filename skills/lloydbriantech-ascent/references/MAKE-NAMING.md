# MAKE-NAMING

> The naming convention every `make` target follows. [PRINCIPLES.md §2](../../../docs/framework/PRINCIPLES.md#2-make-is-the-only-operator-vocabulary) and [ADR-005](../../../docs/framework/DECISIONS/ADR-005-skill-naming.md) are authoritative.

## The convention

```
<area>-<sub-area>-<action>
```

Lowercase. Hyphen-separated. No abbreviations, no aliases, no mixed case. Each target name reads as a precise sentence about what the target does.

Examples:

- `dev-up`, `dev-down`, `dev-logs`, `dev-status`
- `test-unit`, `test-integration`, `test-e2e`
- `qa-lint`, `qa-typecheck`, `qa-structure`
- `aws-ecs-deploy-prod`, `aws-rds-snapshot-create`

## Reserved suffixes

- `-all` — "all variants in this area." Example: `make test-all` runs `test-unit` + `test-integration` + `test-e2e`. The `-all` target is itself a real target; it is not a wildcard.
- `-quick` — fast subset of a longer check. Example: `make dev-status-quick` is the ~80ms variant of `make dev-status`.

Targets that compose other targets do so via explicit prerequisites, not by name pattern. `make test-all: test-unit test-integration test-e2e` declares its composition.

## AWS resource segment

AWS targets carry a resource segment between provider and action:

```
aws-<resource>-<action>-<environment>
```

Examples:

- `aws-ecs-deploy-prod` — deploy to ECS in the prod environment
- `aws-rds-snapshot-create` — create an RDS snapshot
- `aws-ssm-parameter-rotate` — rotate an SSM parameter

The environment suffix is mandatory for actions that target an environment (`deploy`, `rollback`, `migrate`). It is omitted for actions that are environment-independent (`snapshot-create` on a single AWS account).

## SDLC sectioning

Targets are grouped into SDLC sections in `make help` output. Section ordering matches operator workflow — most-frequent operations first.

**Project-level (scaffolded projects):**

```
META · DEV · TEST · QA · SEC · VALIDATE · DOCS · INFRA
```

**Meta-repo (this framework itself):**

```
META · DEV · TEST · QA · DOCS · DIST · RELEASE
```

The two lists differ because the meta-repo has no application to deploy (no `SEC`, `VALIDATE`, `INFRA`) and the framework packages itself instead (`DIST`, `RELEASE`).

## Section annotation

Each target declares its section in a comment after the recipe header:

```make
test-unit:  ## TEST: Run unit tests
	$(ENGINE) compose run --rm app pytest tests/unit
```

`make help` parses these annotations and renders them grouped by section.

## Anti-patterns

- **Abbreviations.** `make ci` instead of `make ci-up` — ambiguous without context.
- **Aliases.** Two target names that do the same thing. `make build` and `make compile` both running `npm run build` violates the one-name rule.
- **Camel or snake case.** `make TestUnit` or `make test_unit` — never.
- **Verb-first instead of area-first.** `make deploy-aws-ecs-prod` reads worse than `make aws-ecs-deploy-prod` because operators search by area, not by verb.
- **Hidden actions inside other targets.** `make dev-up` that secretly runs migrations is harder to reason about than `make dev-up` that depends explicitly on `make data-migrate`.

## Stub-first rule

Future-phase targets ship from Day 1 under their final name:

```make
test-mutation:  ## TEST: Mutation testing [STUB lands in P3.0]
	@printf "[STUB] make test-mutation lands in Phase 3 (v0.4.0)\n"
```

Never rename a target to "promote" it from stub to real. The name is the name from the day the placeholder ships.

## Composition with `$(ENGINE)`

Targets that invoke containers go through `$(ENGINE)`:

```make
dev-up:  ## DEV: Start the dev stack
	$(ENGINE) compose up -d
```

`$(ENGINE)` auto-detects Podman (preferred) and falls back to Docker. The user overrides with `ENGINE=docker make dev-up`. Targets that don't need a container engine (linting, formatting, file generation) never call `$(ENGINE)`.

## Worked example

The framework's own `Makefile` and `make/*.mk` tree (at the repo root) is a worked example of every rule above. Eight section files, SDLC-sectioned help, working QA targets, stub-first naming for `test`, `doc-stub`, `package`, and `release`.
