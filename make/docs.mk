# DOCS — documentation generation and audit, from the ascent-docs plugin

.PHONY: doc-stub

# sq: a value for single quotes, so the shell runs nothing in a title (F12)
sq = $(subst ','\'',$(1))
doc-stub-usage = printf 'Usage: make doc-stub TYPE=<tutorial|how-to|reference|explanation|entry> TITLE="<title>" [PERSONA=<reader>] [OUT=<path.md>]\n'; printf 'Writes one new document with guidance in every section; never overwrites one. See plugins/ascent-docs/README.md.\n'

doc-stub:  ## DOCS: New doc from a stub (TYPE=tutorial, how-to, reference, explanation or entry; TITLE="..."; PERSONA, OUT optional)
	@$(if $(and $(TYPE),$(TITLE)),:,$(doc-stub-usage); exit 2)
	@bash plugins/ascent-docs/scripts/doc-stub.sh --type '$(call sq,$(TYPE))' --title '$(call sq,$(TITLE))' \
	  $(if $(PERSONA),--persona '$(call sq,$(PERSONA))') $(if $(OUT),--out '$(call sq,$(OUT))') .
