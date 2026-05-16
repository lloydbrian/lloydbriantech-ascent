# DEV — morning-standup status family (Principle 13).
#
# dev-status:       full check (~3-5s) — every row pairs with a deep-dive command
# dev-status-quick: fast subset (~80ms) — container + port only
#
# The status command never fails — it reports state, it doesn't gate.

.PHONY: dev-status dev-status-quick

dev-status:  ## DEV: Full dev environment status check (~3-5s)
	@printf "\n"
	@printf "  <<PROJECT_TITLE>> — dev status\n"
	@printf "  ──────────────────────────────────────\n"
	@printf "\n"
	@# Engine
	@printf "  %-24s" "Engine:"
	@if command -v $(ENGINE) >/dev/null 2>&1; then \
	  printf "$(ENGINE) (%s)\n" "$$($(ENGINE) --version 2>/dev/null | head -1)"; \
	else \
	  printf "NOT FOUND — install Podman or Docker\n"; \
	fi
	@# Containers
	@printf "  %-24s" "Containers:"
	@RUNNING=$$($(ENGINE) ps --filter label=project=<<PROJECT_LABEL>> --format '{{.Names}}' 2>/dev/null | wc -l | tr -d ' '); \
	if [ "$$RUNNING" -gt 0 ]; then \
	  printf "%s running (" "$$RUNNING"; \
	  $(ENGINE) ps --filter label=project=<<PROJECT_LABEL>> --format '{{.Names}}' 2>/dev/null | tr '\n' ' '; \
	  printf ")\n"; \
	else \
	  printf "none running — run 'make dev-up'\n"; \
	fi
	@# Backend health
	@printf "  %-24s" "Backend /healthz:"
	@if curl -sf http://localhost:3001/healthz >/dev/null 2>&1; then \
	  printf "OK (http://localhost:3001/healthz)\n"; \
	else \
	  printf "UNREACHABLE — run 'make dev-up' then 'make dev-logs'\n"; \
	fi
	@# Backend readiness
	@printf "  %-24s" "Backend /readyz:"
	@if curl -sf http://localhost:3001/readyz >/dev/null 2>&1; then \
	  printf "OK (http://localhost:3001/readyz)\n"; \
	else \
	  printf "NOT READY — check db connection and dependencies\n"; \
	fi
	@# Frontend
	@printf "  %-24s" "Frontend:"
	@if curl -sf http://localhost:3000 >/dev/null 2>&1; then \
	  printf "OK (http://localhost:3000)\n"; \
	else \
	  printf "UNREACHABLE — run 'make dev-up' then 'make dev-logs'\n"; \
	fi
	@# .env file
	@printf "  %-24s" ".env file:"
	@if [ -f .env ]; then \
	  VARS=$$(grep -cE '^[A-Z_]+=' .env 2>/dev/null || echo 0); \
	  printf "present (%s vars set)\n" "$$VARS"; \
	else \
	  printf "MISSING — copy .env.example to .env and fill in values\n"; \
	fi
	@# Database
	@printf "  %-24s" "Database:"
	@if [ -f data/<<PROJECT_SLUG>>.sqlite ]; then \
	  SIZE=$$(du -h data/<<PROJECT_SLUG>>.sqlite 2>/dev/null | cut -f1); \
	  printf "SQLite-WAL present (%s)\n" "$$SIZE"; \
	else \
	  printf "not yet created — will initialize on first request\n"; \
	fi
	@# Git
	@printf "  %-24s" "Git:"
	@if git rev-parse --git-dir >/dev/null 2>&1; then \
	  BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	  DIRTY=$$(git status --porcelain 2>/dev/null | wc -l | tr -d ' '); \
	  if [ "$$DIRTY" -gt 0 ]; then \
	    printf "%s (%s uncommitted changes)\n" "$$BRANCH" "$$DIRTY"; \
	  else \
	    printf "%s (clean)\n" "$$BRANCH"; \
	  fi; \
	else \
	  printf "not a git repository\n"; \
	fi
	@printf "\n"
	@# Next Actions
	@printf "  Next Actions\n"
	@printf "  ──────────────────────────────────────\n"
	@if ! command -v $(ENGINE) >/dev/null 2>&1; then \
	  printf "  → Install Podman or Docker\n"; \
	elif ! $(ENGINE) ps --filter label=project=<<PROJECT_LABEL>> --format '{{.Names}}' 2>/dev/null | grep -q .; then \
	  printf "  → Run 'make dev-up' to start the dev stack\n"; \
	elif ! curl -sf http://localhost:3001/healthz >/dev/null 2>&1; then \
	  printf "  → Backend unhealthy — run 'make dev-logs' to investigate\n"; \
	elif ! [ -f .env ]; then \
	  printf "  → Copy .env.example to .env and fill in values\n"; \
	else \
	  printf "  → Environment looks good. Run 'make test-all' or start coding.\n"; \
	fi
	@printf "\n"

dev-status-quick:  ## DEV: Fast dev status check (~80ms, containers + port only)
	@RUNNING=$$($(ENGINE) ps --filter label=project=<<PROJECT_LABEL>> --format '{{.Names}}' 2>/dev/null | wc -l | tr -d ' '); \
	HEALTH=$$(curl -sf -o /dev/null -w '%{http_code}' http://localhost:3001/healthz 2>/dev/null || echo "000"); \
	printf "<<PROJECT_SLUG>> | containers: %s | /healthz: %s | engine: %s\n" "$$RUNNING" "$$HEALTH" "$(ENGINE)"
