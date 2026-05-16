# ADR-006: Dual MIT/Apache-2.0 licensing

**Status:** Accepted
**Date:** <<SCAFFOLD_DATE>> (America/New_York)
**Decider:** <<BRAND>> · ASCENT v<<FRAMEWORK_VERSION>> baseline

## Context

<<PROJECT_TITLE>> needs a license. The choice affects three audiences: individual contributors (who want simplicity), corporate users (who want an explicit patent grant), and downstream consumers (who want maximum compatibility with their own license stack).

This project inherits the dual-licensing convention from the ASCENT framework that scaffolded it. The Rust ecosystem has battle-tested this pattern for over a decade; the legal interpretation is well-understood.

## Decision

<<PROJECT_TITLE>> is dual-licensed under **MIT OR Apache-2.0 at the user's option**.

Three files at the project root:

- `LICENSE` — statement of dual licensing
- `LICENSE-MIT` — the MIT license text
- `LICENSE-APACHE` — the Apache 2.0 license text

Contributions are dual-licensed by default (no CLA required). The convention: "Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in this work by you shall be dual-licensed as above."

## Alternatives considered

**MIT only.** Simpler and widely understood. Rejected because MIT lacks an explicit patent grant. Corporate users at organizations with patent-review processes may face friction adopting MIT-only software without a separate patent indemnity.

**Apache 2.0 only.** Has the patent grant. Rejected because Apache 2.0's notice-preservation requirements and NOTICE-file convention add friction for small projects. Also: some downstream consumers prefer MIT-only dependency stacks for license-stacking simplicity.

**GPL v3 (or AGPL).** Strong copyleft. Rejected because copyleft is incompatible with the project's intent to be embeddable in proprietary systems. ASCENT-scaffolded projects are owned by their authors; GPL would virally constrain downstream use.

## Consequences

**Easier:**

- Individual users pick MIT — the simplest, most permissive license they know
- Corporate users pick Apache 2.0 — they get the explicit patent grant their legal team requires
- No CLA overhead — the dual-license-by-contribution convention is the industry standard
- Downstream compatibility is maximal — the project can be consumed under either license tradition

**Harder:**

- Three license files at the root instead of one — minor cosmetic overhead
- Contributors must understand dual licensing — a one-paragraph explanation in CONTRIBUTING.md suffices

**Neutral:**

- The Rust ecosystem convention is legally tested and broadly understood by lawyers and developers alike

## Cost implications

**Time:** Negligible. Three files, already scaffolded.

**Complexity:** Marginally higher than a single-license model. Substantially lower than a CLA.

**Future flexibility:** Maximum. Dual MIT/Apache-2.0 has the broadest downstream compatibility of any common licensing choice.

**Money:** None.
