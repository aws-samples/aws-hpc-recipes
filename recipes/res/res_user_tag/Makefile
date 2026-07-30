# Target rules
all: build
	@echo "Building res_user_tag"

build: assets

assets:
	@echo "Build assets for res_user_tag"

run: build
	@echo "Run assets for res_user_tag"

test: build
	shellcheck assets/tag-res-user.sh
	cfn-lint assets/res-user-tagger.yaml
	cd . && python3 -m venv .venv && . .venv/bin/activate && pip install -q -r tests/requirements.txt && pytest tests/ -q

clean:
	rm -rf .venv

clobber: clean
