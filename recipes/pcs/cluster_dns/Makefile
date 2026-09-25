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

# Regenerate the companion .sha256 files after editing any script, and re-pin the
# same digest inside example-node-lifecycle-actions.json. Both copies must move
# together: the JSON one is what the PCS agent verifies before running the script as
# root, and it is the copy operators paste into their node-group configuration.
# HASH resolves at recipe time so the redirect below cannot truncate a .sha256 file
# when the tool is missing.
HASH := $(shell command -v sha256sum >/dev/null 2>&1 && echo sha256sum || echo "shasum -a 256")
EXAMPLE_JSON := $(ASSETS_DIR)/example-node-lifecycle-actions.json

checksums:
	@echo "Regenerating checksums with '$(HASH)'..."
	@cd $(ASSETS_DIR) && for f in *.sh; do $(HASH) "$$f" > "$$f.sha256"; done
	@python3 -c 'import json,re,sys,pathlib,hashlib;\
p=pathlib.Path("$(EXAMPLE_JSON)");d=json.loads(p.read_text());\
stages=d.get("stages",{});\
[a["scriptSource"].__setitem__("checksum",hashlib.sha256((pathlib.Path("$(ASSETS_DIR)")/a["scriptSource"]["scriptLocation"].rsplit("/",1)[-1]).read_bytes()).hexdigest())\
 for acts in stages.values() for a in acts if "scriptSource" in a];\
p.write_text(json.dumps(d,indent=2)+"\n")'
	@echo "Checksums written (.sha256 files and $(EXAMPLE_JSON))."

clean:
	@echo "Nothing to clean."

clobber: clean
