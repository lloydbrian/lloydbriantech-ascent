# DEV — work on the framework locally
#
# install/uninstall symlink the parent skill into ~/.claude/skills/ so Claude
# Code can load it from this working tree. The skill source itself lands in
# Phase 1 Chunk 2 — `make install` will fail with a clear message until then.

SKILL_NAME := $(FRAMEWORK_NAME)
SKILL_SRC  := $(CURDIR)/skills/$(SKILL_NAME)
SKILL_DST  := $(HOME)/.claude/skills/$(SKILL_NAME)

.PHONY: install uninstall

install:  ## DEV: Symlink the parent skill into ~/.claude/skills/
	@if [ ! -d "$(SKILL_SRC)" ]; then \
	  printf "install: skill source not found at %s\n" "$(SKILL_SRC)" 1>&2; \
	  printf "install: the parent skill has not yet been authored in this working tree.\n" 1>&2; \
	  exit 1; \
	fi
	@mkdir -p "$(HOME)/.claude/skills"
	@if [ -L "$(SKILL_DST)" ]; then \
	  printf "install: symlink already exists: %s -> %s\n" "$(SKILL_DST)" "$$(readlink $(SKILL_DST))"; \
	  printf "install: run 'make uninstall' first to replace it.\n"; \
	  exit 1; \
	fi
	@if [ -e "$(SKILL_DST)" ]; then \
	  printf "install: %s exists and is not a symlink — refusing to overwrite\n" "$(SKILL_DST)" 1>&2; \
	  exit 1; \
	fi
	@ln -s "$(SKILL_SRC)" "$(SKILL_DST)"
	@printf "install: linked %s -> %s\n" "$(SKILL_DST)" "$(SKILL_SRC)"

uninstall:  ## DEV: Remove the parent skill symlink from ~/.claude/skills/
	@if [ -L "$(SKILL_DST)" ]; then \
	  rm "$(SKILL_DST)"; \
	  printf "uninstall: removed symlink %s\n" "$(SKILL_DST)"; \
	elif [ -e "$(SKILL_DST)" ]; then \
	  printf "uninstall: %s exists but is not a symlink — refusing to remove\n" "$(SKILL_DST)" 1>&2; \
	  exit 1; \
	else \
	  printf "uninstall: not installed (no symlink at %s); nothing to do\n" "$(SKILL_DST)"; \
	fi
