# SEC — security checks and dependency hygiene.
#
# Each target is a named stub shipped from Day 1 per Principle 4.
# Implementation lands when CVE scanner and audit tooling are configured.

.PHONY: sec-scan sec-audit sec-deps

sec-scan:  ## SEC: Scan dependencies for known CVEs
	@printf "sec-scan: [STUB] implement when CVE scanner is added (Trivy, Grype, Snyk)\n"
	@printf "  Scans both backend and frontend dependency trees.\n"
	@printf "  Run before every release; integrate into CI for PRs.\n"

sec-audit:  ## SEC: Run security audit against project threat model
	@printf "sec-audit: [STUB] implement when security audit tooling is configured\n"
	@printf "  Validates: auth flows, secret handling, endpoint exposure, image hardening.\n"
	@printf "  See docs/architecture/decisions/ADR-001 (container-first) for baseline.\n"

sec-deps:  ## SEC: Check dependency freshness and known-vulnerable versions
	@printf "sec-deps: [STUB] implement when dependency monitor is added (npm audit, Dependabot)\n"
	@printf "  Reports outdated packages and flags those with active CVEs.\n"
