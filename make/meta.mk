# META — reference and at-a-glance state of the framework

.PHONY: version status

version:  ## META: Print framework version
	@printf "%s\n" "$(FRAMEWORK_VERSION)"

status:  ## META: Show framework state at a glance
	@printf "Framework:    %s\n" "$(FRAMEWORK_NAME)"
	@printf "Version:      %s\n" "$(FRAMEWORK_VERSION)"
	@printf "Phase:        1 complete (v0.2.0); Phase 2 in progress\n"
	@printf "Branch:       %s\n" "$$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf '(not a git repo)')"
	@printf "Commit:       %s\n" "$$(git rev-parse --short HEAD 2>/dev/null || printf '(no commits)')"
	@if [ -L "$(HOME)/.claude/skills/$(FRAMEWORK_NAME)" ]; then \
	  printf "Skill:        installed (-> %s)\n" "$$(readlink $(HOME)/.claude/skills/$(FRAMEWORK_NAME))"; \
	elif [ -e "$(HOME)/.claude/skills/$(FRAMEWORK_NAME)" ]; then \
	  printf "Skill:        present at ~/.claude/skills/%s but NOT a symlink\n" "$(FRAMEWORK_NAME)"; \
	else \
	  printf "Skill:        not installed (run 'make install')\n"; \
	fi
