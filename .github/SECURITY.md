# Security Policy

## Supported versions

ASCENT is currently in alpha (v0.1.x). Only the latest released version receives security updates during the alpha phase.

| Version | Supported |
|---|---|
| 0.1.x (alpha) | ✓ |
| < 0.1 | n/a |

Once v1.0 ships, the support window will be defined explicitly: latest minor version plus the previous minor version receive security updates.

## Reporting a vulnerability

If you believe you've found a security issue in ASCENT — in the parent skill, in template assets, in scaffolded-project defaults, or in the scaffolding scripts — please report it privately.

**Preferred channel:** GitHub's [private vulnerability reporting](https://github.com/lloydbrian/lloydbriantech-ascent/security/advisories/new). This opens a confidential advisory visible only to maintainers.

**Alternative channel:** open a GitHub issue with the title `[SECURITY] (brief description)` and *no further detail*. A maintainer will reach out for the specifics through a private channel.

Please do not disclose the issue publicly until it has been addressed.

## What counts as a security issue

- Template assets that ship with insecure defaults (weak crypto, exposed credentials patterns, unsafe permission defaults)
- Scaffolding scripts that could be tricked into writing outside their intended directory
- Skill behavior that could exfiltrate or leak project content unintentionally
- Reference modules that recommend patterns now known to be insecure

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
