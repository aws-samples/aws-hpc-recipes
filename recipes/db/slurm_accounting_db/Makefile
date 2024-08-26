# Target rules
all: build
	@echo "Building slurm_accounting_db"

build: assets

.PHONY: assets
assets:
	@echo "Build assets for slurm_accounting_db"
	curl -skL -o "assets/main.yaml" "https://raw.githubusercontent.com/aws/aws-parallelcluster/develop/cloudformation/database/main.yaml"

run: build
	@echo "Run assets for slurm_accounting_db"

test: build

clean:

clobber: clean