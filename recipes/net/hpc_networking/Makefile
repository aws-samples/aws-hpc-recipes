# Release
RELEASE_TAG := develop

# Target rules
all: build
	@echo "Building hpc_networking"

build: assets

assets: assets/public.cfn.json assets/public-private.cfn.json
	@echo "Build assets for hpc_networking"

assets/public.cfn.json:
	curl -skL -o assets/public.cfn.json https://raw.githubusercontent.com/aws/aws-parallelcluster/${RELEASE_TAG}/cloudformation/networking/public.cfn.json

assets/public-private.cfn.json:
	curl -skL -o assets/public-private.cfn.json https://raw.githubusercontent.com/aws/aws-parallelcluster/${RELEASE_TAG}/cloudformation/networking/public-private.cfn.json
	
run: build
	@echo "Run assets for hpc_networking"

test: build

clean:
	rm -rf assets/*

clobber: clean
