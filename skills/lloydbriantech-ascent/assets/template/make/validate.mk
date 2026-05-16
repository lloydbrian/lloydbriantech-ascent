# VALIDATE — runtime and schema validation.
#
# Each target is a named stub shipped from Day 1 per Principle 4.
# Implementation lands when validators are authored for the project's schema and structure.

.PHONY: validate-schema validate-env validate-structure

validate-schema:  ## VALIDATE: Validate .ascent-meta.json against schema
	@printf "validate-schema: [STUB] implement when schema validator is added\n"
	@printf "  Checks .ascent-meta.json fields, types, and schema_version compatibility.\n"

validate-env:  ## VALIDATE: Verify .env.example matches code expectations
	@printf "validate-env: [STUB] implement when env validator is added\n"
	@printf "  Ensures every <<ENV_PREFIX>>_* variable read in code appears in .env.example.\n"
	@printf "  Ensures .env.example contains no non-empty defaults (per ENV-DISCIPLINE).\n"

validate-structure:  ## VALIDATE: Verify project directory structure matches ASCENT conventions
	@printf "validate-structure: [STUB] implement when structure validator is added\n"
	@printf "  Checks: backend/ layering intact, required files present, no orphaned modules.\n"
