.PHONY: help test docs-check clean install uninstall

.DEFAULT_GOAL := help

SHELL := /bin/bash

INSTALL_DIR ?= $(if $(XDG_DATA_HOME),$(XDG_DATA_HOME)/nvim/site/pack/novelist/start/novelist,$(HOME)/.local/share/nvim/site/pack/novelist/start/novelist)

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

test: ## Run the dependency-free headless test suite
	@./tests/run.sh

docs-check: ## Check that Neovim help documentation resolves
	@nvim --headless -u NONE --cmd 'set rtp^=.' -c 'helptags doc' -c 'help novelist' -c 'quitall'

clean: ## Remove generated help tags
	@rm -f doc/tags

install: ## Symlink this checkout into Neovim's package path
	@set -eu; \
	repo=$$(pwd -P); target="$(INSTALL_DIR)"; \
	if [ -z "$$target" ]; then echo "install: INSTALL_DIR must not be empty" >&2; exit 1; fi; \
	if [ -L "$$target" ]; then \
	  existing=$$(cd -P -- "$$target" 2>/dev/null && pwd -P) || existing=; \
	  if [ "$$existing" = "$$repo" ]; then echo "install: already linked to $$repo"; exit 0; fi; \
	  echo "install: refusing to replace existing destination: $$target" >&2; exit 1; \
	fi; \
	if [ -e "$$target" ]; then echo "install: refusing to replace existing destination: $$target" >&2; exit 1; fi; \
	mkdir -p -- "$$(dirname -- "$$target")"; \
	ln -s -- "$$repo" "$$target"; \
	echo "install: linked $$target to $$repo"

uninstall: ## Remove this checkout's symlink from Neovim's package path
	@set -eu; \
	repo=$$(pwd -P); target="$(INSTALL_DIR)"; \
	if [ -z "$$target" ]; then echo "uninstall: INSTALL_DIR must not be empty" >&2; exit 1; fi; \
	if [ -L "$$target" ]; then \
	  existing=$$(cd -P -- "$$target" 2>/dev/null && pwd -P) || existing=; \
	  if [ "$$existing" = "$$repo" ]; then rm -- "$$target"; echo "uninstall: removed $$target"; exit 0; fi; \
	fi; \
	echo "uninstall: leaving unrelated destination untouched: $$target"
