# ADR-003: Make as the operator vocabulary

**Status:** Accepted
**Date:** <<SCAFFOLD_DATE>> (America/New_York)
**Decider:** <<BRAND>> · ASCENT v<<FRAMEWORK_VERSION>> baseline

## Context

<<PROJECT_TITLE>> has operations that humans run against it: start the stack, run tests, lint code, deploy, check status, rotate secrets. These operations need to be invocable consistently across three surfaces: a developer's laptop, a CI pipeline, and a production incident runbook.

Without a unified vocabulary, the same operation has different names and invocations in each context. The developer types `npm run dev`, CI runs `node scripts/test.sh`, and the runbook says "SSH in and run deploy.sh with the prod flag." Three surfaces, three incantations, three chances for divergence.

## Decision

Every operation that a human runs against <<PROJECT_TITLE>> happens through a `make` target. The same target name works on the developer's laptop, in CI, and in a production runbook.

The target list is SDLC-sectioned (`make help` groups targets into META · DEV · TEST · QA · SEC · VALIDATE · DOCS · INFRA) and follows the naming convention `<area>-<sub-area>-<action>` (e.g., `dev-up`, `test-unit`, `aws-ecs-deploy-prod`).

Future-phase functionality ships from Day 1 as named stubs that print `[STUB]` and exit 0. Names are final — never renamed when implementations land.

## Alternatives considered

**npm scripts (`package.json` scripts field).** Rejected because npm scripts are JavaScript-ecosystem-specific, can't orchestrate multi-service container operations naturally, and don't provide SDLC-sectioned help output. A `make` target that calls `npm run test` inside a container is fine; npm scripts as the primary vocabulary is not.

**Taskfile (go-task).** Rejected because it introduces a Go binary dependency for a task runner. Make is pre-installed on every Unix system and most CI images. Taskfile is a dependency; Make is infrastructure.

**Shell scripts (`scripts/` directory).** Rejected because scripts accumulate without discipline — no consistent naming, no discoverable help output, no sectioned organization. Make enforces these by convention (the `## SECTION: description` annotation pattern).

**Justfile (just).** Rejected for the same reason as Taskfile — it's an additional binary dependency that solves a problem Make already solves. Just's syntax is friendlier than Make's, but the delta doesn't justify adding a tool every developer must install.

## Consequences

**Easier:**

- `make help` is the single discovery command — every operation is listed, grouped, described
- Runbooks are sequences of `make` targets — operators copy-paste them under pressure
- CI configuration references the same targets — `make test-all`, `make qa`, `make aws-ecs-deploy-staging`
- New developers learn one vocabulary, not three

**Harder:**

- Make's syntax (tabs, not spaces; recipe continuation rules; shell-per-line) has a learning curve
- Long shell commands in Makefiles are harder to read than standalone scripts — mitigated by moving complex logic into `make/*.sh` helper scripts
- Make doesn't natively support Windows — developers on Windows use WSL2 (which the container-first approach already requires)

**Neutral:**

- Make targets delegate to language-specific tools where appropriate (`make test-unit` may call `npm test` inside a container) — Make is the vocabulary, not the build system

## Cost implications

**Time:** One-time cost to learn Make's syntax conventions (an afternoon). Ongoing time savings from never having to ask "how do I run this operation?" — `make help` answers.

**Complexity:** The `make/` directory with SDLC-sectioned `.mk` files is a small structural addition. The alternative (ad-hoc scripts accumulating over months) is higher-complexity in practice.

**Future flexibility:** Adding a new operation is one target in the appropriate `.mk` file. The vocabulary extends without restructuring.

**Money:** None. Make is free and pre-installed.
