# Makefile for pcs/cluster_dns recipe

SHELL := /bin/bash
ASSETS_DIR := assets
TESTS_DIR := tests
SCRIPTS := $(wildcard $(ASSETS_DIR)/*.sh)
TEMPLATE := $(ASSETS_DIR)/cluster-dns.yaml

.PHONY: all build lint validate test checksums clean clobber

all: lint test

build:
	@echo "No build step required for this recipe."

lint:
	@echo "Running ShellCheck on shell scripts..."
	@shellcheck $(SCRIPTS) $(TESTS_DIR)/validate.sh
	@echo "Running cfn-lint on the template..."
	@if command -v cfn-lint >/dev/null 2>&1; then cfn-lint $(TEMPLATE); else echo "  cfn-lint not installed — skipping"; fi
	@echo "Lint passed."

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
