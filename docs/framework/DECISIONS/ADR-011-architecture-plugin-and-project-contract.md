# ADR-011: Architecture plugin and the project contract file

**Status:** Proposed
**Date:** 2026-10-18 (America/New_York)
**Decider:** lloydbriantech

## Context

The plugin roadmap decided on 2026-10-18 ranks `ascent-architecture` first (decision 6). Most of the owner's projects are either technical or strongly user-facing, and none of the existing plugins helps a builder answer the questions that come before production:

- What is the system made of, and does it meet measurable quality targets (availability, latency, recovery, cost)?
- Does the code follow sound design principles (MVC or layering, SOLID, twelve-factor, API design)?
- Which deployment should we choose, what does it take to set up, and what will it cost to run each month?
- How close is the project to an enterprise-grade operating standard, and what is deliberately skipped?

Anthropic's `engineering:system-design` and `engineering:architecture` skills cover generic design and ADR writing. They do not know ASCENT's contract, maturity target or severity conventions, and they do not produce dated cost estimates or deployable blueprints.

Decision 2 put per-project configuration in one file with a section per plugin. ADR-009 deferred a contract file until a second plugin needed one, and ADR-010 created `.delivery-loop.yml` for the delivery loop alone. This plugin is the first that needs project targets, so it introduces the shared file.

## Decision

1. **A new plugin, `ascent-architecture` 0.1.0** (hand-written, decision B; ADR-010 part 2 allows hand-written plugin skills that have no template source). It contains:
   - four skills: `architecture-review` (entry point, hybrid pattern: surface checks, then deeper skills only where flagged), `quality-attributes`, `design-principles-check` and `deployment-options`. They are siblings: they share sources and never invoke each other;
   - a read-only `architecture-reviewer` agent (Read, Grep, Glob) that also serves as a delivery-loop review lens;
   - references: architecture principles (P1–P12, the six Well-Architected pillars, the Solutions Architect Professional lens, maturity targets), an AWS ↔ Azure ↔ Google Cloud component mapping, and the contract template.
2. **The project contract is `.ascent/contract.yml`** (decision A), or `.claude/contract.yml` where ASCENT-named files are not allowed. This plugin reads its `architecture:` section: maturity target, cloud, region, blueprint, IaC paths, quality targets, usage profile, ADR directory and waivers. When the file is missing, the review proposes it from the repository and the operator confirms and commits it (detect-don't-ask). `ascent-delivery` 0.2.0 will read a `delivery:` section in the same file and keep accepting `.delivery-loop.yml`.
3. **Enterprise is the default maturity target** (decision 10). A project may choose less, but every skipped item becomes a waiver: an ADR listed under `architecture.waivers`. A waived gap is reported as Info, and a waiver pointing at a missing ADR is a finding.
4. **Costs are estimated, dated and sourced** (decisions C and 9). A pricing file for the blueprint's AWS services in us-east-1, with an `as_of` date and a source URL per row, plus a CloudFront flat-rate plan file. `scripts/estimate-cost.sh` turns a usage profile into an itemized monthly estimate, shares free allowances that AWS pools across rows (Lambda arm64 and x86, CloudFront HTTP and HTTPS, CloudWatch Logs), compares the flat-rate plans while honoring the plan features the design needs (access logs, custom response headers), warns when prices are more than 90 days old, and stops on any unpriced or malformed usage line instead of dropping it. When web access is available, `deployment-options` checks the live AWS pages first and reports any difference. Every figure is labelled as an estimate with its date and source.
5. **One blueprint in 0.1.0: `static-site-serverless-aws`** (decision D). A CloudFormation template for a private S3 origin behind CloudFront with Origin Access Control and security headers, an HTTP API on Lambda (arm64, Node.js 24) with DynamoDB on demand, retained data, point-in-time recovery, log retention, throttling, an error alarm and a monthly budget. It passes `cfn-lint`, and the plugin test runs `cfn-lint` whenever it is installed. Its README carries the architecture, the cost estimate, setup and operating effort, an operator deploy runbook (change-set dry run first, personal values as shell variables), rollback and the gaps it leaves to waivers.
6. **Mechanical template checks.** `scripts/check-cfn-static-site.sh` runs 12 read-only checks (C1–C12) on CloudFormation YAML for this pattern: public access, Origin Access Control, HTTPS only, TLS policy, the CloudFront-only bucket policy, security headers, retention on delete, point-in-time recovery, log retention, API throttling, a budget and access logging. Checks are per resource (each S3 origin, each distribution, each Lambda function's log group). A check whose resources are absent is N/A, never PASS, and syntax it cannot read (flow-style resources) stops it with exit 2 instead of skipping a resource. Its severities are pinned in three places that a test keeps identical: the script header, the architecture-review mapping table and the script output. It is a guard rail for one pattern, not a replacement for `cfn-lint` or `cfn-guard`.
7. **Executable plugin code needs behavior tests.** `make test-plugins` T11 now covers plugins with `scripts/` as well as `hooks/`, and fails when any script is not named by a test. T5 also keeps every copy of the architecture severity table identical (the skill and the agent). The estimator is tested against hand-checkable fixtures and the shipped files; the checker is tested on the blueprint, on layout variants that must still pass, and on one broken copy per defect, which must fail that check and no other. Both run on every awk installed. Twenty-eight plugin controls (P30–P57) in `make test-mutants` must each fail on the check they name; P50–P57 pin the rules added after the read-only trial (decision E), which `test-skill-rules.sh` checks.
8. **Trial on tennis, read-only** (decision E). The first trial runs the agent and `architecture-review` on the tennis repository and produces a report only; no fixes.

## Alternatives considered

- **Generate the skills from template skills (ADR-009).** No template skill covers architecture review or deployment choice, so there is nothing to generate from. Writing template skills first would delay the plugin for content no scaffolded project asked for yet.
- **Wait for the scaffolder before introducing the contract file.** Rejected: the architecture review needs targets now, and a second interim file (`.architecture.yml`) would have to be migrated later.
- **Live prices only, no pricing file.** Rejected: reviews also run offline or where the AWS pages cannot be fetched, and a dated file makes estimates reproducible and testable.
- **A full pricing catalog for every AWS service.** Rejected for 0.1.0 (decision C): every row must be kept current. Rows are added with each new blueprint.
- **Terraform or CDK for the first blueprint.** CloudFormation needs no extra tooling, matches the tennis project, and the hook already knows its deploy commands. Terraform and CDK blueprints can follow.
- **`cfn-guard` rules instead of a bash checker.** Better long-term, but it needs a tool the operator may not have. The bash checker is portable and tested; `cfn-guard` rules are a candidate for 0.2.0.

## Consequences

- Builders get one command for an architecture review that names its evidence and its targets, and a deployment decision with numbers attached.
- The contract file becomes the shared home for plugin configuration. `ascent-delivery` 0.2.0 must follow it.
- The pricing file goes stale. The estimator's 90-day warning and the live check make that visible; refreshing it is a plugin change with a version bump (T10), which is the intended friction.
- The template checker reads YAML by indentation and treats any `Fn::If` branch as present. It can miss a defect in an unusual template, which is why it is documented as a guard rail and names `cfn-lint` and `cfn-guard`.
- Accessibility and UX remain out of scope until `ascent-ux`, and SRE runbooks, pre-flight and post-flight checks until `ascent-ops`.

## Cost implications

- One plugin of about 1,600 lines (skills, agent, references, blueprint, two scripts) and about 400 lines of tests. Twenty more controls add about two minutes to `make test-mutants`.
- Recurring: refresh the pricing file at least every 90 days or when AWS changes a price; review the blueprint when a Lambda runtime approaches end of support.
- The blueprint itself costs about 0.86 USD a month for a small site on pay-as-you-go, at prices as of 2026-10-18. CloudFront flat-rate plans do not pay off for it as written: its access logs and custom security headers need the Business plan (200 USD).
