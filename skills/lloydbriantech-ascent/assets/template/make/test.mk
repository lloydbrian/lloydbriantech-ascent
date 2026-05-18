# TEST — test discipline hierarchy.
#
# test-unit and test-skills are real implementations.
# test-integration and test-e2e remain stubs per PHASE-3-PLAN.md §8
# (their implementation lands in Phase 5).

.PHONY: test-unit test-integration test-e2e test-skills test-skill test-all

test-unit:  ## TEST: Run unit tests (Vitest)
	@cd backend && npx vitest run

test-integration:  ## TEST: Run integration tests [STUB lands in Phase 5]
	@printf "test-integration: [STUB] implement when integration test framework is added\n"
	@printf "  Integration tests cover controller -> service -> storage paths with a real database.\n"

test-e2e:  ## TEST: Run end-to-end tests [STUB lands in Phase 5]
	@printf "test-e2e: [STUB] implement when e2e framework is added (Playwright, Cypress)\n"
	@printf "  E2E tests cover full user flows through the stack.\n"

test-skills:  ## TEST: Run all skill tests
	@TESTS_DIR="tests/skills"; \
	PASS=0; FAIL=0; FAILED=""; \
	for test in "$$TESTS_DIR"/test-*.sh; do \
	  [ -f "$$test" ] || continue; \
	  SKILL=$$(basename "$$test" .sh | sed 's/^test-//'); \
	  if bash "$$test"; then \
	    PASS=$$((PASS + 1)); \
	  else \
	    FAIL=$$((FAIL + 1)); \
	    FAILED="$$FAILED  FAIL: $$SKILL\n"; \
	  fi; \
	done; \
	TOTAL=$$((PASS + FAIL)); \
	printf "\nSkills test suite: %s/%s PASS" "$$PASS" "$$TOTAL"; \
	if [ "$$FAIL" -gt 0 ]; then \
	  printf ", %s FAIL\n" "$$FAIL"; \
	  printf "$$FAILED"; \
	  exit 1; \
	else \
	  printf "\n"; \
	fi

test-skill:  ## TEST: Run one skill test (usage: make test-skill SKILL=ascent-env-audit)
	@if [ -z "$(SKILL)" ]; then \
	  printf "Usage: make test-skill SKILL=<skill-name>\n"; \
	  printf "Example: make test-skill SKILL=ascent-env-audit\n"; \
	  exit 1; \
	fi
	@bash tests/skills/test-$(SKILL).sh

test-all:  ## TEST: Run all test suites (unit + skills + integration + e2e)
	@$(MAKE) --no-print-directory test-unit
	@$(MAKE) --no-print-directory test-skills
	@$(MAKE) --no-print-directory test-integration
	@$(MAKE) --no-print-directory test-e2e
