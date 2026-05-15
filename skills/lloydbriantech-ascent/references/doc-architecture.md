# doc-architecture

> The structural side of [PRINCIPLES.md §14](../../../docs/framework/PRINCIPLES.md#14-persona-segmented-documentation). Persona segmentation defines *who reads what*; this module defines *how the docs link together*.

A doc-set is a graph, not a list. Nodes are documents; edges are links. Good doc-architecture produces a graph that's:

- **Rooted** — every doc is reachable from one or more persona entry points
- **Bounded** — no doc is more than 3 clicks from its persona's root
- **Audience-pure** — each doc serves one primary audience; cross-references suit the originating audience's needs

This module is about the graph's shape. The persona→entry-point mapping lives canonically in [audience-mapping.md](audience-mapping.md).

## The five personas

ASCENT recognizes five personas — Architect, Developer, Operator, Contributor, Learner. Each has a known entry point and a bounded path through the doc graph. See `audience-mapping.md` for the persona definitions, entry points, and per-persona paths.

## Depth limit — 3 clicks

No doc is more than **3 clicks** from its persona's root.

Why 3: more clicks lose readers. The "3 click rule" is well-documented in UX research; for technical documentation it's even tighter because each click is a context switch.

Implication: when a doc is naturally 4 deep in the tree, the persona's entry point grows a "shortcut" link directly to it. Path purity in the tree matters less than reachability for the reader.

## Audience purity

Each doc serves **one primary audience**. Cross-references are allowed and encouraged, but the doc's voice, depth, and assumptions match its primary audience.

When a doc serves two audiences (rare but happens), pick one as primary. The secondary audience's needs are handled by cross-reference, not by hedging the voice in two directions.

Anti-pattern: a doc that says "for developers, skip this section." Split the doc.

## The reading rhythm

A reader scrolling through a doc should be able to predict the next heading from the previous one. The structure is itself the table of contents; if the headings don't tell the story, the doc is missing scaffolding.

This is enforced by [writing-style.md](writing-style.md)'s "Section depth" rule — three heading levels max, no `####`.

## Cross-links

Cross-links between docs are the graph's edges. Two rules govern them:

1. **Forward-references** point from less-specific to more-specific. A persona entry point links to role modules; role modules link to specific patterns; specific patterns rarely link upward except for grounding citations.
2. **Backward-references** are citation-only. A specific doc citing the persona entry point that scoped it is fine; a specific doc embedding the entry point's overview is doc-theater.

The framework's own `references/` directory applies these rules — see the cross-linking discipline applied across all modules (each module's header carries authoritative links; body links first mentions only).

## The doc graph as artifact

The doc graph is queryable. `make qa-links` validates internal markdown links — the bare structural check. A future skill (`ascent-doc-sweep`) will validate semantic completeness: every persona reachable, every leaf reachable from at least one root, no orphaned docs.

For now: write to the persona, link to the next-most-specific, and trust the rules.

## Anti-patterns

- **Doc dump** — long docs that try to be everything for everyone. Split by audience.
- **Hub-and-spoke** — a central doc that's the only entry to everything. Brittle; breaks when reorganized.
- **Cycle of references** — A → B → C → A. Usually means the topic should be one doc, not three.
- **Audience aliasing** — a doc nominally for Developers but secretly for Architects (because the writer is an architect). The voice gives it away.
- **Stub docs without intent** — a `TODO.md` or empty `setup.md` is graph noise. Lazy-generated docs per `make doc-stub` are deliberate; orphan stubs are not.

## Updating doc-architecture

When the framework adds a new persona, a new doc class, or a new structural constraint, this module updates first. Other docs update their cross-references to match. Adding without updating this module risks doc-graph drift — the kind of drift `ascent-doc-sweep` exists to detect.
