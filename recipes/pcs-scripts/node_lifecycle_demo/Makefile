# Makefile for pcs-scripts/node_lifecycle_demo recipe

SHELL := /bin/bash
ASSETS_DIR := assets
TESTS_DIR := tests
SCRIPTS := $(wildcard $(ASSETS_DIR)/*.sh)

.PHONY: all build lint validate test checksums clean clobber

all: lint test

build:
	@echo "No build step required for this recipe."

lint:
	@echo "Running ShellCheck on shell scripts..."
	@shellcheck $(SCRIPTS) $(TESTS_DIR)/validate.sh
	@echo "Running yamllint on metadata..."
	@if command -v yamllint >/dev/null 2>&1; then yamllint metadata.yml; else echo "  yamllint not installed — skipping"; fi
	@echo "Lint passed."

# `validate` is an alias for `test` so this recipe participates in the
# repository convention while running its own script-oriented checks.
validate: test

test:
	@$(TESTS_DIR)/validate.sh

# Regenerate the companion .sha256 files after editing any script.
checksums:
	@echo "Regenerating checksums..."
	@cd $(ASSETS_DIR) && for f in *.sh; do sha256sum "$$f" > "$$f.sha256"; done
	@echo "Checksums written."

clean:
	@echo "Nothing to clean."

clobber: clean
