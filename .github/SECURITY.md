# Security Policy

## Supported versions

ASCENT is pre-1.0 (v0.4.x). Only the latest framework release, and the latest version of each `ascent-*` plugin, receive security fixes.

| Version | Supported |
|---|---|
| 0.4.x, latest release | ✓ |
| older releases | upgrade to the latest |

Once v1.0 ships, the support window will be defined explicitly: latest minor version plus the previous minor version receive security updates.

## Reporting a vulnerability

If you believe you've found a security issue in ASCENT, whether in the parent skill, template assets, scaffolded-project defaults or the scaffolding scripts, please report it privately.

**Preferred channel:** GitHub's [private vulnerability reporting](https://github.com/lloydbrian/lloydbriantech-ascent/security/advisories/new). This opens a confidential advisory visible only to maintainers.

**Alternative channel:** open a GitHub issue with the title `[SECURITY] (brief description)` and *no further detail*. A maintainer will reach out for the specifics through a private channel.

Please do not disclose the issue publicly until it has been addressed.

## What counts as a security issue

- Template assets that ship with insecure defaults (weak crypto, exposed credentials patterns, unsafe permission defaults)
- Scaffolding scripts that could be tricked into writing outside their intended directory
- Skill behavior that could exfiltrate or leak project content unintentionally
- Reference modules that recommend patterns now known to be insecure
- Plugin scripts, hooks or agents that can be made to write, run commands or reach the network when they are documented as read-only
- A way to get around the `ascent-delivery` operator-boundary hook, so Claude can commit, push, merge, tag or deploy while it is enabled
- A report that prints a secret value, an account id or contact details

## What doesn't count

- Vulnerabilities in dependencies of scaffolded projects (those are upstream issues; report them to the upstream maintainer)
- Choices users make in their own ASCENT-scaffolded projects (the framework provides defaults; users own their projects)
- Theoretical issues without a demonstrated impact (please show how it would be exploited)

## Response timeline

During alpha:

- Acknowledgement: within 5 business days
- Initial assessment: within 10 business days
- Fix or mitigation: target within 30 days, depending on severity

Post-v1.0 timelines will be tightened.

## Acknowledgement

Reporters who follow responsible disclosure will be credited in the relevant CHANGELOG entry unless they request otherwise.
