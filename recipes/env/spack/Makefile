# Target rules
all: build
	@echo "Building spack"

build: assets

.PHONY: assets
assets: assets/postinstall.sh
	@echo "Build assets for spack"

.PHONY: assets/postinstall.sh
assets/postinstall.sh:
	curl -skL -o assets/postinstall.sh https://raw.githubusercontent.com/spack/spack-configs/main/AWS/parallelcluster/postinstall.sh

run: build
	@echo "Run assets for spack"

test: build

clean:
	rm -rf assets/*

clobber: clean
