# Target rules
all: build
	@echo "Building parakeet_transcription_awsbatch_nvidia"

build: assets

.PHONY: assets
assets: assets/deployment.yaml
	@echo "Build assets for parakeet_transcription_awsbatch_nvidia"

.PHONY: assets/deployment.yaml
assets/deployment.yaml:
	curl -skL -o assets/deployment.yaml https://raw.githubusercontent.com/aws-samples/sample-parakeet-transcription-awsbatch-nvidia-blog/main/deployment.yaml

run: build
	@echo "Run assets for parakeet_transcription_awsbatch_nvidia"

test: build

clean:

clobber: clean
