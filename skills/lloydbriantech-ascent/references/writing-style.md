# writing-style

> Doc voice, tense, and anti-patterns for ASCENT documentation. [PRINCIPLES.md §14](../../../docs/framework/PRINCIPLES.md#14-persona-segmented-documentation) is the authoritative principle this style serves.

Documentation in ASCENT is a craft, not an afterthought. The voice is consistent across the framework, scaffolded projects, role modules, and ADRs. This document codifies the voice and shows it in action.

## Voice

- **Active, not passive.** "The skill loads the module" — not "the module is loaded by the skill."
- **Declarative, not hedging.** "The framework refuses whole-file overwrites." — not "the framework will generally try to use surgical edits where possible."
- **Specific, not abstract.** "`make qa-skill-frontmatter` validates the four required fields." — not "various quality checks are run."
- **Direct, not chatty.** No "let's look at..." or "we'll now discuss..." filler. Lead with the claim.
- **Concrete examples beat abstract rules.** Show, then state the rule. Or state the rule, then show. Don't only state.

## Tense

- **Present tense** for what the system does: "The skill routes intent across roles."
- **Imperative** for what the reader does: "Add the entry to `.gitignore`."
- **Past tense** only for history (CHANGELOG, ADR Context sections, post-mortems).
- **Future tense** only for explicit roadmap items: "Phase 5 introduces eval scenarios."

Mixing tenses in the same section reads as incomplete drafting. Pick one for each section.

## Anti-patterns

- **Documentation theater** — docs written to look thorough rather than to be read. The cure: every doc has a named audience (see [audience-mapping.md](audience-mapping.md)). If you can't name the audience, don't write the doc.
- **Hedging.** "May", "might", "could", "perhaps" weaken the statement. Reserve them for genuine uncertainty.
- **Role-blind prose.** "Someone should make sure..." — who? Name the role: "The cybersecurity role verifies..."
- **Universal documentation.** A doc for everyone is a doc for no one. See [doc-architecture.md](doc-architecture.md) for the persona-segmentation rule.
- **Restating without distillation.** Copy-paste from one doc to another with no compression is doc-theater. Restatement should compress — three paragraphs become three sentences.
- **Inline TODOs that ship.** A `TODO` in committed prose is a promise that everyone reads and no one fulfills. Either resolve it or remove it.

## Snippets — voice in action

Three short examples from the framework's own prose. Read them aloud; the voice is consistent across files.

### From [CLAUDE.md](../../../CLAUDE.md):

> The parent skill is the single source of truth. The starter repo and any other downstream artifacts are *built* from the skill, never edited directly.

Two declarative claims. No hedging. Active voice. The italic *built* is the only emphasis — used to highlight the verb that distinguishes the framework's architecture from naive alternatives.

### From [ARCHITECTURE.md](../../../docs/framework/ARCHITECTURE.md):

> Scaffolded projects do not import a framework library. The framework's "output" is *files*, and those files are independent of the framework after creation. This is intentional. A framework with a runtime would couple every scaffolded project to the framework's release cadence; ASCENT scaffolds projects that survive the framework's deletion.

Negative claim ("do not import"), positive claim, justification, consequence. Each sentence sharpens the previous. The closing phrase "survive the framework's deletion" is concrete imagery that makes the abstract concrete.

### From PRINCIPLES.md:

> "Works on my machine" is the single largest source of friction in software delivery. When the development environment is the container, this class of bug becomes impossible by construction.

Names the problem (the cliché *is* the problem). States the solution. Explains the mechanism in five words. No room for argument.

## Formatting conventions

- **Tables** for comparisons and enumerations with parallel structure
- **Code spans** for identifiers, file paths, command names, environment variables
- **Code blocks** for multi-line snippets, with language tag when meaningful
- **Quoted blocks** for direct quotations from other docs (as above) or to set off a definition
- **Bold** for the term being defined; sparingly elsewhere
- **Italic** for emphasis when bold is too loud; sparingly
- **Em-dashes** for parenthetical asides — tighter than commas, less ambiguous than parens

## Sentence shape

- Lead with the subject and verb. "The skill loads modules on demand" beats "On demand, modules are loaded by the skill."
- Limit subordinate clauses. One per sentence is plenty; two is the cap.
- Numbers go in numerals (`6`, `14`, `629`) unless they begin a sentence.
- Avoid "of" stacks. "The version of the file" → "the file's version."

## Section depth

Three levels of heading. `#` for the title, `##` for major sections, `###` for sub-sections within a major section. `####` is a smell — refactor into a `###` or fold into prose.

The reading rhythm: a reader scrolling through `##` headings should know the whole document's structure. If they don't, the doc is missing scaffolding.

## What this doc doesn't cover

- ADR-specific format (Context / Decision / Alternatives / Consequences / Cost implications) — that lives in `ADR-TEMPLATE.md`
- Code-comment style — that lives per-language in the developer role module (Chunk 5 of Phase 1)
- Commit message style — Conventional Commits per `CONTRIBUTING.md`; the style guide there governs commit prose

Writing in ASCENT is one voice across the whole framework. When in doubt, read three nearby docs and match.
