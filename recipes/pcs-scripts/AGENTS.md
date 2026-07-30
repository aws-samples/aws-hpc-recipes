# Agent guide: recipes/pcs-scripts

Conventions for authoring community **PCS node lifecycle action (NLA)** scripts in
this namespace. These supplement — they do not repeat — the checks that CI already
enforces. Read `recipes/pcs-scripts/README.md` for the full contributor checklist and
`docs/` for repository-wide rules.

## What CI already enforces (do not re-explain, just satisfy)

- **ShellCheck is blocking here.** Every `*.sh` under `recipes/pcs-scripts/` MUST pass
  `shellcheck` cleanly at default severity (`scripts/validate_shellcheck.py`). Elsewhere
  in the repo it is advisory only.
- Structure, `metadata.yml` schema, partition safety, and (per recipe) `tests/validate.sh`
  run in `make validate` / CI. Run `make lint && make test` in the recipe directory before
  proposing changes.

## NLA conventions CI does NOT check — get these right by hand

- **Versioned filenames + checksums.** Name scripts `‹name›-v‹MAJOR.MINOR.PATCH›.sh` and
  ship a companion `‹script›.sha256`. After editing any script, regenerate with
  `make checksums` (a stale checksum fails `tests/validate.sh`, but only if you remember to
  run it — regenerate as part of every script edit).
- **Fail fast on instance metadata.** IMDS calls MUST use short timeouts
  (`curl --connect-timeout 1 --max-time 2 …`). A lifecycle action runs during node
  bootstrap; a hanging metadata call stalls the whole node. Never call IMDS without a bound.
- **Decide best-effort vs. fail-loud, and document it.** For each script, choose deliberately:
  a critical action (e.g. storage tuning) should fail loudly and pair with `onError: TERMINATE`;
  a cosmetic or optional action (e.g. tagging, MOTD) should degrade to a warning + `exit 0` and
  pair with `onError: CONTINUE`. State the intended `onError` and `executionPolicy` in the
  script header and the recipe README.
- **Do not manage log files.** The PCS agent captures stdout/stderr to
  `/var/log/amazon/pcs/lifecycle/actions/‹stage›/‹script-name›.log`. Emit consistent,
  prefixed messages to stdout/stderr; never open your own log file.
- **No package installation.** Assume prerequisites are baked into the AMI. Detect a missing
  prerequisite and either fail loudly or degrade (per the criticality decision above); document
  required packages in the script header and recipe README.
- **The public bucket is single-Region.** Assets are served from `aws-hpc-recipes` in
  `us-east-1` only — the S3 URI is region-agnostic, but any HTTPS URL keeps the
  `s3.us-east-1.amazonaws.com` host regardless of the cluster's Region. Do not rewrite that
  host per Region (this is the opposite of AWS's per-Region `aws-pcs-repo-‹region›` buckets).

## When adding a new recipe here

- Follow the standard skeleton (`README.md`, `metadata.yml`, `Makefile`, `assets/`, `docs/`,
  `tests/`); `metadata.yml` uses `type: shell` and tags including `community`.
- Copy `node_lifecycle_demo`'s `Makefile` and `tests/validate.sh` as the starting point — they
  encode the lint/test/checksum loop this namespace expects.
