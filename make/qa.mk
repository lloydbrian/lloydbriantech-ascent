# QA — static validation of skill structure, frontmatter, and internal links

.PHONY: qa qa-skill-frontmatter qa-links

qa:  ## QA: Run all QA checks
	@$(MAKE) --no-print-directory qa-skill-frontmatter
	@$(MAKE) --no-print-directory qa-links

qa-skill-frontmatter:  ## QA: Validate frontmatter of every SKILL.md
	@bash make/qa-skill-frontmatter.sh

qa-links:  ## QA: Validate internal markdown links
	@bash make/qa-links.sh
