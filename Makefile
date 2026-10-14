.PHONY: help test docs-check clean

.DEFAULT_GOAL := help

SHELL := /bin/bash

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

test: ## Run the dependency-free headless test suite
	@./tests/run.sh

docs-check: ## Check that Neovim help documentation resolves
	@nvim --headless -u NONE --cmd 'set rtp^=.' -c 'helptags doc' -c 'help novelist' -c 'quitall'

clean: ## Remove generated help tags
	@rm -f doc/tags
