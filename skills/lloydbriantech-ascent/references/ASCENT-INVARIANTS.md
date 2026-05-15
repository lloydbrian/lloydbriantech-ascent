# ASCENT-INVARIANTS

> Runtime restatement of the 14 framework invariants. [PRINCIPLES.md](../../../docs/framework/PRINCIPLES.md) in the meta-repo is authoritative if this file drifts from it.

The 14 invariants every ASCENT project must satisfy. Each is load-bearing; none is optional. Violations are either fixed or formally superseded by a project-level ADR titled `ADR-NNN-supersede-principle-N`.

---

## 1. Containerization-first

**Rule:** The development environment is the container. There is no host-language path.

**Why:** "Works on my machine" becomes impossible by construction when the container *is* the application.

**Surfaces in:** Architect's Dockerfile templates; absence of `npm install` / `pip install` in dev runbooks; `make dev-up` boots the stack with only the container engine installed on the host.

## 2. Make is the only operator vocabulary

**Rule:** Every human-run operation flows through a `make` target. The same target name works on a developer laptop, in CI, and in production runbooks.

**Why:** Cognitive consistency across surfaces beats locally-optimal naming on each surface.

**Surfaces in:** The `make/` directory; absence of bespoke shell scripts that duplicate make-target functionality; runbooks that read as `make` invocations. See [MAKE-NAMING.md](MAKE-NAMING.md) for the naming convention.

## 3. SDLC-sectioned `make help`

**Rule:** `make help` is grouped into labeled sections in SDLC workflow order. Bare `make` runs `make help`.

**Why:** A help output that requires the reader to know what they're looking for is a help output that doesn't help.

**Surfaces in:** The parent Makefile's `help` target; section markers in `make/*.mk` files; the `## SECTION: <desc>` annotation convention.

## 4. Stub-first naming for deferred work

**Rule:** Future-phase functionality ships from Day 1 under its final name, printing `[STUB] lands in PX.Y` and exiting 0.

**Why:** Renaming targets after the fact is a tax paid by everyone who memorized the old name.

**Surfaces in:** Every `make/*.mk` file in the framework's meta-repo (`make test`, `make package`, `make doc-stub`); the `[STUB] lands in ...` phrase as the canonical signal.

## 5. `.env` discipline

**Rule:** `.env` is gitignored AND dockerignored. `.env.example` contains empty defaults only — never `REPLACE_ME` or other fake-but-non-empty placeholders. Production secrets come from the environment, never from a baked-in file.

**Why:** Fake placeholders are an attractive nuisance — they get deployed, cargo-culted, committed.

**Surfaces in:** [ENV-DISCIPLINE.md](ENV-DISCIPLINE.md) for the full pattern; `.gitignore` and `.dockerignore` template entries; the `ascent-self-audit` skill's detection patterns.

## 6. Strict backend layering

**Rule:** The backend pipeline is `routes → controllers → services → storage`. Only the storage layer writes data. Routes register only. Controllers contain no business logic.

**Why:** Without strict layering, every service grows a god class with SQL in the controller and a business rule in the route.

**Surfaces in:** Developer-role reference modules; the `ascent-adr-conformance` skill; the always-emitted ADR-002 in every scaffolded project.

## 7. ADR discipline

**Rule:** Every architectural decision lands in `docs/architecture/decisions/ADR-NNN-<slug>.md` using the canonical template (Context, Decision, Alternatives considered, Consequences, Cost implications). `INDEX.md` lists every ADR in numeric order.

**Why:** Without ADRs, decisions decay into lore. ADR discipline makes rationale explicit and durable.

**Surfaces in:** [ADR-TEMPLATE.md](ADR-TEMPLATE.md) for the canonical format; the `ascent-adr-conformance` skill; the architect role's reference module.

## 8. Phase-gated delivery with explicit go-signal

**Rule:** Work is organized into numbered phases with explicit exit criteria. No phase begins without the literal signal **"Proceed with Phase N."** Phase transitions update `CHANGELOG.md` and the `phase` field of `.ascent-meta.json`.

**Why:** Implicit phase transitions become explicit phase confusion.

**Surfaces in:** [PHASE-PROTOCOL.md](PHASE-PROTOCOL.md) for the full transition discipline; the delivery-lead's PHASE-PLAN; the `ascent-delivery-status` skill.

## 9. Label-based project scoping

**Rule:** Every container, image, network, and volume carries `--label project=<project-slug>`. Cleanup operations filter by label, never by name-string-matching.

**Why:** Name-matching cleanup is the source of "I just deleted my coworker's database" stories.

**Surfaces in:** Container start commands; `podman-clean-*` make targets filter by label; multi-project developers can clean one project without disturbing others.

## 10. Container engine compatibility

**Rule:** All Make targets use `$(ENGINE)`, which auto-detects Podman (preferred) and falls back to Docker. `ENGINE=docker make <target>` works identically.

**Why:** Hard-coding one engine becomes an obstacle when the team's engine choice evolves.

**Surfaces in:** The parent Makefile's `ENGINE` variable; targets that don't need an engine never call one.

## 11. Context-aware host/container execution

**Rule:** The runtime container sets `<PROJECT_SLUG_UPPER>_INSIDE_CONTAINER=1`. Targets that behave differently on host versus inside-container use this marker to degrade gracefully.

**Why:** Without context awareness, CI runners produce recursive container-spawning or fail engine detection inside containers that lack one.

**Surfaces in:** The Dockerfile setting the marker; `make/test.mk` branching on it; CI workflows reading the same marker.

## 12. Graceful shutdown

**Rule:** The application traps `SIGTERM` and drains in-flight work before exiting. `make dev-down` sends `SIGTERM` first with a 15-second grace period, then `SIGKILL`.

**Why:** Hard kills produce corrupted state, partial writes, and angry users.

**Surfaces in:** The server stub's SIGTERM handler; `make dev-down` grace-period logic; runbooks that assume graceful drain.

## 13. `dev-status` morning-standup family

**Rule:** Every project ships `make dev-status` (full check, ~3–5s) and `make dev-status-quick` (fast subset, ~80ms). Every output row pairs with a deep-dive command. The "Next Actions" section adapts to detected state. The status command never fails — it reports state, it doesn't gate.

**Why:** "What state is my dev environment in?" is the most-asked question in a software project.

**Surfaces in:** `make/dev-status.mk`; row-by-row deep-dive commands; the `PHASE-PROTOCOL.md` status-on-transition pattern.

## 14. Persona-segmented documentation

**Rule:** The README and overall doc structure organize content by audience — Architects, Developers, Operators, Contributors, Learners. Documents are written for one primary audience, not for everyone simultaneously.

**Why:** Universal documentation is documentation no one reads.

**Surfaces in:** README role-segmented tables; the `ascent-persona-coverage` skill; the `audience-mapping.md` practice module.

---

## When an invariant is broken

Two valid paths:

1. **Fix it.** The invariant is the default for a reason. Fixing the violation is usually cheap.
2. **Supersede it.** Write a project-level ADR titled `ADR-NNN-supersede-principle-N` explaining which invariant is broken, why this project is an exception, what replaces it (if anything), and when it might be reinstated (if ever).

The illegitimate path is silent violation. The `ascent-self-audit` skill exists to make silent violations loud.
