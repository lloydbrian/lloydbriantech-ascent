---
name: design-principles-check
description: >-
  Use when asked "check our design principles", "is this MVC done right?",
  "SOLID or layering review", "is this twelve-factor?", or when
  architecture-review flags a design concern. Detects the architecture style,
  then checks separation of concerns, coupling, object-oriented design,
  twelve-factor configuration and API design with file:line evidence. Read-only.
version: 0.1.2
allowed-tools: Read, Grep, Glob
---

# design-principles-check

A focused review of how the code is organized, against the software design principles in section 4 of [architecture-principles.md](../../references/architecture-principles.md). It is a sibling of [architecture-review](../architecture-review/SKILL.md) and uses its severity table. Most findings here are Medium (when they block a quality target) or Low; a design smell that blocks nothing is a note, not a finding.

Stack-specific layering rules (for example ASCENT's Node.js routes → services → storage rule) belong to the `ascent-node-stack` plugin (planned). This skill stays language-neutral and judges the principles, not one framework's conventions.

## Steps

### Step 1 — Detect the style

Detect, don't ask. Read the directory layout, the entry points and a sample of imports, then name the style the code is trying to follow:

| Signals | Style |
|---|---|
| `models/`, `views/` or `templates/`, `controllers/` or `routes/` | MVC |
| `routes/` or `handlers/` → `services/` → `storage/` or `repositories/` | Layered |
| `domain/` or `core/` with `adapters/` or `infrastructure/`; interfaces owned by the domain | Hexagonal (ports and adapters) |
| One function per file under `functions/` or `handlers/`, IaC wiring them to events | Serverless functions |
| HTML, CSS and JS with no server code, data from JSON or an API | Static site (with or without an API) |
| No consistent structure | Unstructured: report it, then judge against layered |

State the detected style and the evidence. If the repository's AGENTS.md, CLAUDE.md or an ADR declares a style, judge against that one and note any mismatch.

### Step 2 — Check the principles

Check each that applies; skip the rest and say why.

1. **Separation of concerns.** Presentation, application logic and data access live in different modules. Grep UI and template files for data-access calls (`fetch(` to third-party hosts with secrets, SQL keywords, SDK clients); grep route or handler files for business rules longer than validation and a call.
2. **Dependency direction and coupling.** Inner layers do not import outer ones (domain does not import web frameworks, ORMs or cloud SDKs). Look for import cycles between top-level modules. Services sharing one database table are coupled; name the table.
3. **Object-oriented design (when the code is OO).** Single responsibility (classes with unrelated public methods, files over ~500 lines doing several jobs); type switches (`instanceof`, `switch (type)`) that a polymorphic method would replace; subclasses that throw "not supported" (substitution); wide interfaces most implementers stub out; constructors that `new` their own dependencies where injection would allow testing.
4. **Configuration and state (twelve-factor).** Config from the environment, not hardcoded hosts, ports, regions or keys; no local file state in request handling; logs to stdout or a log service; the same build promoted from beta to prod.
5. **API design.** Additive or versioned contracts; idempotent writes (PUT or an idempotency key) wherever a client or queue can retry; consistent error shape and status codes; pagination on list endpoints; validation at the boundary.
6. **Errors.** No swallowed exceptions (`catch {}`, `except: pass`); errors logged once, with an id; failures mapped to the right status.
7. **One home per rule.** The same business rule implemented in two places (client and server, two services, a script and the app) will drift. Name both locations.

### Step 3 — Report

```
design-principles-check: <style detected> — <M> Medium, <L> Low, <n> notes
Style evidence: <files and signals>

Findings, most severe first (architecture-review format):
D<n>  <severity>  <file>:<line>
      Principle: <e.g. Separation of concerns>
      Scenario: <what this makes harder or breaks: a quality target, a test, a change>
      Fix: <smallest refactor that closes it, and its risk>

Notes (no target blocked): <one line each>
```

Prefer small, reversible refactors, and name a test that would protect each one. A large restructuring is a one-way door: recommend an ADR and a delivery loop, not a drive-by change.

## What this skill does not do

- Refactor code. Fixes go through the delivery loop (`ascent-delivery`).
- Enforce one framework's folder conventions: that is `ascent-node-stack` (planned) or the project's own AGENTS.md.
- Review infrastructure, cost or deployment: see [architecture-review](../architecture-review/SKILL.md) and [deployment-options](../deployment-options/SKILL.md).
