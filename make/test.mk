# TEST — eval scenarios for the skill (lands in Phase 5)

.PHONY: test test-skills test-mutants test-mutants-groups test-harness test-plugins ownership plugins

test:  ## TEST: Run eval scenarios against the skill [STUB lands in P5.0]
	@printf "[STUB] make test lands in Phase 5 (v0.6.0)\n"
	@printf "Phase 5 introduces tests/scenarios/*.md and runs them via Claude with the skill installed.\n"

test-skills:  ## TEST: Render the template and run all 28 embedded-skill tests
	@WORK="$$(mktemp -d)"; trap 'rm -rf "$$WORK"' EXIT; \
	bash make/render-template.sh "$$WORK/project" && \
	$(MAKE) --no-print-directory -C "$$WORK/project" -f make/test.mk test-skills

# MODE and JOBS count only when given on the command line: an exported MODE or
# JOBS in the operator's shell must not change how the controls run.
mutant_arg = $(if $(filter command line,$(origin $(1))),$($(1)))

test-mutants:  ## TEST: Negative controls — every named mutant must be killed (ADR-008); GROUP=<group>, MODE=full, JOBS=<n> (ADR-018)
	@ASCENT_MUTANT_GROUP="$(GROUP)" ASCENT_MUTANT_MODE="$(call mutant_arg,MODE)" ASCENT_MUTANT_JOBS="$(call mutant_arg,JOBS)" bash make/test-mutants.sh

test-mutants-groups:  ## TEST: List the negative-control groups as JSON (one CI job per group)
	@bash make/test-mutants.sh --groups-json

test-harness:  ## TEST: The harness's slow self-tests — gate sections run alone, parallel runs report as serial ones (ADR-018)
	@bash tests/meta/test-gate-sections.sh && bash tests/meta/test-mutants-harness.sh

test-plugins:  ## TEST: Plugin gate — drift, placeholders, names, read-only agents, links, ownership (ADR-009)
	@bash make/test-plugins.sh

ownership:  ## TEST: Ownership gate T13 alone — OWNERSHIP.md against the repository (ADR-015)
	@bash make/check-ownership.sh

plugins:  ## DIST: Regenerate plugin skills from the template sources (ADR-009)
	@bash make/build-plugins.sh
