---
name: ascent-self-audit
description: >-
  Verifies that <<PROJECT_TITLE>> conforms to all 15 ASCENT invariants.
  The umbrella audit — delegates to ascent-layering-check, ascent-env-audit,
  and ascent-observability-check for their domains, then validates the
  remaining 12 invariants directly: containerization, make vocabulary,
  SDLC-sectioned help, stub-first naming, backend layering structure,
  ADR discipline, phase-gated delivery, label-based scoping, engine
  compatibility, context-aware execution, graceful shutdown, dev-status
  family, persona-segmented docs, and session resumption.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-self-audit

Comprehensive audit of <<PROJECT_TITLE>> against the 15 ASCENT framework invariants. This is the umbrella skill — it delegates to three focused component checks ([ascent-layering-check](../ascent-layering-check/SKILL.md), [ascent-env-audit](../ascent-env-audit/SKILL.md), [ascent-observability-check](../ascent-observability-check/SKILL.md)) for their domains, then validates the remaining 12 invariants directly. The result is a single N/15 report covering every architectural commitment.

## When this skill engages

- Before a commit or PR, to verify the project is still ASCENT-compliant
- When a developer suspects a convention has drifted
- As a periodic health check (recommended: weekly or per-phase)
- When onboarding a developer to confirm the project adheres to invariants
- After a significant refactor that may have broken structural conventions
- As a quality gate before phase transitions (per PHASE-PROTOCOL.md)

## Inputs

- **Project root directory** — reads files, checks structure, validates patterns across the entire project
- **Invocation mode** (optional) — full (all 15 invariants) or quick (structural checks only, skipping git-history and composition checks)
- No user input required for full mode — the audit is autonomous

## Outputs

- **Structured report** — each of the 15 invariants marked PASS or FAIL with specific detail
- **Per-FAIL detail** — the specific violation, the file/line if applicable, and the fix action
- **Summary line** — "N/15 invariants passing"
- **Exit code** — 0 if all pass, 1 if any fail

## Operational logic

The audit executes in two phases: delegation (Steps 1-3) and direct checks (Steps 4-15). Each step maps to one PRINCIPLES.md invariant. Step numbers are local to this skill.

### Phase A — Delegated checks (component skills)

### Step 1 — §6 Backend layering (delegate to ascent-layering-check)

**Condition:** Invoke [ascent-layering-check](../ascent-layering-check/SKILL.md) in component mode.

**Action on PASS:** Record §6 as PASS. Report "§6 Backend layering — PASS (via ascent-layering-check: M/M checks)."

**Action on FAIL:** Record §6 as FAIL. Report the component's violation summary. Example: "§6 Backend layering — FAIL (via ascent-layering-check: 4/6 checks, 2 violations). Run ascent-layering-check standalone for details."

### Step 2 — §5 Env discipline (delegate to ascent-env-audit)

**Condition:** Invoke [ascent-env-audit](../ascent-env-audit/SKILL.md) in component mode.

**Action on PASS:** Record §5 as PASS.

**Action on FAIL:** Record §5 as FAIL. Report the component's violation summary.

### Step 3 — Observability contract (delegate to ascent-observability-check)

**Condition:** Invoke [ascent-observability-check](../ascent-observability-check/SKILL.md) in component mode. This covers multiple principles: logging structure, healthcheck differentiation, lifecycle events, trace propagation.

**Action on PASS:** Record observability as PASS.

**Action on FAIL:** Record as FAIL. Report the component's violation summary.

### Phase B — Direct checks (remaining invariants)

### Step 4 — §1 Containerization-first

**Condition:** `backend/Dockerfile` exists. `docker-compose.yml` exists. At least one service in compose has `build: context:` pointing to a local directory.

**Action on PASS:** Report "§1 Containerization-first — PASS."

**Action on FAIL:** Report which artifact is missing. Example: "§1 FAIL: backend/Dockerfile not found — the development environment must be containerized."

### Step 5 — §2 Make as operator vocabulary

**Condition:** `Makefile` exists at project root. `make/` directory exists with at least one `.mk` file. `make help` is the default target (`.DEFAULT_GOAL := help`).

**Action on PASS:** Report "§2 Make as operator vocabulary — PASS."

**Action on FAIL:** Report what's missing. Example: "§2 FAIL: Makefile not found — every operation must have a make target."

### Step 6 — §3 SDLC-sectioned help

**Condition:** `make/help.sh` (or equivalent) exists. The help renderer parses `## SECTION:` annotations. At least 4 SDLC sections are defined.

**Action on PASS:** Report "§3 SDLC-sectioned help — PASS."

**Action on FAIL:** Report "§3 FAIL: help renderer not found or fewer than 4 sections defined."

### Step 7 — §4 Stub-first naming

**Condition:** Any make target that prints `[STUB]` exits with code 0 and uses the canonical format `[STUB] implement when <context>`.

**Action on PASS:** Report "§4 Stub-first naming — PASS (N stubs found, all conforming)."

**Action on FAIL:** Report non-conforming stubs. Example: "§4 FAIL: make/test.mk target test-unit prints '[TODO]' instead of '[STUB] implement when...'."

**Fallback:** If no stubs exist (all targets implemented), report PASS with "0 stubs found — all targets implemented."

### Step 8 — §7 ADR discipline

**Condition:** `docs/architecture/decisions/INDEX.md` exists. Every `ADR-NNN-*.md` file in the directory is listed in INDEX.md. Every listed ADR has the 5 required sections (Context, Decision, Alternatives, Consequences, Cost implications).

**Action on PASS:** Report "§7 ADR discipline — PASS (N ADRs, all conforming)."

**Action on FAIL:** Report each violation. Example: "§7 FAIL: ADR-003 missing Cost implications section."

### Step 9 — §8 Phase-gated delivery

**Condition:** `.ascent-meta.json` exists with a `phase` field. The phase value is non-empty.

**Action on PASS:** Report "§8 Phase-gated delivery — PASS (current phase: [phase value])."

**Action on FAIL:** Report "§8 FAIL: .ascent-meta.json missing or phase field empty."

### Step 10 — §9 Label-based scoping

**Condition:** Every service in `docker-compose.yml` has `labels: project: <<PROJECT_LABEL>>`. Networks and volumes also carry the label.

**Action on PASS:** Report "§9 Label-based scoping — PASS (all compose resources labeled)."

**Action on FAIL:** Report unlabeled resources. Example: "§9 FAIL: docker-compose.yml service 'nginx' missing project label."

### Step 11 — §10 Engine compatibility

**Condition:** `make/engine.mk` (or equivalent) exists. The `$(ENGINE)` variable is defined with auto-detection logic (Podman → Docker fallback).

**Action on PASS:** Report "§10 Engine compatibility — PASS."

**Action on FAIL:** Report "§10 FAIL: engine detection not found — make targets must use $(ENGINE) for Podman/Docker compatibility."

### Step 12 — §11 Context-aware execution

**Condition:** At least one Dockerfile sets an `_INSIDE_CONTAINER` environment variable (matching the project's slug-derived marker).

**Action on PASS:** Report "§11 Context-aware execution — PASS."

**Action on FAIL:** Report "§11 FAIL: no INSIDE_CONTAINER marker found in any Dockerfile."

### Step 13 — §12 Graceful shutdown

**Condition:** `backend/server.js` (or equivalent) contains a SIGTERM handler that logs a draining event and closes the server with a timeout.

**Action on PASS:** Report "§12 Graceful shutdown — PASS."

**Action on FAIL:** Report "§12 FAIL: no SIGTERM handler found in server.js — the application must trap SIGTERM and drain in-flight work."

### Step 14 — §13 dev-status family

**Condition:** `make/dev-status.mk` exists. It defines both `dev-status` (full check) and `dev-status-quick` (fast subset) targets.

**Action on PASS:** Report "§13 dev-status family — PASS."

**Action on FAIL:** Report which target is missing.

### Step 15 — §14 Persona-segmented docs

**Condition:** `README.md` contains a persona section or links to `audience-mapping.md`.

**Action on PASS:** Report "§14 Persona-segmented docs — PASS."

**Action on FAIL:** Report "§14 FAIL: README has no persona section or audience-mapping link."

### Step 16 — §15 Session resumption

**Condition:** `docs/delivery/working-memory.md` exists (git-tracked). `docs/delivery/session-state.md` is referenced in `.gitignore`. `CLAUDE.md` contains "Session resumption protocol" section.

**Action on PASS:** Report "§15 Session resumption — PASS."

**Action on FAIL:** Report each missing element. Example: "§15 FAIL: working-memory.md not found — session state artifacts missing." Or: "§15 FAIL: CLAUDE.md missing 'Session resumption protocol' section."

### Step 17 — Aggregate and report

Collect all PASS/FAIL results from Steps 1-16. Report summary: "15/15 invariants passing" or "12/15 invariants passing (3 violations found)."

List each result with its principle number for traceability. Each principle maps to exactly one step — no ambiguity in the N/15 count.

## Examples

### Example 1 — Fully compliant project

**Input state:** A freshly scaffolded project from ASCENT v0.3.1 with no modifications.

**Skill output:**
```
ascent-self-audit: 15/15 invariants passing
  §1  Containerization-first          PASS
  §2  Make as operator vocabulary     PASS
  §3  SDLC-sectioned help            PASS
  §4  Stub-first naming              PASS (17 stubs, all conforming)
  §5  Env discipline                  PASS (via ascent-env-audit: 7/7)
  §6  Backend layering                PASS (via ascent-layering-check: 6/6)
  §7  ADR discipline                  PASS (7 ADRs, all conforming)
  §8  Phase-gated delivery            PASS (phase: 0-foundation)
  §9  Label-based scoping             PASS (all compose resources labeled)
  §10 Engine compatibility            PASS
  §11 Context-aware execution         PASS
  §12 Graceful shutdown               PASS
  §13 dev-status family               PASS
  §14 Persona-segmented docs          PASS
  §15 Session resumption              PASS
```

### Example 2 — Dockerfile removed (§1 violation)

**Input state:** Developer deleted `backend/Dockerfile` during a cleanup.

**Skill output:**
```
ascent-self-audit: 14/15 invariants passing (1 violation)
  §1  Containerization-first          FAIL
    → backend/Dockerfile not found — the development environment must be containerized
  §2  Make as operator vocabulary     PASS
  ...
```

### Example 3 — Multiple violations across domains

**Input state:** `.env.example` has `REPLACE_ME` values, a route imports storage directly, and SIGTERM handler is missing.

**Skill output:**
```
ascent-self-audit: 12/15 invariants passing (3 violations)
  ...
  §5  Env discipline                  FAIL (via ascent-env-audit: 5/7)
    → Run ascent-env-audit standalone for details
  §6  Backend layering                FAIL (via ascent-layering-check: 5/6)
    → Run ascent-layering-check standalone for details
  ...
  §12 Graceful shutdown               FAIL
    → No SIGTERM handler found in server.js
  ...
```

### Example 4 — Partial project (early development)

**Input state:** Project has Makefile, docker-compose, backend with server.js, but no ADRs, no frontend, no persona docs.

**Skill output:**
```
ascent-self-audit: 10/15 invariants passing (5 not yet implemented)
  ...
  §7  ADR discipline                  FAIL (docs/architecture/decisions/INDEX.md not found)
  §14 Persona-segmented docs          FAIL (README has no persona section)
  §15 Session resumption              FAIL (working-memory.md not found)
  ...
```

## Anti-patterns

### Anti-pattern 1 — Running self-audit only at release time

By then, violations have accumulated and the fix-list is overwhelming. **Why it's tempting:** the audit takes a few seconds; running it feels like overhead during active development. **What to do instead:** run per-commit (via pre-commit hook or CI). Each violation is a one-line fix when caught immediately; it's an architectural rescue when caught at release.

### Anti-pattern 2 — Suppressing failures without ADRs

Marking a principle as "not applicable" to make the audit pass. **Why it's tempting:** the team doesn't use ADRs (or doesn't do phase-gated delivery, etc.) and doesn't want to see the FAIL. **What to do instead:** write `ADR-NNN-supersede-principle-N` explaining the override. The principle then reports SUPERSEDED instead of FAIL — the decision is tracked, not suppressed.

### Anti-pattern 3 — Trusting the component results without understanding them

Seeing "§6 Backend layering — PASS (via ascent-layering-check: 6/6)" and moving on without understanding what the 6 checks are. **Why it's tempting:** the umbrella summary looks green. **What to do instead:** periodically run the component skills standalone to understand what they check. The umbrella is for efficiency; the components are for education.

### Anti-pattern 4 — Over-relying on structural checks

The audit checks structural properties (file existence, import patterns, configuration shapes). It does not verify runtime behavior. A /healthz endpoint that exists but crashes on every request passes the structural check. **What to do instead:** complement the audit with runtime tests (`make test-all`). The audit catches convention drift; tests catch behavioral bugs.

### Anti-pattern 5 — Treating partial-project FAILs as bugs

A project in early development that hasn't created ADRs yet will FAIL §7. This isn't a bug — it's an accurate report of what's not yet done. **What to do instead:** use the audit as a checklist during development. The 15-item report IS the todo list of what the project needs before it's structurally complete.
