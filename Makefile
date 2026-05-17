# lloydbriantech-ascent — root Makefile
#
# Per PRINCIPLES.md §2, make is the only operator vocabulary for this framework.
# Run `make help` (or bare `make`) for the SDLC-sectioned target list.
#
# Section order (META · DEV · TEST · QA · DOCS · DIST · RELEASE) matches the
# meta-repo convention in CLAUDE.md. Scaffolded projects use a project-level
# section list that adds SEC · VALIDATE · INFRA — those land in Phase 2 templates.

SHELL := /bin/bash
.DEFAULT_GOAL := help

FRAMEWORK_NAME    := lloydbriantech-ascent
FRAMEWORK_VERSION := 0.3.1

export FRAMEWORK_NAME
export FRAMEWORK_VERSION

include make/meta.mk
include make/dev.mk
include make/test.mk
include make/qa.mk
include make/docs.mk
include make/dist.mk
include make/release.mk

.PHONY: help
help:  ## META: Show this help (default target)
	@bash make/help.sh
