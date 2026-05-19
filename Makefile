# Release tag
ifdef HPCDK_TAG
RELEASE_TAG := $(HPCDK_TAG)
else
RELEASE_TAG := main
endif

# Deployment bucket
ifdef HPCDK_S3_BUCKET
S3_BUCKET := $(HPCDK_S3_BUCKET)
else
S3_BUCKET := aws-hpc-recipes
endif

# CLI profile
ifdef HPCDK_PROFILE
PROFILE := $(HPCDK_PROFILE)
else
PROFILE := default
endif

PROJECTS ?= $(shell find recipes -name Makefile)

FILTER_OUT :=

PROJECTS := $(filter-out $(FILTER_OUT),$(PROJECTS))

%.ph_build :
	+@$(MAKE) -C $(dir $*) $(MAKECMDGOALS)

%.ph_test :
	+@$(MAKE) -C $(dir $*) test

%.ph_clean : 
	+@$(MAKE) -C $(dir $*) clean $(USE_DEVICE)

%.ph_clobber :
	+@$(MAKE) -C $(dir $*) clobber $(USE_DEVICE)

all:  $(addsuffix .ph_build,$(PROJECTS))
	@echo "Finished building recipes"

build: $(addsuffix .ph_build,$(PROJECTS))

test : $(addsuffix .ph_test,$(PROJECTS))

tidy:
	@find * | egrep "#" | xargs rm -f
	@find * | egrep "\~" | xargs rm -f

clean: tidy $(addsuffix .ph_clean,$(PROJECTS))

clobber: clean $(addsuffix .ph_clobber,$(PROJECTS))

.PHONY: validate
validate:
	@echo "=== Validating recipe structure ==="
	python -m scripts.validate_structure
	@echo ""
	@echo "=== Validating recipe metadata ==="
	python -m scripts.validate_metadata
	@echo ""
	@echo "=== Checking partition safety ==="
	python -m scripts.validate_partitions
	@echo ""
	@echo "=== Running cfn-lint ==="
	@files=$$(find recipes -path '*/assets/*.yaml' -o -path '*/assets/*.yml' | grep -v '.gitkeep' | xargs grep -l 'AWSTemplateFormatVersion\|^Resources:' 2>/dev/null); \
	if [ -n "$$files" ]; then cfn-lint -t $$files || true; else echo "No CFN templates found."; fi
	@echo ""
	@echo "=== All validation complete ==="

.PHONY: deploy
deploy:
	@aws s3 sync --profile ${PROFILE} --delete --acl public-read \
		--exclude "*" --include "*/assets/*" --exclude "*/.gitkeep" \
		recipes s3://${S3_BUCKET}/${RELEASE_TAG}/recipes/;\

.PHONY: readme
readme:
	python -m scripts.render_readme
	git add recipes/README.md

set_version:
	$(eval RELEASE_TAG := $(shell git describe))
	@echo ${RELEASE_TAG}

release: set_version readme deploy
