---
name: ascent-dependency-health
description: >-
  Validates dependency discipline for <<PROJECT_TITLE>> via static
  package.json analysis. Checks pinned versions, engine constraints,
  framework traceability, and unused dependencies — offline-capable,
  no network required.
version: <<PROJECT_VERSION>>
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
---

# ascent-dependency-health

Validates dependency discipline through static `package.json` analysis. ASCENT scaffolds pin every dependency to an exact version (`"express": "4.21.2"`, not `"^4.21.2"`) because version ranges introduce non-deterministic builds. This skill catches unpinned versions, missing engine constraints, broken traceability, and unused dependencies — all without network access.

For runtime vulnerability scanning (`npm audit`, CVE matching, SBOM generation), see the v0.4.x hardening roadmap. This skill covers the offline-verifiable discipline checks.

## When this skill engages

- After adding or updating dependencies
- Before a release to verify dependency hygiene
- When onboarding to verify the project follows ASCENT dependency conventions
- When debugging build reproducibility issues

## Inputs

- **`backend/package.json`** — dependency declarations (required)
- **`frontend/package.json`** — frontend dependency declarations (optional; checked if present)
- **`backend/` source files** — for cross-referencing actual imports against declared dependencies

## Outputs

- **Per-check report** — each check marked PASS or FAIL with specific findings
- **Summary line** — "dependency-health: N/4 checks passing"

## Operational logic

The skill executes these steps in order. Step numbers are local to this skill.

### Step 1 — Pinned versions

**Condition:** Every dependency in `dependencies` and `devDependencies` uses an exact version (no `^`, `~`, `>=`, `*`, or `latest` prefixes).

**Action on PASS:** Report "Pinned versions — PASS. N dependencies, all exact."

**Action on FAIL:** List each unpinned dependency. Example: "Pinned versions — FAIL. `lodash: ^4.17.21` uses a range — pin to `4.17.21`."

### Step 2 — Engine constraints

**Condition:** `package.json` has an `engines` field specifying a Node.js version constraint (per Principle §10 engine compatibility).

**Action on PASS:** Report "Engine constraints — PASS. Node `>=NN.0.0` declared."

**Action on FAIL:** Report "Engine constraints — FAIL. No `engines` field in package.json. Without this, the project may run on an incompatible Node version."

### Step 3 — Framework traceability

**Condition:** `package.json` has an `ascent_framework_version` field matching the framework version that scaffolded it.

**Action on PASS:** Report "Framework traceability — PASS. ascent_framework_version: `<<FRAMEWORK_VERSION>>`."

**Action on FAIL:** Report "Framework traceability — FAIL. No `ascent_framework_version` field. This field traces the project back to the ASCENT version that generated it."

### Step 4 — Unused dependencies

**Condition:** Every package listed in `dependencies` (not `devDependencies`) is imported by at least one source file in the corresponding source tree (`backend/` or `frontend/`).

Detection: for each dependency name, search for `import ... from '<name>'` or `require('<name>')` patterns across source files. A dependency with zero matches is potentially unused.

**Action on PASS:** Report "Unused dependencies — PASS. All N dependencies have at least one import."

**Action on FAIL:** List each potentially unused dependency. Example: "Unused dependencies — WARNING. `uuid` is declared in package.json but no source file imports it. Verify or remove."

**Note:** This check uses WARNING (not FAIL) because some dependencies are used indirectly (e.g., `better-sqlite3` native bindings loaded by the runtime). False positives are possible; the developer should verify.

## Examples

### Example 1 — Healthy package.json

**Skill output:**
```
ascent-dependency-health: 4/4 checks passing
  Pinned versions          PASS (6 dependencies, all exact)
  Engine constraints       PASS (Node >=22.0.0)
  Framework traceability   PASS (ascent_framework_version: 0.3.1)
  Unused dependencies      PASS (all 5 production deps imported)
```

### Example 2 — Unpinned dependency

**Skill output:**
```
ascent-dependency-health: 3/4 checks passing (1 failure)
  Pinned versions          FAIL
    → lodash: ^4.17.21 uses a range — pin to 4.17.21
    → axios: ~1.6.0 uses a range — pin to 1.6.0
  Engine constraints       PASS
  Framework traceability   PASS
  Unused dependencies      PASS
```

## Anti-patterns

### Anti-pattern 1 — Trusting version ranges for reproducibility

Using `^` or `~` prefixes because "npm shrinkwrap handles it." **Why it's tempting:** ranges auto-update patches. **What to do instead:** pin exact versions. Update deliberately via `npm update <pkg>` + test + commit. Shrinkwrap/lockfiles are a second defense, not a substitute for intentional version management.
