# Engine detection and container-engine lifecycle.
#
# Principles honored:
#   §9  — Label-based project scoping (cleanup filters by --label project=<<PROJECT_LABEL>>)
#   §10 — Container engine compatibility (auto-detect Podman, fallback Docker)
#   §11 — Context-aware host/container execution (<<INSIDE_CONTAINER_MARKER>>=1)

# Auto-detect container engine: prefer Podman, fall back to Docker.
# Override with ENGINE=docker make <target>.
ENGINE := $(shell command -v podman 2>/dev/null || command -v docker 2>/dev/null || echo "echo 'ERROR: no container engine found'")

# Context-aware execution marker.
# The Dockerfile sets <<INSIDE_CONTAINER_MARKER>>=1; targets that behave
# differently on host vs inside-container check this variable.
export <<INSIDE_CONTAINER_MARKER>>

.PHONY: engine-clean-project engine-clean-images engine-clean-volumes

engine-clean-project:  ## DEV: Remove all project containers, networks, and volumes (label-filtered)
	@printf "Stopping containers with label project=<<PROJECT_LABEL>>...\n"
	@$(ENGINE) ps -q --filter label=project=<<PROJECT_LABEL>> 2>/dev/null | xargs -r $(ENGINE) stop 2>/dev/null || true
	@printf "Removing containers with label project=<<PROJECT_LABEL>>...\n"
	@$(ENGINE) ps -aq --filter label=project=<<PROJECT_LABEL>> 2>/dev/null | xargs -r $(ENGINE) rm 2>/dev/null || true
	@printf "Removing networks matching <<PROJECT_SLUG>>...\n"
	@$(ENGINE) network ls --filter label=project=<<PROJECT_LABEL>> -q 2>/dev/null | xargs -r $(ENGINE) network rm 2>/dev/null || true
	@printf "Removing volumes matching <<PROJECT_SLUG>>...\n"
	@$(ENGINE) volume ls --filter label=project=<<PROJECT_LABEL>> -q 2>/dev/null | xargs -r $(ENGINE) volume rm 2>/dev/null || true
	@printf "engine-clean-project: done\n"

engine-clean-images:  ## DEV: Remove project container images
	@printf "Removing images matching <<PROJECT_SLUG>>...\n"
	@$(ENGINE) images --filter reference='<<IMAGE_DEV>>' -q 2>/dev/null | xargs -r $(ENGINE) rmi 2>/dev/null || true
	@$(ENGINE) images --filter reference='<<IMAGE_PROD>>' -q 2>/dev/null | xargs -r $(ENGINE) rmi 2>/dev/null || true
	@printf "engine-clean-images: done\n"

engine-clean-volumes:  ## DEV: Remove project data volumes
	@printf "Removing volume <<VOLUME_DATA>>...\n"
	@$(ENGINE) volume rm <<VOLUME_DATA>> 2>/dev/null || true
	@printf "engine-clean-volumes: done\n"
