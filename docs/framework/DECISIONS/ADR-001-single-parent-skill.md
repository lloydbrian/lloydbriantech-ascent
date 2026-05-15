# ADR-001: Single parent skill with internal role routing

**Status:** Accepted
**Date:** 2026-05-14 (America/New_York)
**Decider:** lloydbriantech

## Context

The initial framework design called for six parent skills, each owning a discipline: architect, designer, developer, tester, devops, cybersecurity. The intent was a clean role-based decomposition that mirrored a real engineering team's structure.

Two problems surfaced during the design review:

**Trigger collision.** Claude's skill system auto-invokes skills based on description matching against the user's input. Six skills whose descriptions all begin with "ASCENT framework..." would compete for the same triggers. When a user typed "I want to add a login endpoint," the runtime would have to pick among architect (because it might need an ADR), developer (because it needs implementation), and cybersecurity (because login is security-relevant). The user would have no good way to disambiguate, and the framework would produce inconsistent role selection.

**Operational overhead per skill.** Each skill carries its own SKILL.md, frontmatter, allowed-tools declaration, references directory, and assets bundle. Six skills means six times the bookkeeping: six frontmatters to validate, six references trees to maintain, six packaging tasks. For a framework whose value is in the *combined* discipline of all roles, the per-skill overhead pays off poorly.

The design also called for adding three more roles (delivery-lead, data-engineer, ai-engineer, plus ui-ux-designer as a split from designer), bringing the total to nine. Nine separate skills would compound both problems.

## Decision

ASCENT ships **one parent skill** named `lloydbriantech-ascent` with **internal role-routing logic**. The nine roles live as reference modules inside the skill (`references/role-*.md`), loaded into context based on the user's intent as determined by the skill's routing logic at runtime.

The "nine roles" remain the mental model in framework documentation. Engineers familiar with team org charts can map their thinking onto the framework. But the technical implementation is one skill that knows about nine roles, not nine skills that know about one role each.

The skill's routing logic operates on these signals:

- Explicit role invocation ("as the architect role, draft an ADR for X")
- Implicit role inference from request shape ("scaffold this project" → architect role; "add a security header" → cybersecurity role; "what's our phase plan" → delivery-lead role)
- Multi-role tasks loaded with multiple reference modules (a new feature might engage delivery-lead + architect + developer + tester)

## Alternatives considered

**Six skills (or nine) as originally designed.** Rejected for the reasons in the Context section. The trigger collision is structural — Claude's skill system has no concept of "skill priority" or "skill disambiguation prompt" that would resolve the issue cleanly.

**One skill per project-embedded skill, with no parent skill at all.** Considered briefly. Rejected because there's still a need for scaffold/enhance/migrate logic that lives outside any individual project. The parent skill exists precisely to bridge between "I want to start a new ASCENT project" (no project exists yet) and "I want to enhance my existing ASCENT project" (a project exists). Without a parent, that bridging logic has nowhere natural to live.

**Three skills — `ascent-create` (scaffold), `ascent-modify` (enhance + migrate), `ascent-operate` (project-embedded delegate).** Reduces the trigger collision somewhat but doesn't eliminate it. Still requires the user to think about which mode their task fits before invoking, when the mode is usually obvious from context.

**Two skills — `lloydbriantech-ascent` (the parent) and `lloydbriantech-ascent-roles` (the role modules as a library).** Rejected because Claude's skill system doesn't compose skills cleanly — a library skill that another skill depends on is not a first-class concept.

## Consequences

**Easier:**

- One frontmatter to validate, one references tree to maintain, one packaging task
- Trigger logic is clear: any framework-related request hits `lloydbriantech-ascent`, then the skill decides which role(s) engage
- Cross-role workflows (a feature touching architect + developer + tester) load multiple reference modules in one Claude session without skill-to-skill handoff
- The framework's mental model and its technical model are explicitly different, with documentation that bridges the two — this is honest about the implementation

**Harder:**

- The single SKILL.md is longer and more complex than any single role-skill would be (must contain routing logic)
- Adding a new role means modifying the existing skill rather than authoring a new self-contained skill — slightly higher contribution friction
- Discoverability of roles relies on framework documentation, not on skill-list browsing — users browsing `~/.claude/skills/` see one entry where the original design would have shown six

**Neutral:**

- The role-based mental model is preserved in documentation and reference modules; users still think in terms of nine roles even though the technical layer is one skill

## Cost implications

**Time:** Saves ongoing maintenance time across the framework's lifetime (one skill to update instead of nine). Adds one-time design cost in Phase 1 to author the routing logic robustly.

**Complexity:** Shifts complexity from "many simple things" to "one moderately complex thing." Net complexity decrease in the system, because skill-to-skill coordination would have been the dominant complexity in the alternative.

**Future flexibility:** Slight cost — adding a new role requires modifying the parent skill rather than dropping a new skill into the collection. The benefit of independent role evolution is sacrificed in exchange for trigger reliability. Given how rarely roles change (once added, they evolve slowly), the trade-off is acceptable.

**Money:** No financial cost difference.
