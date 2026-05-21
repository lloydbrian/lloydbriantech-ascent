# QA — static validation of skill structure, frontmatter, internal links, and template placeholders

.PHONY: qa qa-skill-frontmatter qa-links qa-template-placeholders qa-claimed-vs-actual

qa:  ## QA: Run all QA checks
	@$(MAKE) --no-print-directory qa-skill-frontmatter
	@$(MAKE) --no-print-directory qa-links
	@$(MAKE) --no-print-directory qa-template-placeholders

qa-skill-frontmatter:  ## QA: Validate frontmatter of every SKILL.md
	@bash make/qa-skill-frontmatter.sh

qa-links:  ## QA: Validate internal markdown links
	@bash make/qa-links.sh

qa-template-placeholders:  ## QA: Validate template slug placeholders against canonical set
	@bash make/qa-template-placeholders.sh

qa-claimed-vs-actual:  ## QA: Verify artifacts claimed in PLAN file exist
	@if [ -z "$(PLAN)" ]; then \
	  printf "Usage: make qa-claimed-vs-actual PLAN=<plan-file>\n"; \
	  printf "Example: make qa-claimed-vs-actual PLAN=docs/framework/PHASE-3-RETRO-PLAN.md\n"; \
	  exit 1; \
	fi
	@bash make/qa-claimed-vs-actual.sh "$(PLAN)"
