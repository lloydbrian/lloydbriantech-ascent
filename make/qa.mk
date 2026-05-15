# QA — static validation of skill structure, frontmatter, internal links, and template placeholders

.PHONY: qa qa-skill-frontmatter qa-links qa-template-placeholders

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
