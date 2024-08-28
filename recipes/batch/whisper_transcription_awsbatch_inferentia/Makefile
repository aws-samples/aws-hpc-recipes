# Target rules
all: build
	@echo "Building whisper_transcription_awsbatch_inferentia"

build: assets

.PHONY: assets
assets: assets/deployment.yaml
	@echo "Build assets for whisper_transcription_awsbatch_inferentia"

.PHONY: assets/deployment.yaml
assets/deployment.yaml:
	curl -skL -o assets/deployment.yaml https://raw.githubusercontent.com/aws-samples/whisper-transcription-awsbatch-inferentia-blog/main/deployment.yaml

run: build
	@echo "Run assets for whisper_transcription_awsbatch_inferentia"

test: build

clean:

clobber: clean
