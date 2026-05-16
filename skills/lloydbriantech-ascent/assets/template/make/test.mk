# TEST — test discipline hierarchy.
#
# Each target is a named stub shipped from Day 1 per Principle 4 (stub-first naming).
# Implementation lands when the project's test framework is chosen and configured.

.PHONY: test-unit test-integration test-e2e test-all

test-unit:  ## TEST: Run unit tests
	@printf "test-unit: [STUB] implement when test framework is added (Jest, Vitest, Mocha)\n"
	@printf "  Unit tests cover individual functions and classes in isolation.\n"
	@printf "  Convention: tests/ directory mirrors backend/ structure.\n"

test-integration:  ## TEST: Run integration tests
	@printf "test-integration: [STUB] implement when test framework is added\n"
	@printf "  Integration tests cover controller -> service -> storage paths with a real database.\n"

test-e2e:  ## TEST: Run end-to-end tests
	@printf "test-e2e: [STUB] implement when e2e framework is added (Playwright, Cypress)\n"
	@printf "  E2E tests cover full user flows through the stack.\n"

test-all:  ## TEST: Run all test suites (unit + integration + e2e)
	@$(MAKE) --no-print-directory test-unit
	@$(MAKE) --no-print-directory test-integration
	@$(MAKE) --no-print-directory test-e2e
