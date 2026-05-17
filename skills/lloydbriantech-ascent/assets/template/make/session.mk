# SESSION — session state capture and resumption verification.
# Per PRINCIPLES.md §15, project state is durable and inspected on every session start.
#
# Requires bash for local variable support in classify_file().
SHELL := /bin/bash

.PHONY: session-snapshot session-resume

session-snapshot:  ## META: Capture current session state to docs/delivery/session-state.md
	@DELIVERY_DIR="docs/delivery"; \
	STATE_FILE="$$DELIVERY_DIR/session-state.md"; \
	SNAPSHOTS_DIR="$$DELIVERY_DIR/snapshots"; \
	TIMESTAMP=$$(date +%Y-%m-%d-%H%M); \
	SNAPSHOT_FILE="$$SNAPSHOTS_DIR/$$TIMESTAMP.md"; \
	\
	mkdir -p "$$DELIVERY_DIR" "$$SNAPSHOTS_DIR"; \
	\
	BRANCH=$$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf "unknown"); \
	COMMIT=$$(git rev-parse --short HEAD 2>/dev/null || printf "unknown"); \
	DIRTY=$$(git status --porcelain 2>/dev/null | wc -l | tr -d ' '); \
	\
	if [ -f .ascent-meta.json ]; then \
	  if command -v jq >/dev/null 2>&1; then \
	    PHASE=$$(jq -r '.phase // "unknown"' .ascent-meta.json); \
	    FOCUS=$$(jq -r '.current_focus // ""' .ascent-meta.json); \
	  else \
	    PHASE=$$(grep '"phase"' .ascent-meta.json | sed 's/.*: *"//;s/".*//' || printf "unknown"); \
	    FOCUS=$$(grep '"current_focus"' .ascent-meta.json | sed 's/.*: *"//;s/".*//' || printf ""); \
	  fi; \
	else \
	  PHASE="unknown (no .ascent-meta.json)"; \
	  FOCUS=""; \
	fi; \
	\
	printf "# Session state\n\n" > "$$STATE_FILE"; \
	printf "Captured: %s\n\n" "$$TIMESTAMP" >> "$$STATE_FILE"; \
	printf "## Current focus\n\n" >> "$$STATE_FILE"; \
	if [ -n "$$FOCUS" ]; then \
	  printf "%s\n\n" "$$FOCUS" >> "$$STATE_FILE"; \
	else \
	  printf "(fill in: what are you working on right now?)\n\n" >> "$$STATE_FILE"; \
	fi; \
	printf "## Active decisions\n\n" >> "$$STATE_FILE"; \
	printf "(fill in: questions being deliberated but not yet resolved)\n\n" >> "$$STATE_FILE"; \
	printf "## Blockers\n\n" >> "$$STATE_FILE"; \
	printf "(fill in: what's preventing progress, if anything)\n\n" >> "$$STATE_FILE"; \
	printf "## Next actions\n\n" >> "$$STATE_FILE"; \
	printf "(fill in: immediate next steps when resuming)\n\n" >> "$$STATE_FILE"; \
	printf "## Phase context\n\n" >> "$$STATE_FILE"; \
	printf "- Phase: %s\n" "$$PHASE" >> "$$STATE_FILE"; \
	printf "- Branch: %s (%s)\n" "$$BRANCH" "$$COMMIT" >> "$$STATE_FILE"; \
	printf "- Uncommitted changes: %s\n" "$$DIRTY" >> "$$STATE_FILE"; \
	\
	cp "$$STATE_FILE" "$$SNAPSHOT_FILE"; \
	\
	printf "session-snapshot: state written to %s\n" "$$STATE_FILE"; \
	printf "session-snapshot: snapshot archived at %s\n" "$$SNAPSHOT_FILE"; \
	printf "session-snapshot: edit %s to fill in focus, decisions, blockers, next actions\n" "$$STATE_FILE"

session-resume:  ## META: Display session state for verification (what Claude reads on start)
	@DELIVERY_DIR="docs/delivery"; \
	STATE_FILE="$$DELIVERY_DIR/session-state.md"; \
	MEMORY_FILE="$$DELIVERY_DIR/working-memory.md"; \
	STALE_DAYS=7; \
	\
	classify_file() { \
	  local file="$$1"; \
	  if [ ! -f "$$file" ]; then \
	    printf "MISSING"; \
	    return; \
	  fi; \
	  local content=$$(grep -c '[^[:space:]]' "$$file" 2>/dev/null || echo 0); \
	  if [ "$$content" -le 1 ]; then \
	    printf "EMPTY"; \
	    return; \
	  fi; \
	  local mod_epoch=$$(stat -f %m "$$file" 2>/dev/null || stat -c %Y "$$file" 2>/dev/null || echo 0); \
	  local now_epoch=$$(date +%s); \
	  local age_days=$$(( (now_epoch - mod_epoch) / 86400 )); \
	  if [ "$$age_days" -gt "$$STALE_DAYS" ]; then \
	    printf "STALE (%s days old)" "$$age_days"; \
	  else \
	    printf "FRESH (%s days old)" "$$age_days"; \
	  fi; \
	}; \
	\
	printf "\n"; \
	printf "  Session resumption — what Claude reads on start\n"; \
	printf "  ══════════════════════════════════════════════════\n"; \
	printf "\n"; \
	\
	STATE_CLASS=$$(classify_file "$$STATE_FILE"); \
	printf "  session-state.md:   [%s]\n" "$$STATE_CLASS"; \
	if [ -f "$$STATE_FILE" ] && [ "$$(grep -c '[^[:space:]]' "$$STATE_FILE" 2>/dev/null || echo 0)" -gt 1 ]; then \
	  printf "  ──────────────────────────────────────\n"; \
	  sed 's/^/  /' "$$STATE_FILE"; \
	  printf "\n"; \
	fi; \
	\
	printf "\n"; \
	MEMORY_CLASS=$$(classify_file "$$MEMORY_FILE"); \
	printf "  working-memory.md:  [%s]\n" "$$MEMORY_CLASS"; \
	if [ -f "$$MEMORY_FILE" ] && [ "$$(grep -c '[^[:space:]]' "$$MEMORY_FILE" 2>/dev/null || echo 0)" -gt 1 ]; then \
	  printf "  ──────────────────────────────────────\n"; \
	  sed 's/^/  /' "$$MEMORY_FILE"; \
	  printf "\n"; \
	fi; \
	\
	printf "\n"; \
	printf "  Protocol: Claude reads these files, cites them by name, refuses to\n"; \
	printf "  confabulate content not grounded in them. Run this command to see\n"; \
	printf "  exactly what Claude sees. See session-protocol.md for full details.\n"; \
	printf "\n"
