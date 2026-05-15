# RELEASE — tag and publish releases

.PHONY: release release-tag

release-tag:  ## RELEASE: Create git tag matching FRAMEWORK_VERSION on HEAD
	@if git rev-parse "v$(FRAMEWORK_VERSION)" >/dev/null 2>&1; then \
	  printf "release-tag: tag v%s already exists, refusing to overwrite\n" "$(FRAMEWORK_VERSION)" 1>&2; \
	  exit 1; \
	fi
	@git tag "v$(FRAMEWORK_VERSION)"
	@printf "release-tag: created tag v%s on %s\n" "$(FRAMEWORK_VERSION)" "$$(git rev-parse --short HEAD)"
	@printf "release-tag: run 'git push --tags' to publish.\n"

release:  ## RELEASE: Cut a release (tag + GitHub release) [STUB lands in P7.0]
	@printf "[STUB] make release lands in Phase 7 (v1.0.0)\n"
	@printf "For now: 'make release-tag' creates the tag; push manually with 'git push --tags'.\n"
