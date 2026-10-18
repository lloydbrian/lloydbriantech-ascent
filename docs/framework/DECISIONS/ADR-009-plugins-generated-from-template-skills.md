# ADR-009: Plugins generated from the template skills

**Status:** Proposed
**Date:** 2026-10-17 (America/New_York)
**Decider:** lloydbriantech

## Context

The October 2026 audit found that 20 of the 28 embedded skills are useful outside a scaffolded ASCENT project. They work as-is or once their paths are detected rather than hard-coded. Until now the only way to get them was to scaffold a project, which requires the containers, stack and layout an existing repository rarely has.

Claude Code, its VS Code extension and Cowork all install **plugins**: a folder with `.claude-plugin/plugin.json` containing skills, agents and hooks, listed in a `marketplace.json`. A plugin is the natural way to ship these skills to any repository.

Copying the skills into a plugin would break architecture rule 1 in `CLAUDE.md`: "The parent skill is the single source of truth. Downstream artifacts are *built* from the skill, never edited directly." Two hand-maintained copies would drift, which is the failure ADR-007 avoids for the starter repo.

The marketplace repository planned for these plugins (`lloydbriantech-claude-marketplace`) does not exist yet.

## Decision

1. **Plugin skills are generated, not written.** `make plugins` (`make/build-plugins.sh`) builds each plugin skill from its template source. For each skill it:
   - renames it (`ascent-env-audit` becomes `env-audit`, invoked as `/ascent-security:env-audit`);
   - rewrites links between skills in the same plugin;
   - turns links to skills outside the plugin into plain text;
   - fills template placeholders with neutral wording;
   - stamps the version from `plugin.json` and adds a "generated — edit the source" notice.

   The build fails if any placeholder survives.
2. **Drift fails the gate.** `make test-plugins` rebuilds into a temporary directory and fails if any committed plugin skill differs from what was built. It also checks:
   - no placeholders;
   - names and versions agree across directory, `plugin.json`, marketplace entry and skills, and every marketplace source is a plugin directory;
   - agents are read-only: tools a subset of Read, Grep, Glob, and no frontmatter keys beyond name, description, tools, model and color;
   - skills pre-approve only read tools (Read, Grep, Glob, `git ls-files`, `git log`);
   - the skills that classify findings carry the shared severity table, and every copy is identical;
   - links resolve and stay inside the plugin;
   - frontmatter is valid;
   - every skill step an agent cites exists, and an agent cites at least one;
   - `claude plugin validate` passes, when the CLI is installed.

   In `make test-mutants`, a baseline control shows an unmodified copy passes, and 13 negative controls each break one thing and must fail on the check they name.
3. **Agents and manifests are hand-written.** An agent is a new artifact, not a copy. It references the skills' steps by number so a reviewer can trace each check, and its tool list is enforced read-only.
4. **Plugins detect their inputs.** The skills locate source code, compose files, Dockerfiles and nginx configs from common layouts and say which paths they used. A surface with no files is never a failure: a project with no containers reports container security as "not present" (not applicable), while source code that cannot be located is "not assessed". This is the detect-don't-ask pattern, and it is what makes the skills useful outside ASCENT projects. A project contract file is deferred until a second plugin needs one.
5. **Interim home.** Plugins live under `plugins/` in this repository, with `.claude-plugin/marketplace.json` at the root, so they install today with `/plugin marketplace add lloydbrian/lloydbriantech-ascent`. When `lloydbriantech-claude-marketplace` exists, the marketplace entry moves there and points back at this repository. The generator, the gate and the template source stay here.
6. **First plugin: `ascent-security`.** It contains `env-audit`, `security-audit`, `sec-posture` and a `security-auditor` agent. It is the security-review pilot capability. Its skills were hardened at the source before generation (audit F39):
   - a shared severity table;
   - object-style credential detection;
   - redacted findings;
   - CSP and HSTS required;
   - a check for nginx `location` blocks that drop headers;
   - exhaustive posture rules.

## Alternatives considered

- **Hand-copy the skills into the plugin.** Simplest today, but two copies drift and nothing catches it. Rejected under architecture rule 1.
- **Make the template's `.claude/skills/` the plugin directly.** The template copies must keep their placeholders, because a scaffolded project renders them, and their ascent-prefixed names, because inside a project they sit beside 25 other skills. A plugin needs neither. One file cannot serve both audiences without a build step, so the build step is explicit.
- **Wait for the marketplace repository.** Delays a working plugin for no technical reason. The marketplace entry is a single small JSON file that can move later without changing any plugin.
- **Generate with Python** (the Phase 4 language). Every other meta-repo tool is portable bash and runs on stock macOS and Linux. Revisit when Phase 4's scaffolder lands; the generator is small enough to port.

## Consequences

**Easier:**
- Any repository, including tennis, the home lab and work repositories (subject to employer policy), can install the security checks with two commands, in Claude Code, VS Code or Cowork.
- A fix made once in the template source reaches scaffolded projects and the plugin, and the gate proves the plugin was rebuilt.
- The delivery loop can call the `security-auditor` agent for its security review angle.

**Harder:**
- Skill authors must run `make plugins` after editing a skill that a plugin ships. CI fails until they do.
- The agent restates the checks in short form. Its step references and the read-only tool rule are tested, but its wording is reviewed by a person.

**Neutral:**
- `version:` in template frontmatter remains a placeholder for scaffolded projects. Plugin copies carry the plugin version.
- Plugins carry the plugin namespace, so `/ascent-security:env-audit` and a scaffolded project's `/ascent-env-audit` can coexist without colliding.

## Cost implications

- About half a day for the generator, gate and controls. Each further plugin is a few lines in the generator's map, a `plugin.json` and a marketplace entry.
- `claude plugin details` estimates about 520 tokens of always-on context per session where the plugin is enabled, and about 1.9k (agent) to 3.9k (security-audit) tokens each time a skill or the agent runs. These are the CLI's estimates, not measured usage; re-check them when a skill grows.
- When the marketplace repository exists, moving the plugin is one PR in each repository.
