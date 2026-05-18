---
name: ascent-feature-intake
description: >-
  Runs the delivery-lead intake protocol for new features in
  <<PROJECT_TITLE>>: decomposes a request into acceptance criteria,
  identifies cross-role dependencies, estimates scope, and records the
  feature in the project's PHASE-PLAN. Per §15, appends locked
  acceptance criteria as dated entries to working-memory.md.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Write
---

# ascent-feature-intake

Structures a new feature request into the delivery-lead's intake format: concrete acceptance criteria, scope estimate, cross-role dependencies, and a PHASE-PLAN entry. This is Stage 1 of the feature lifecycle — the point where vague requests become testable commitments. Per §15 (session resumption), when acceptance criteria are locked, the skill appends them as dated entries to `docs/delivery/working-memory.md` so feature decisions persist across sessions.

## When this skill engages

- When a stakeholder or developer describes a new feature they want
- When explicitly asked to "intake this feature" or "add this to the phase plan"
- At the start of a new phase, when features are being scoped
- When a feature request arrives via GitHub issue, conversation, or stakeholder meeting
- When re-scoping an existing feature mid-phase (criteria refinement)
- NOT for bug fixes (those skip intake and go directly to developer)

## Inputs

- **Feature request** — can be conversational, vague, or well-structured. The skill extracts structure from any form.
- **Current phase context** — from `.ascent-meta.json` (which phase are we in?)
- **Existing PHASE-PLAN.md** (optional) — if features are already scoped, the new feature adds to them
- **Priority or deadline constraints** (optional) — from the stakeholder
- **`docs/delivery/working-memory.md`** — existing decisions per §15 (four-state classified; used to avoid re-litigating prior decisions)

## Outputs

- **Structured intake artifact** with:
  - One-sentence feature description
  - Acceptance criteria (concrete and verifiable — each must be testable)
  - Estimated scope (small/medium/large relative to prior features)
  - Cross-role dependencies (which roles engage per feature-lifecycle Stage 2 triggers)
- **PHASE-PLAN.md entry** — the feature added as a checkbox item with its criteria
- **working-memory.md append** — per §15, dated entries under `## Decisions` recording the locked criteria

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Read current phase context

**Condition:** `.ascent-meta.json` exists with a `phase` field.

**Action on PASS:** Extract current phase. This determines where the feature lands (current phase or next phase). Report "Current phase: [phase]. New features intake for: [same phase or next, based on gate status]."

**Action on FAIL:** Report "No .ascent-meta.json — cannot determine current phase. Proceeding with feature intake without phase context."

### Step 2 — Read existing working-memory.md per §15

**Condition:** Check `docs/delivery/working-memory.md` for existence and content.

**Action on FRESH or STALE:** Read existing decisions to understand what's already been decided. This prevents the intake from re-litigating resolved questions. Report: "Working memory loaded — [N] prior decisions on record."

**Action on EMPTY or MISSING:** Proceed without prior-decision context. Note: "No working memory — this may be the project's first feature intake."

### Step 3 — Extract feature description from the request

**Condition:** The user has provided a feature request (in any form).

**Action:** Distill the request into a one-sentence feature description. The sentence must name the user-facing outcome, not the implementation. "Users can log in with email and password" — not "Add JWT auth endpoint."

**Fallback:** If the request is too vague to produce a feature description (e.g., "make it better"), ask a clarifying question: "What specific user outcome does this feature produce?"

### Step 4 — Decompose into acceptance criteria

**Condition:** Feature description from Step 3 is available.

**Action:** Produce 3-7 acceptance criteria. Each criterion must pass the testability check:

- **Concrete:** names a specific observable behavior, not a quality ("the dashboard loads" vs "the app is fast")
- **Verifiable:** can be confirmed by a test, a curl command, or a visual inspection
- **Scoped:** doesn't require the entire feature to be done to verify (each criterion is independently checkable)

For each proposed criterion, mentally apply the testability check: "How would you verify this? What does 'works' look like concretely?" If the answer is vague, refine the criterion.

**Inline example:** "Users can log in" → decomposed to: (1) "User with valid credentials sees the dashboard within 2 seconds" (2) "Invalid credentials show error message 'Invalid email or password'" (3) "Failed attempts are rate-limited to 5/minute per IP" (4) "Session token expires after 24 hours of inactivity."

### Step 5 — Testability gate

**Condition:** All criteria from Step 4 are proposed.

**Action:** Review each criterion against the testability standard. Reject any criterion that:
- Uses subjective language ("should work well", "is fast enough", "looks good")
- Depends on another criterion being met first (criteria must be independently verifiable)
- Is unmeasurable ("users are happy", "performance is acceptable")

For each rejected criterion, propose a concrete replacement. Example: "is fast enough" → "p95 response time under 200ms measured by `http_request_duration_seconds` histogram."

### Step 6 — Identify cross-role dependencies

**Condition:** Criteria are testability-gated.

**Action:** For each criterion, identify which roles engage per the feature-lifecycle Stage 2 trigger table:
- Schema or query change → data-engineer
- Auth, secrets, or egress → cybersecurity
- Customer-facing surface → ui-ux-designer
- AI prompt or eval → ai-engineer
- Infra or deploy change → devops

Report: "This feature engages [N] roles: [list]. The architect should review the design before implementation begins."

### Step 7 — Estimate scope

**Action:** Relative to prior features in the project (from PHASE-PLAN.md if available, or from working-memory.md decisions), estimate:
- **Small:** 1-2 day implementation, single-role, no architectural decisions needed
- **Medium:** 3-5 day implementation, 2-3 roles, may need an ADR
- **Large:** 1-2 week implementation, 4+ roles, requires an ADR and possibly a design review

Report the estimate with brief rationale.

### Step 8 — Write to PHASE-PLAN.md

**Condition:** Criteria are locked (user confirms the decomposition).

**Action:** Append to `docs/delivery/PHASE-PLAN.md` (create if it doesn't exist):

```markdown
### Feature: [one-sentence description]

- [ ] [Criterion 1]
- [ ] [Criterion 2]
- [ ] [Criterion 3]

**Scope:** [small/medium/large] · **Roles:** [role list] · **Intake date:** [YYYY-MM-DD]
```

### Step 9 — Append to working-memory.md per §15

**Condition:** Criteria are locked and PHASE-PLAN.md is written.

**Action:** Append dated entries under `## Decisions` in `docs/delivery/working-memory.md`:

```markdown
- YYYY-MM-DD: Feature "[description]" accepted with N criteria (see PHASE-PLAN.md)
```

If the intake involved deciding between alternatives (e.g., "chose email+password over OAuth-only"), append that as a separate decision entry.

**Four-state handling for working-memory.md:**
- FRESH or STALE: append below existing entries
- EMPTY: add the entry as the first item under `## Decisions`
- MISSING: create the file with the standard structure (title + three section headers) then append

### Step 10 — Confirm and summarize

**Action:** Present the completed intake to the user:
- Feature description
- Acceptance criteria (numbered, with testability confirmed)
- Cross-role dependencies
- Scope estimate
- PHASE-PLAN.md entry written
- working-memory.md updated

Ask: "Confirm this intake is complete, or refine any criteria before proceeding."

## Examples

### Example 1 — Well-formed request

**Input:** "We need user authentication — login with email and password."

**Skill output:**
```
Feature intake — <<PROJECT_TITLE>>

Feature: Users can authenticate via email and password

Acceptance criteria:
  1. User with valid credentials sees the dashboard within 2 seconds
  2. Invalid credentials show error "Invalid email or password"
  3. Failed login attempts rate-limited to 5/minute per IP
  4. Session token expires after 24 hours of inactivity

Scope: medium (3-5 days, multi-role)
Roles: architect (design), developer (implement), tester (validate), cybersecurity (auth review)

Written to docs/delivery/PHASE-PLAN.md
Appended to docs/delivery/working-memory.md:
  - 2026-05-18: Feature "user authentication" accepted with 4 criteria (see PHASE-PLAN.md)
```

### Example 2 — Vague request requiring decomposition

**Input:** "Make the app faster."

**Skill output:**
```
Clarification needed: "faster" is ambiguous.

Options:
  A. Lower latency — reduce p95 response time on specific routes
  B. Higher throughput — handle more concurrent requests
  C. Both A and B

Which interpretation matches the stakeholder's intent? And on which routes?
```

After clarification ("lower latency on the /api/items endpoint"):

```
Feature: /api/items endpoint responds within 200ms at p95

Acceptance criteria:
  1. GET /api/items p95 latency under 200ms (measured by http_request_duration_seconds)
  2. POST /api/items p95 latency under 300ms
  3. Latency regression test added to test-integration suite

Scope: small (1-2 days, developer + tester)
```

### Example 3 — Request with untestable criteria (rejected and refined)

**Input:** "Add a dashboard that looks professional."

**Skill output:**
```
Criterion rejected: "looks professional" is subjective and untestable.
Refined criteria:
  1. Dashboard renders the items list with name and creation date
  2. Dashboard uses the project's design-system tokens (colors, typography, spacing)
  3. Dashboard is keyboard-navigable (tab order follows visual order)
  4. Dashboard renders correctly at 320px, 768px, and 1440px viewport widths

"Professional" decomposed into: design-system compliance, accessibility, and responsive layout.
```

### Example 4 — First feature in a new project (no PHASE-PLAN)

**Input:** "We need to display a list of items."

**Skill output:**
```
Feature intake — <<PROJECT_TITLE>>

No existing PHASE-PLAN.md — creating docs/delivery/PHASE-PLAN.md.

Feature: Display a list of items on the main page

Acceptance criteria:
  1. GET /api/items returns JSON array of items
  2. Frontend renders item names in a list
  3. Empty state shows "No items yet. Add one above."

Scope: small (already implemented in scaffold — verify and customize)
Roles: developer (verify scaffold implementation)

Created docs/delivery/PHASE-PLAN.md with initial feature
Appended to docs/delivery/working-memory.md:
  - 2026-05-18: Feature "display items list" accepted with 3 criteria (see PHASE-PLAN.md)
```

## Anti-patterns

### Anti-pattern 1 — Accepting vague acceptance criteria

"Login should work" passes through without decomposition into testable conditions. **Why it's tempting:** the developer "knows what 'works' means." **What to do instead:** the skill must push back on every criterion that fails the testability check. "How would you verify this? What does 'works' look like concretely?"

### Anti-pattern 2 — Skipping the testability gate

Accepting criteria like "the UI is intuitive" or "performance is acceptable" because refining them feels pedantic. **Why it's tempting:** subjective criteria feel meaningful. **What to do instead:** decompose subjective qualities into observable behaviors. "Intuitive" → specific interaction patterns. "Acceptable" → specific latency thresholds.

### Anti-pattern 3 — Feature intake without recording in PHASE-PLAN

Discussing a feature, agreeing on criteria verbally, then moving to implementation without writing to PHASE-PLAN.md. **Why it's tempting:** the conversation was productive; writing it down feels redundant. **What to do instead:** the written artifact IS the intake. Without it, delivery-status can't track progress and the criteria drift.

### Anti-pattern 4 — Not appending to working-memory.md

Locking criteria but not recording them in working-memory.md. **Why it's tempting:** the criteria are in PHASE-PLAN.md already. **What to do instead:** working-memory.md records the DECISION to accept these criteria (not the criteria themselves). This distinction matters for session resumption — the next session knows a feature was accepted without re-parsing PHASE-PLAN.md.

### Anti-pattern 5 — Treating scope estimates as commitments

The scope estimate (small/medium/large) is a rough sizing for planning, not a delivery commitment. **Why it's tempting:** stakeholders hear "medium = 3-5 days" as a promise. **What to do instead:** present scope as relative sizing. "This feature is about the same size as [prior feature], which took [N] days."
