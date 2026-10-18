# ascent-security

Read-only security checks for any repository. The checks cover `.env` discipline, hardcoded credentials, container privilege, nginx security headers and production URLs. This plugin is part of the [ASCENT framework](../../README.md), and you don't need an ASCENT project to use it.

| Component | Type | Use it when you ask |
|---|---|---|
| `env-audit` | skill | "check my .env", "audit environment variables", "any secrets committed?" |
| `security-audit` | skill | "what security issues exist?", "check security baseline", or before a deploy |
| `sec-posture` | skill | "what's our security stance?", "security overview" |
| `security-auditor` | agent (read-only) | an independent security review of a repo or change, e.g. from a delivery loop or PR review |

## Install

Claude Code CLI, or the Claude Code extension in VS Code:

```
/plugin marketplace add lloydbrian/lloydbriantech-ascent
/plugin install ascent-security@lloydbriantech-ascent
```

From a local clone, use the clone's path instead of `lloydbrian/lloydbriantech-ascent`.

Cowork: Customize → Plugins → Add marketplace → `lloydbrian/lloydbriantech-ascent`.

Skills are called as `/ascent-security:env-audit`, `/ascent-security:security-audit` and `/ascent-security:sec-posture`. Claude also loads them automatically when your request matches their description.

To turn the plugin on for everyone working in a repository, add it to that repository's `.claude/settings.json` under `enabledPlugins`.

## Privacy and safety

- The checks only read. The skills pre-approve Read, Grep and Glob (plus `git ls-files` and `git log` for `env-audit`), and their instructions never change files. Claude still asks before using any other tool.
- The agent's tools are limited to Read, Grep and Glob. It cannot edit files or run commands.
- Findings cite `file:line` and the rule name, never the matched value or line. Detection is pattern-based: it misses some secrets (short, split or binary) and can flag test fixtures, so confirm each finding.
- Fixes are given as advice in text. The skills and the agent never rotate keys, deploy or run git; the operator acts on findings.

## How this plugin is built

The three skills are **generated** by `make plugins` from the template skills in `skills/lloydbriantech-ascent/assets/template/.claude/skills/ascent-{env-audit,security-audit,sec-posture}`. To change a skill, edit that source and run `make plugins`. `make test-plugins` fails if a generated file has drifted from its source. The agent and the manifests are maintained by hand. See [ADR-009](../../docs/framework/DECISIONS/ADR-009-plugins-generated-from-template-skills.md).
