# QA — code quality checks.
#
# Each target is a named stub shipped from Day 1 per Principle 4.
# Implementation lands when linter, type checker, and structure validator are configured.

.PHONY: qa qa-lint qa-typecheck qa-structure

qa:  ## QA: Run all quality checks (lint + typecheck + structure)
	@$(MAKE) --no-print-directory qa-lint
	@$(MAKE) --no-print-directory qa-typecheck
	@$(MAKE) --no-print-directory qa-structure

qa-lint:  ## QA: Run linter
	@printf "qa-lint: [STUB] implement when linter is added (ESLint, Biome)\n"
	@printf "  Covers backend/ and frontend/ source files.\n"

qa-typecheck:  ## QA: Run type checker
	@printf "qa-typecheck: [STUB] implement when type checking is added (TypeScript, JSDoc)\n"
	@printf "  Runs without emitting — type errors fail the check, not the build.\n"

qa-structure:  ## QA: Validate project structure against ASCENT conventions
	@printf "qa-structure: [STUB] implement when structure validator is added\n"
	@printf "  Checks: backend layering (routes/controllers/services/storage), required files present,\n"
	@printf "  .env.example matches code expectations, ADR INDEX.md is current.\n"
