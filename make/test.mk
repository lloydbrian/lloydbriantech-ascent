# TEST — eval scenarios for the skill (lands in Phase 5)

.PHONY: test test-skills test-mutants

test:  ## TEST: Run eval scenarios against the skill [STUB lands in P5.0]
	@printf "[STUB] make test lands in Phase 5 (v0.6.0)\n"
	@printf "Phase 5 introduces tests/scenarios/*.md and runs them via Claude with the skill installed.\n"

test-skills:  ## TEST: Render the template and run all 28 embedded-skill tests
	@WORK="$$(mktemp -d)"; trap 'rm -rf "$$WORK"' EXIT; \
	bash make/render-template.sh "$$WORK/project" && \
	$(MAKE) --no-print-directory -C "$$WORK/project" -f make/test.mk test-skills

test-mutants:  ## TEST: Negative controls — every named mutant must be killed (ADR-008)
	@bash make/test-mutants.sh
