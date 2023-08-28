# Target rules
all: build
	@echo "Building demo_managed_ad"

build: assets

assets:
	@echo "Build assets for demo_managed_ad"
	curl -skL -o "assets/main.yaml" "https://raw.githubusercontent.com/aws/aws-parallelcluster/develop/cloudformation/ad/ad-integration.yaml"

run: build
	@echo "Run assets for demo_managed_ad"

test: build

clean:

clobber: clean
