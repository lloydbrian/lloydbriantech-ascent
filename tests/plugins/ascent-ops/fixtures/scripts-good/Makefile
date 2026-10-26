.PHONY: help deploy status
help:  ## META: List targets
	@grep -E '^[a-z-]+:.*##' Makefile

deploy:  ## DEPLOY: Deploy the stack (ENV=dev|prod)
	@bash scripts/deploy.sh --env "$(ENV)"

status:  ## META: Show the stack status
	@sh scripts/status.sh "$(ENV)"

VERSION := 1.4.2
