# TEST — skill tests, the plugin gate, negative controls, harness self-tests and ownership
# (`make test`, the eval scenarios, lands in Phase 5)

.PHONY: test test-skills test-mutants test-mutants-groups test-harness test-plugins gate-scope gate-changed ownership plugins

test:  ## TEST: Run eval scenarios against the skill [STUB lands in P5.0]
	@printf "[STUB] make test lands in Phase 5 (v0.6.0)\n"
	@printf "Phase 5 introduces tests/scenarios/*.md and runs them via Claude with the skill installed.\n"

test-skills:  ## TEST: Render the template and run all 28 embedded-skill tests
	@WORK="$$(mktemp -d)"; trap 'rm -rf "$$WORK"' EXIT; \
	bash make/render-template.sh "$$WORK/project" && \
	$(MAKE) --no-print-directory -C "$$WORK/project" -f make/test.mk test-skills

# MODE, JOBS, IDS, TIMES, CACHE and BASE count only when given on the command line: an exported
# one in the operator's shell must not change what runs.
mutant_arg = $(if $(filter command line,$(origin $(1))),$($(1)))

test-mutants:  ## TEST: Negative controls — every named mutant must be killed (ADR-008); GROUP=<group>, MODE=full, JOBS=<n> (ADR-018), IDS="<id> ..." (ADR-023), TIMES=<file>, CACHE=<dir> (ADR-025)
	@ASCENT_MUTANT_GROUP="$(GROUP)" ASCENT_MUTANT_MODE="$(call mutant_arg,MODE)" ASCENT_MUTANT_JOBS="$(call mutant_arg,JOBS)" ASCENT_MUTANT_IDS="$(call mutant_arg,IDS)" ASCENT_MUTANT_TIMES="$(call mutant_arg,TIMES)" ASCENT_MUTANT_CACHE="$(call mutant_arg,CACHE)" bash make/test-mutants.sh

test-mutants-groups:  ## TEST: List the negative-control groups as JSON (one CI job per group)
	@bash make/test-mutants.sh --groups-json

test-harness:  ## TEST: The harness's slow self-tests — gate sections run alone, parallel runs report as serial ones (ADR-018)
	@bash tests/meta/test-gate-sections.sh && bash tests/meta/test-mutants-harness.sh

test-plugins:  ## TEST: Plugin gate T1–T17 — drift, names, versions, read-only agents, links, behavior tests, ownership, fast-mode and scope self-tests, own ADRs and release evidence
	@bash make/test-plugins.sh

gate-scope:  ## TEST: Show which slow checks this branch needs, and why, from its changes against origin/main (BASE=<ref>; ADR-023)
	@bash make/gate-scope.sh --base "$(or $(call mutant_arg,BASE),origin/main)" --explain

gate-changed:  ## TEST: Run what CI runs for this branch — the cheap checks, then the slow checks its changes need (BASE=<ref>; ADR-023)
	@bash make/gate-scope.sh --base "$(or $(call mutant_arg,BASE),origin/main)" --run

ownership:  ## TEST: Ownership gate T13 alone — OWNERSHIP.md against the repository (ADR-015)
	@bash make/check-ownership.sh

plugins:  ## DIST: Regenerate plugin skills from the template sources (ADR-009)
	@bash make/build-plugins.sh
