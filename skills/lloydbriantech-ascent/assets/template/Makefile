# <<PROJECT_TITLE>> — Makefile
#
# Per ASCENT Principle 2, make is the only operator vocabulary.
# Run `make help` (or bare `make`) for the SDLC-sectioned target list.
#
# Sections: META · DEV · TEST · QA · SEC · VALIDATE · DOCS · INFRA

SHELL := /bin/bash
.DEFAULT_GOAL := help

PROJECT_SLUG    := <<PROJECT_SLUG>>
PROJECT_VERSION := <<PROJECT_VERSION>>

export PROJECT_SLUG
export PROJECT_VERSION

include make/engine.mk
include make/dev.mk
include make/dev-status.mk
include make/test.mk
include make/quality.mk
include make/security.mk
include make/validate.mk
include make/docs.mk
include make/infra.mk
include make/session.mk

.PHONY: help version status

help:  ## META: Show this help (default target)
	@bash make/help.sh

version:  ## META: Print project version
	@printf "%s\n" "$(PROJECT_VERSION)"

status:  ## META: Show project state at a glance
	@printf "Project:      %s\n" "$(PROJECT_SLUG)"
	@printf "Version:      %s\n" "$(PROJECT_VERSION)"
	@printf "Engine:       %s\n" "$(ENGINE)"
	@printf "Branch:       %s\n" "$$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf '(not a git repo)')"
	@printf "Commit:       %s\n" "$$(git rev-parse --short HEAD 2>/dev/null || printf '(no commits)')"
	@if $(ENGINE) ps --filter label=project=$(PROJECT_SLUG) --format '{{.Names}}' 2>/dev/null | grep -q .; then \
	  printf "Containers:   %s\n" "$$($(ENGINE) ps --filter label=project=$(PROJECT_SLUG) --format '{{.Names}}' | tr '\n' ' ')"; \
	else \
	  printf "Containers:   none running (run 'make dev-up')\n"; \
	fi
