# ASCENT Principles

The fourteen invariants that define an ASCENT project. These are not aspirations or recommendations — they are the conditions that must hold for a project to be considered ASCENT-compliant.

If a project breaks any of these invariants, either the project is broken or the principle has been deliberately superseded by a project-level ADR. The framework provides the default; the project retains the right to override with explicit justification.

The principles are numbered for reference. The numbering is not a priority order — every principle is load-bearing.

---

## 1. Containerization-first

The development environment **is** the container. There is no host-language path. A developer with the container engine installed and nothing else should be able to clone the repository and run `make dev-up` to a working stack.

The container is not a deployment artifact bolted onto a host-developed application. It is the application. The host machine's role is to run the container engine — nothing more.

**Why:** "Works on my machine" is the single largest source of friction in software delivery. When the development environment is the container, this class of bug becomes impossible by construction.

**What this rules out:** `npm install && npm run dev` on the host. Local Python virtual environments for application code. `pip install -r requirements.txt` on the developer's machine.

**What this still allows:** Local installs of tooling that is itself a host concern — the container engine, `make`, `git`, the IDE. These are not application dependencies.

## 2. Make is the only operator vocabulary

Every operation that a human runs against the project — start the stack, run tests, lint code, deploy to staging, rotate a credential, check security posture — happens through a `make` target. The same target name works on a developer laptop, in CI, in production incident response.

There is no separate vocabulary for "developer commands" versus "CI commands" versus "ops runbook commands." There is one set of names, used everywhere.

**Why:** Cognitive consistency across surfaces is worth more than the locally-optimal naming for each surface. When the same `make dev-up` works in three places, runbooks become operational rather than ceremonial.

**Naming convention:** `<area>-<sub-area>-<action>`, no aliases. The `-all` suffix means "all variants in this area." AWS targets carry a resource segment (`aws-ecs-deploy-prod`). See [ADR-005](DECISIONS/ADR-005-skill-naming.md) for the full convention; the Make naming convention follows the same shape applied to make targets.

## 3. SDLC-sectioned `make help`

The output of `make help` is grouped into labeled sections in SDLC workflow order: META · DEV · TEST · QA · SEC · VALIDATE · DOCS · INFRA. Bare `make` runs `make help`.

The section order is curated to match operator workflow — most-frequent operations first, cheapest-first within static checks, release-pipeline-order within infra.

**Why:** A help output that requires the reader to know what they're looking for is a help output that doesn't help. Section grouping converts the target list from a reference into a workflow.

## 4. Stub-first naming for deferred work

Future-phase functionality ships from Day 1 as named stubs that print `[STUB] lands in PX.Y` and exit zero. The names are the final names — never renamed when the implementation lands.

**Why:** Renaming targets is a tax paid by everyone who memorized the old name. Stub-first naming pays the design cost once, at the start, and amortizes it across the project's life.

## 5. `.env` discipline

The `.env` file is gitignored and dockerignored. The `.env.example` file is committed and contains **empty defaults only** — never fake-but-non-empty placeholders like `REPLACE_ME`. The production image's filesystem doesn't include `.env`; production secrets come from the environment (AWS Secrets Manager, Kubernetes secrets, etc.), never from a file baked into the image.

**Why:** Fake placeholders are an attractive nuisance — they get accidentally deployed, they get cargo-culted, they get committed. Empty defaults are unambiguous: a value is set or it isn't.

## 6. Strict backend layering

The backend pipeline is `routes → controllers → services → storage`. Only the storage layer writes data. Controllers do not contain business logic. Routes register only.

For projects in other stacks, the same shape applies under different names. The invariant is the layering, not the file extension.

**Why:** Without strict layering, every service grows into a god class with a SQL query in the controller, a business rule in the route, and three storage abstractions fighting each other. Strict layering refuses the gravitational pull of convenience.

## 7. ADR discipline

Every architectural decision lands in `docs/architecture/decisions/ADR-NNN-<slug>.md`. The ADR template requires Context, Decision, Alternatives considered, Consequences, and Cost implications. An `INDEX.md` lists all ADRs in numeric order with one-line summaries.

**Why:** Without ADRs, decisions decay into lore. Six months in, no one remembers why the schema chose this column type, and the next person changes it because the rationale was implicit. ADRs make the rationale explicit and durable.

## 8. Phase-gated delivery with explicit go-signal

Work is organized into numbered phases. Each phase has explicit exit criteria. No phase begins without the literal signal **"Proceed with Phase N."** Phase transitions update `CHANGELOG.md` and the `phase` field of `.ascent-meta.json`.

**Why:** Implicit phase transitions become explicit phase confusion. The go-signal protocol makes "are we done with X?" answerable in one word.

## 9. Label-based project scoping

Every container, image, network, and volume carries `--label project=<project-slug>`. Cleanup operations filter by label, never by name-string-matching. Multi-project developers can run cleanup on one project without disturbing the others.

**Why:** Name-matching cleanup is the source of "I just deleted my coworker's database" stories. Labels are precise, deliberate metadata that survive renaming and re-tagging.

## 10. Container engine compatibility

All Make targets use `$(ENGINE)`, which auto-detects Podman (preferred) and falls back to Docker. `ENGINE=docker make <target>` works identically. Targets that don't need an engine never call one.

**Why:** Tooling that hard-codes one engine becomes an obstacle when the team's engine choice evolves. Auto-detection plus explicit override is the cheapest possible flexibility.

## 11. Context-aware host/container execution

The runtime container sets `<PROJECT_SLUG_UPPER>_INSIDE_CONTAINER=1`. Targets that behave differently on host versus inside-container use this marker to degrade gracefully — `make test-all` on the host spawns a container; the same target inside the container runs the binary directly.

**Why:** Without context awareness, CI runners and validation scripts produce recursive container-spawning behavior or fail engine detection inside containers that don't have one.

## 12. Graceful shutdown

The application traps `SIGTERM` and drains in-flight work before exiting. The `make dev-down` target sends `SIGTERM` first with a 15-second grace period, then `SIGKILL`.

**Why:** Hard kills produce corrupted state, partial writes, and angry users. Graceful shutdown is one of those engineering invariants that costs little and pays back every time it matters.

## 13. `dev-status` morning-standup family

Every project ships `make dev-status` (full check, ~3-5s) and `make dev-status-quick` (fast subset, ~80ms). Every output row pairs with a deep-dive command. The "Next Actions" section adapts to detected state. The status command never fails — it reports state, it doesn't gate.

**Why:** "What state is my dev environment in?" is the most-asked question in a software project. Answering it with one command is the single largest quality-of-life improvement in daily work.

## 14. Persona-segmented documentation

The README and overall doc structure organize content by audience — Architects, Developers, Operators, Contributors, Learners. A given persona has a clear entry point and a clear navigation path. Documents are written for one primary audience, not for everyone simultaneously.

**Why:** Universal documentation is documentation no one reads. Persona-segmented documentation is documentation that finds its reader.

---

## How the principles relate to the framework

| Principle | Surfaces in |
|---|---|
| 1 — Containerization-first | Architect's Dockerfile templates; DevOps's production Dockerfiles; `.dockerignore`; absence of host-Node paths |
| 2 — Make as operator vocabulary | The `make/` directory; every skill's recommended invocation; runbook commands |
| 3 — SDLC-sectioned help | Parent Makefile's `help` target; section markers in `make/*.mk` |
| 4 — Stub-first naming | Every `make/*.mk` file ships final names; `[STUB]` prints with version-of-landing |
| 5 — `.env` discipline | `.env.example` template; `.gitignore` and `.dockerignore` enforcement; `qa-structure` checks |
| 6 — Strict backend layering | Developer role's reference modules; `ascent-adr-conformance` checks; ADR-002 in every project |
| 7 — ADR discipline | Architect's ADR template; `docs/architecture/decisions/INDEX.md`; `ascent-adr-conformance` skill |
| 8 — Phase-gated delivery | Delivery-lead's PHASE-PLAN; `.ascent-meta.json` phase field; `ascent-delivery-status` skill |
| 9 — Label-based scoping | Every container `--label project=<slug>`; `podman-clean-*` targets filter by label |
| 10 — Engine compatibility | `$(ENGINE)` auto-detect in parent Makefile; `ENGINE=docker` override documented |
| 11 — Context-aware execution | Dockerfile sets the `_INSIDE_CONTAINER` marker; `make/test.mk` branches on it |
| 12 — Graceful shutdown | Server stub includes SIGTERM handler; `dev-down` sends SIGTERM with grace period |
| 13 — `dev-status` family | `make/dev-status.mk`; row-by-row deep-dive commands; context-aware Next Actions |
| 14 — Persona-segmented docs | README's role-segmented tables; `ascent-persona-coverage` skill; doc-architecture reference |

## When a principle is broken

Two valid paths:

1. **Fix it.** The principle is the default for a reason. Fixing the violation is usually cheap.
2. **Supersede it.** If a project genuinely needs an exception, write a project-level ADR titled `ADR-NNN-supersede-principle-N` that explains:
   - Which principle is being broken
   - Why this project is an exception
   - What replaces the principle (if anything)
   - When the principle might be reinstated (if ever)

An ADR that supersedes a framework principle is a serious decision. It's also a legitimate one. The framework's authority is opinionated, not absolute.

The illegitimate path is to break a principle silently and hope no one notices. The `ascent-self-audit` skill exists to make silent violations loud.
