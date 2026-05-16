# DOCS — documentation generation and audit.
#
# Each target is a named stub shipped from Day 1 per Principle 4.
# Implementation lands when doc generation and sweep tooling are authored.

.PHONY: doc-generate doc-sweep

doc-generate:  ## DOCS: Generate documentation from templates
	@printf "doc-generate: [STUB] implement when doc generator is added\n"
	@printf "  Generates API docs from route definitions and ADR index from decision files.\n"

doc-sweep:  ## DOCS: Audit documentation consistency
	@printf "doc-sweep: [STUB] implement when doc-sweep tooling is added\n"
	@printf "  Checks: every persona reachable from README, no broken internal links,\n"
	@printf "  ADR INDEX.md matches actual ADR files, CHANGELOG current.\n"
