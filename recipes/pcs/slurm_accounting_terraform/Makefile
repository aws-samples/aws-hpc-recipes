# Target rules
all: build
	@echo "Building slurm_accounting_terraform"

build: assets

assets:
	@echo "Build assets for slurm_accounting_terraform"

# Unit tests need only Python 3.12+. Terraform validation runs when terraform
# is on PATH and is skipped otherwise.
test: build
	python3 -m unittest discover -s tests -v
	@if command -v terraform >/dev/null 2>&1; then \
		for d in assets assets/examples/complete assets/examples/sacctmgr-dump; do \
			echo "terraform validate $$d"; \
			(cd $$d && terraform init -backend=false -input=false >/dev/null && terraform fmt -check -recursive && terraform validate) || exit 1; \
		done; \
	else \
		echo "terraform not found; skipping terraform validate"; \
	fi

clean:
	find . -name __pycache__ -type d -prune -exec rm -rf {} +
	find . -name .terraform -type d -prune -exec rm -rf {} +
	find . -name .terraform.lock.hcl -delete

clobber: clean
