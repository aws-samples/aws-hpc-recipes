# Makefile for pcs/nice_dcv recipe

SHELL := /bin/bash
ASSETS_DIR := assets
TESTS_DIR := tests

.PHONY: all build lint validate test clean

all: lint validate

build:
	@echo "No build step required for this recipe."

lint:
	@echo "Running ShellCheck on shell scripts..."
	@shellcheck $(ASSETS_DIR)/install-relion.sh
	@shellcheck $(TESTS_DIR)/validate.sh
	@echo "Running yamllint on YAML files..."
	@yamllint metadata.yml
	@yamllint $(ASSETS_DIR)/dcv-linux-node.yaml
	@echo "Lint passed."

validate:
	@echo "Validating CloudFormation template..."
	@if aws sts get-caller-identity &>/dev/null; then \
		aws cloudformation validate-template \
			--template-body file://$(ASSETS_DIR)/dcv-linux-node.yaml \
			--output text > /dev/null && echo "Template validation passed."; \
	else \
		echo "Skipping CloudFormation validation (no AWS credentials)."; \
	fi

test:
	@$(TESTS_DIR)/validate.sh

clean:
	@echo "Nothing to clean."
