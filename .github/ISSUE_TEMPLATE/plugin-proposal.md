---
name: Plugin proposal
about: Propose a new ascent-* Claude Code plugin, or a new skill, check or rule in an existing one
title: '[plugin] '
labels: ['enhancement', 'new-plugin']
assignees: ['lloydbrian']
---

## Type

- [ ] New plugin (`ascent-<name>`), which needs an ADR
- [ ] New skill or agent in an existing plugin
- [ ] New check or rule in an existing plugin's scripts or severity table

**Plugin:** `ascent-_________`

## Problem this solves

What does a reviewer miss today, in any repository? Name the gap in one or two sentences.

"Better reliability" is not a problem; "no check notices a deploy script that has no rollback" is.

## Who asks for it

The phrases someone would type to Claude to trigger it ("is this operable?", "check our design tokens"). These become the skill's trigger description.

## Evidence it would produce

What does a finding look like? Every ASCENT finding has a `file:line` (or the paths searched when something is absent), a severity from the plugin's table, a failure scenario and a fix.

| Finding | Severity | Evidence |
|---|---|---|
| | | |

## Contract targets

Which measurable targets would it read from `.ascent/contract.yml`, and what are the defaults at the enterprise, standard and prototype maturity targets?

## Overlap

Which existing plugins or embedded skills cover part of this? Where is the line drawn (sibling pattern: read the same sources, never invoke each other)?

## Real repositories to trial it on

Plugins are trialled read-only on real repositories before release. Which kinds of repository would show whether it works?

## Delivery bar

A plugin ships only after it clears the bar in [CONTRIBUTING.md](https://github.com/lloydbrian/lloydbriantech-ascent/blob/main/CONTRIBUTING.md#contributing-a-plugin): hardened source, behavior tests, negative controls, the plugin gate with its version check, a real-repository trial and a release record.

---

*Before submitting, please confirm:*

- [ ] I've read the plugin table in the [README](https://github.com/lloydbrian/lloydbriantech-ascent/blob/main/README.md#plugins-for-any-repository) and checked for overlap
- [ ] The proposal keeps the plugin read-only by default, and Claude never commits or deploys for the user
- [ ] No credentials, account ids or personal data appear in this issue
