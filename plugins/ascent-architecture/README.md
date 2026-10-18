# ascent-architecture

Architecture review for any repository, judged against the project's own targets. It helps a builder answer four questions before production: what the system is, whether it meets its quality targets, whether the code follows sound design principles, and which deployment to choose, with what setup effort and what monthly cost.

It is part of the [ASCENT framework](../../README.md), and you don't need an ASCENT project to use it.

| Component | Type | What it does |
|---|---|---|
| `architecture-review` | skill | Entry point. Maps the system, runs surface checks (quality attributes, design principles, deployment and cost, maturity gaps), rates findings, and recommends the deeper skills only where needed. |
| `quality-attributes` | skill | Turns the "-ilities" into measurable targets in the contract and scores each as met, at risk or unmeasured, with evidence. |
| `design-principles-check` | skill | Detects the style (MVC, layered, hexagonal, serverless, static) and checks separation of concerns, coupling, SOLID, twelve-factor and API design. |
| `deployment-options` | skill | Compares deployment options by setup effort, dated monthly cost, operations burden and maturity fit; drafts the ADR; hands over a blueprint. |
| `architecture-reviewer` | agent (read-only) | An independent review in a separate context, also usable as a delivery-loop review lens. |
| `static-site-serverless-aws` | blueprint | CloudFormation for S3 + CloudFront (Origin Access Control, security headers) + HTTP API + Lambda + DynamoDB, with retention, throttling, alarm and budget. Passes all 12 template checks. |
| `estimate-cost.sh` | script | Monthly estimate from a dated pricing file and a usage profile; compares CloudFront flat-rate plans; warns when prices are over 90 days old. |
| `check-cfn-static-site.sh` | script | 12 read-only checks (C1–C12) on a CloudFormation YAML template for the static-site pattern. |
| `architecture-principles.md`, `cloud-component-mapping.md`, `contract-template.yml` | references | Principles P1–P12, Well-Architected pillars, Solutions Architect Professional lens, maturity targets; AWS ↔ Azure ↔ Google Cloud mapping; the `architecture:` section of `.ascent/contract.yml`. |

## Install

Claude Code CLI, or the Claude Code extension in VS Code:

```
/plugin marketplace add lloydbrian/lloydbriantech-ascent
/plugin install ascent-architecture@lloydbriantech-ascent
```

Cowork: Customize → Plugins → Add marketplace → `lloydbrian/lloydbriantech-ascent`, then install `ascent-architecture`.

Start with `/ascent-architecture:architecture-review`, or ask "review the architecture". For an independent pass: "Use the ascent-architecture:architecture-reviewer agent to review this repository."

## The project contract

Targets live in `.ascent/contract.yml` under `architecture:` (or `.claude/contract.yml` where ASCENT-named files are not allowed). If the file is missing, the review proposes one from what the repository declares and asks you to confirm it; you commit it. See [contract-template.yml](references/contract-template.yml). The same file will carry a `delivery:` section for `ascent-delivery` 0.2.0.

Every project defaults to the **enterprise** maturity target. Choosing less is fine, but each skipped item becomes a waiver recorded in an ADR.

## Cost estimates

Prices come from [pricing/aws-us-east-1.tsv](pricing/aws-us-east-1.tsv) (AWS us-east-1 list prices for the blueprint's services, dated) and [pricing/aws-cloudfront-flat-rate.tsv](pricing/aws-cloudfront-flat-rate.tsv). When web access is available, `deployment-options` checks the live AWS pages first and says when the file needs a refresh. Every number is labelled with its date and source, and is an estimate, not a quote.

## Boundaries

- Read-only: the skills and the agent never edit files, call cloud APIs or deploy. The scripts only read files.
- Deploys are the operator's, from a runbook. With `ascent-delivery` enabled, its hook blocks deploy commands for Claude.
- Credentials, account ids and email addresses never go into templates, contracts, reports or chat; runbooks declare them as shell variables at run time.
- Security scanning depth is `ascent-security`'s job; accessibility and UX are `ascent-ux` (planned).

## Tests

`make test-plugins` runs `tests/plugins/ascent-architecture/`: the estimator against hand-checkable fixtures and the shipped pricing files, and the template checker against the blueprint plus one broken copy per check, on every awk installed. `make test-mutants` adds negative controls that must each make a named check fail.
