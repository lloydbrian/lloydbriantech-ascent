# Review lenses

Delivery-loop Step 4 runs one reviewer per lens, in parallel, against the diff and the acceptance criteria. For each lens, use the first provider in its list that is installed in this session, and the fallback prompt when none is. Detect providers from the skills and agents available in the session. Do not ask the operator, and do not install anything.

## Providers

| Lens | Providers, first installed wins | Fallback |
|---|---|---|
| Correctness | `engineering:code-review` | [Correctness](#correctness) |
| Security and privacy | `ascent-security:security-auditor` | [Security and privacy](#security-and-privacy) |
| Architecture and cost | `ascent-architecture:architecture-reviewer` | [Architecture and cost](#architecture-and-cost) |
| Accessibility | `ascent-ux:ux-reviewer`, `design:accessibility-review` | [Accessibility](#accessibility) |
| UX and navigation | `ascent-ux:ux-reviewer` | [UX and navigation](#ux-and-navigation) |
| Operational and deploy impact | `ascent-ops:ops-reviewer`, `engineering:deploy-checklist` | [Operational and deploy impact](#operational-and-deploy-impact) |
| Tests | `engineering:testing-strategy` | [Tests](#tests) |

The `ascent-*` providers are read-only agents from the ASCENT plugins; the others are skills. ASCENT's ownership registry (`docs/framework/OWNERSHIP.md` in the framework repository) owns this list, and its gate fails when this table drifts from it.

Run each lens as its own subagent, so the reviewers cannot see each other's findings. When a provider is a skill, the subagent's task is "apply `<skill>` to this diff". When it is an agent, launch that agent. When one agent provides two lenses (`ascent-ux:ux-reviewer` for accessibility and UX), launch it once, name both lenses in its task, and file each finding under the lens it belongs to.

**Wrap, don't rebuild.** Pass a provider's output through unedited, under this header:

```
#### <Lens> — via <provider>
<provider output, verbatim>
```

A fallback reviewer's output goes under `#### <Lens> — built-in fallback`. Then extract each finding into the shared format below for the verifier. Keep the provider's own wording in the description.

Skip a lens only when it cannot apply, and say why in one line (for example, "Accessibility — skipped: no user interface in this change").

## Finding format (every lens)

```
F<n>  <severity: Critical | High | Medium | Low>  <file>:<line>
      Lens: <lens>
      Finding: <what is wrong, one sentence>
      Scenario: <concrete inputs or state → wrong output, crash, leak or outage>
      Fix: <one line>
```

A finding without `file:line` and a concrete scenario is not a finding. Send it to the operator as a question instead.

## Fallback prompts

Give each fallback reviewer the diff, the acceptance criteria, its prompt, and the finding format. Each prompt starts with the same preamble:

> You are an independent reviewer with one lens. Read the diff and the files it touches. Report only problems you can tie to a specific `file:line`, each with a concrete failure scenario. Do not edit files, run git or deploy. Do not report style preferences. If you find nothing, say "no findings" and list what you checked.

### Correctness

> Lens: correctness. Check every acceptance criterion against the code. Look for wrong conditions and off-by-one errors; unhandled errors, nulls and empty inputs; races and ordering assumptions; and resources that are not released. Check that changed function contracts still hold for every caller (search for callers), and that behavior differs between environments (OS, locale, time zone) only where intended.

### Security and privacy

> Lens: security and privacy. Look for injection (SQL, shell, template, path), missing authorization checks, secrets or credentials in code, config or logs, and personal data written to logs, analytics or third parties. Check unsafe deserialization or `eval`; CORS, CSP and cookie flags on changed endpoints; dependency additions with known risk; and data retained longer than needed. Never quote a secret value. Cite the `file:line` and the pattern.

### Architecture and cost

> Lens: architecture and cost. Check that the change keeps the system's boundaries: no new coupling across layers or services, no business logic in handlers or templates, configuration from the environment rather than code. Look for new infrastructure or managed services without a recorded decision, resources without limits, timeouts or retries, single points of failure on a path that had none, and anything that changes the monthly running cost (new always-on resources, larger instances, data transfer, log volume) without saying by how much.

### Accessibility

> Lens: accessibility (WCAG 2.1 AA). For changed UI, check keyboard reachability and focus order, visible focus, labels and accessible names, and color contrast (4.5:1 for text). Check that errors are announced, not only colored; target sizes; motion and auto-play; and that headings and landmarks still make sense.

### UX and navigation

> Lens: UX and navigation. Walk the changed flows as a first-time user and as a returning user. Look for dead ends and lost state on back or refresh, and missing empty, loading and error states. Check that wording matches the rest of the product, that destructive actions have confirmation or undo, and that the behavior matches the option the operator chose in Step 1.

### Operational and deploy impact

> Lens: operational and deploy impact. Check migrations (reversible? locking? order relative to the code deploy?), config and environment variables the deploy needs, feature flags and their default, backward compatibility during a rolling deploy, logging and metrics for the new path, and what rollback leaves behind. Check that the runbook's dry run and build-stamp check would catch a wrong-stage or stale deploy.

### Tests

> Lens: tests. Map each acceptance criterion to a test, and list the criteria without one. Check that each new rule has a negative control that makes a named test fail. Look for tests that cannot fail (asserting on their own fixture, no assertion, platform-skip branches that pass), tests that grep documentation instead of exercising behavior, and flaky timing or ordering assumptions.

## After the reviewers

Give the full list of findings, from every lens, to the `ascent-delivery:finding-verifier` agent. Only findings it marks CONFIRMED go into the fix list without question. UNCONFIRMED findings go to the operator with a recommendation, and REJECTED findings are listed with the verifier's reason.
