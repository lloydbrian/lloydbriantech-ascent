# DEV — container lifecycle for local development.
#
# All targets use $(ENGINE) for Podman/Docker compatibility (Principle 10).
# dev-down sends SIGTERM with a 15-second grace period (Principle 12).

.PHONY: dev-up dev-down dev-logs dev-shell dev-restart dev-clean

dev-up:  ## DEV: Start the dev stack
	@printf "Starting <<PROJECT_TITLE>> dev stack...\n"
	@$(ENGINE) compose up -d
	@printf "dev-up: stack running\n"
	@printf "  Backend:  http://localhost:3001/healthz\n"
	@printf "  Frontend: http://localhost:3000\n"
	@printf "  Proxy:    http://localhost:8080\n"

dev-down:  ## DEV: Stop the dev stack (graceful shutdown, 15s grace)
	@printf "Stopping <<PROJECT_TITLE>> dev stack (SIGTERM + 15s grace)...\n"
	@$(ENGINE) compose down --timeout 15
	@printf "dev-down: stack stopped\n"

dev-logs:  ## DEV: Tail container logs (all services)
	@$(ENGINE) compose logs -f

dev-shell:  ## DEV: Open a shell in the backend container
	@$(ENGINE) compose exec backend /bin/sh

dev-restart:  ## DEV: Restart the dev stack (down + up)
	@$(MAKE) --no-print-directory dev-down
	@$(MAKE) --no-print-directory dev-up

dev-clean:  ## DEV: Full cleanup (stop + remove containers, networks, volumes, images)
	@$(MAKE) --no-print-directory dev-down
	@$(MAKE) --no-print-directory engine-clean-project
	@$(MAKE) --no-print-directory engine-clean-images
	@printf "dev-clean: all project resources removed\n"
