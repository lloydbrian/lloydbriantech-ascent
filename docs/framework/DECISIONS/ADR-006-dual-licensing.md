# ADR-006: Dual MIT OR Apache-2.0 license

**Status:** Accepted
**Date:** 2026-05-14 (America/New_York)
**Decider:** lloydbriantech

## Context

The framework needs a license. The license choice affects three constituencies:

**Individual users** want a license that's permissive, broadly understood, and doesn't impose obligations they need a lawyer to understand. The MIT license is the dominant choice in this segment for good reason.

**Corporate users** want a license that grants them an explicit patent license alongside the copyright permission. Without an explicit patent grant, a contributor could in principle sue users over patent claims the contribution embodies. The Apache 2.0 license includes the explicit patent grant; MIT does not.

**Contributors** want clarity about what license they're contributing under. They want patent reassurance for their own contributions. They want a license whose contribution model is well-understood and doesn't require a Contributor License Agreement (CLA).

A single license can't optimally serve all three. MIT is preferred by individual contributors and small projects but lacks the corporate patent grant. Apache 2.0 has the patent grant but is more verbose and has slightly stricter notice requirements. GPL family is unacceptable for many corporate environments and isn't appropriate for a framework intended to be embedded in projects the user owns.

There is a precedent for solving this — the Rust ecosystem has been dual-licensing under MIT OR Apache-2.0 for over a decade. Users pick the license they prefer; contributors agree to both via the convention "Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you shall be dual-licensed as above." This pattern is widely understood, legally tested, and works without a CLA.

## Decision

ASCENT is dual-licensed under **MIT OR Apache-2.0 at the user's option**. The license model exactly mirrors the Rust ecosystem convention:

- Three files at the repo root: `LICENSE` (statement of dual licensing), `LICENSE-MIT` (the MIT license text), `LICENSE-APACHE` (the Apache 2.0 license text)
- The `LICENSE` file explicitly states "Apache License, Version 2.0 OR MIT License, at your option"
- The `CONTRIBUTING.md` file states the contributor convention: contributions are dual-licensed unless the contributor explicitly states otherwise
- No CLA — the dual-license-by-contribution convention handles patent grant cleanly

The framework's `README.md`, `CONTRIBUTING.md`, and source headers (where applicable) all reference this dual license.

## Alternatives considered

**MIT only.** Simpler. Widely understood. Rejected because:

1. No explicit patent grant. Corporate users at telcos and large enterprises may have policies against using MIT-only software without a separate patent indemnity. The user's own employer (large telecom) is a representative example of an environment where Apache 2.0 is easier to clear with legal review.
2. Adopting MIT-only forecloses the option of attracting Apache-2.0-preferring contributors.

**Apache 2.0 only.** Has the patent grant. Rejected because:

1. Some downstream projects prefer MIT-only dependencies for license-stacking simplicity. Locking ASCENT to Apache 2.0 only would limit who can comfortably embed the framework's patterns.
2. The notice-preservation requirements in Apache 2.0 (the NOTICE file convention) add friction for small projects that don't otherwise need it.

**MPL 2.0.** Mozilla Public License 2.0 has file-level copyleft. Rejected because:

1. ASCENT's value is the *patterns it teaches*, not the code itself. File-level copyleft would chill the reuse of those patterns in proprietary projects.
2. Copyleft licenses are harder to clear in corporate environments than permissive licenses.

**GPL v3.** Strong copyleft. Rejected because:

1. Incompatible with the framework's intent. ASCENT scaffolds projects that the user owns and ships under their own license; GPL would virally affect those projects.
2. Effectively unusable in most corporate environments.

**Unlicense / 0BSD / public domain.** Maximally permissive. Rejected because:

1. No patent grant.
2. Some jurisdictions don't have a clean "public domain" concept, making rights ambiguous.
3. The marginal user-side simplicity over MIT is not worth the legal ambiguity.

**Custom license.** Rejected immediately. Custom licenses create legal uncertainty for every user and provide no benefit over the established options.

**No license at all.** "All rights reserved" by default. Rejected because:

1. Defeats the purpose of releasing the framework.
2. No-license projects are unusable in any context that requires explicit licensing — which is most professional contexts.

**Single license — the Anthropic Model Card Terms or similar AI-specific.** Rejected because ASCENT is a software framework, not an AI model; AI-specific licenses don't fit the artifact.

## Consequences

**Easier:**

- Individual users pick MIT, get the simplest license they know
- Corporate users pick Apache 2.0, get the patent grant their legal team requires
- Contributors agree to both via the contribution convention, no CLA needed
- The framework can be embedded comfortably in projects under either license tradition
- The pattern is legally tested through extensive use in the Rust ecosystem — judges, lawyers, and corporate counsel know how to interpret it

**Harder:**

- Three license files instead of one — minor cosmetic overhead
- Documentation must explain the dual-license model in `CONTRIBUTING.md` and `README.md`
- Some users won't be familiar with dual-licensing and will need to read the explanation

**Neutral:**

- Future relicensing would require contributor consent (same as any other change-of-license)
- Trademark on "ASCENT" or "lloydbriantech" is separate from the copyright license — handled if/when needed

## Cost implications

**Time:** Up-front cost: writing three license files (small). Ongoing cost: zero.

**Complexity:** Marginally higher than a single-license model. Substantially lower than the legal complexity of a CLA or custom license.

**Future flexibility:** Maximum. Dual MIT/Apache-2.0 has the broadest downstream compatibility of any common licensing choice. Any future change in scope (commercializing parts of the framework, building proprietary extensions, contributing patches to other projects) is unconstrained by this choice.

**Money:** None directly. Indirectly: the license model removes a hurdle to adoption in corporate environments, which matters for the author's stated goal of monetizing ASCENT expertise commercially. A framework that corporate engineers can adopt is one whose author can be hired to consult on.

## Note on precedent

The Rust convention this ADR adopts is documented at:

- The Rust language repository (`rust-lang/rust`) and most of its ecosystem
- The `tokio-rs/tokio` repository
- Most major Rust crates

ASCENT's dual-license statement is functionally identical to those. The pattern is mature and battle-tested.
