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

## Required script header shape

Every script in this namespace opens with the same block, in this order. The metadata
tag names match the AWS-maintained node lifecycle action scripts (in
`s3://aws-pcs-repo-‹region›/aws-pcs-node-lifecycle-scripts/`) so one parser reads both
sets. Copy an existing script rather than reconstructing this from memory.

```bash
#!/usr/bin/env bash
#
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
#DESCRIPTION: One line saying what the script does
#VERSION: 1.0.0
#OS: AL2, AL2023, Ubuntu22, Ubuntu24, Rhel9, Rhel8, Rocky9, Rocky8
#PACKAGES: package names required on the AMI, or the reason none are needed
#
# ‹filename› — AWS PCS node lifecycle action (community example)
#
# ‹prose: what it does, what it demonstrates, edge cases worth a NOTE›
#
# Prerequisites: ‹packages or state the AMI must already provide, or "none"›
# IAM: ‹exact permissions, or "none"›
# Suggested execution policy: ‹EVERY_BOOT | FIRST_BOOT_ONLY› (‹why›)
# Suggested onError: ‹CONTINUE | STOP_SEQUENCE | TERMINATE› (‹why›)
#
# Usage: ‹one line›
```

- **`SPDX-License-Identifier: MIT-0`**, not `Apache-2.0`. The repository `LICENSE` is
  MIT No Attribution. The AWS-maintained scripts use Apache-2.0; do not copy that.
- **`#OS:` lists only the operating systems you designed and checked the script for.**
  It is a claim, not boilerplate. Do not widen it to match another script.
- **`Suggested execution policy` / `Suggested onError` are required**, with the reason
  in parentheses. The AWS-maintained scripts omit these; ours do not. They are the two
  settings a user must choose when wiring the script up, and choosing wrong gives
  either a silent no-op or a node-replacement loop.
- **`usage()` is an explicit `cat <<'USAGE'` heredoc.** Do NOT re-derive help text from
  the header with `sed -n 'N,Mp' "$0"`. That pattern was removed because it makes the
  header positionally load-bearing: inserting a line silently changes `--help` output.
  Duplicating a few lines is the cheaper trade.
- **Log helpers carry a timestamp and a level:**

  ```bash
  _ts()  { date +'%Y-%m-%d %H:%M:%S'; }
  log()  { echo "[$(_ts)] [‹script-name›] INFO: $*"; }
  warn() { echo "[$(_ts)] [‹script-name›] WARNING: $*" >&2; }
  die()  { echo "[$(_ts)] [‹script-name›] ERROR: $*" >&2; exit 1; }
  ```

  These run during node bootstrap, where the questions are ordering and stalls, so the
  clock matters. The agent's `executor.log` is timestamped too, so the two interleave.

## Deliberately NOT borrowed from the AWS-maintained scripts

Do not "improve" our scripts toward these; the divergence is a decision.

- **`${VAR:-default}` override seams** on internal paths and constants (AWS labels them
  "Overridable for unit-test isolation; not a customer interface"). Those exist because
  AWS unit-tests its scripts. This namespace has no script unit tests — only ShellCheck
  and a checksum-currency gate — and env vars are not reachable through node lifecycle
  action configuration anyway, so a seam here is indirection with no consumer. When a
  value genuinely needs tuning, add a named flag instead (see
  `set-shared-dir-mode`'s `--wait-seconds`).
- **`#!/bin/bash`** and **`set -euo pipefail`**. Keep `#!/usr/bin/env bash` and the long
  form `set -o errexit -o pipefail -o nounset`.

## Borrowed from the AWS-maintained scripts

- **Bounded waits for boot races.** When a script depends on state another action
  produces (a mount, a service), a missing precondition can be a *timing* miss rather
  than a *configuration* miss. Poll for a bounded time before degrading, so a slow
  predecessor does not turn into a silent no-op. `set-shared-dir-mode` waits
  `--wait-seconds` (default 30) for its path to become a mount point.

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
  `/var/log/amazon/pcs/lifecycle/actions/‹stage›/‹script-name›.log`; never open your own
  log file. Use the `log`/`warn`/`die` helpers from "Required script header shape" so
  every line carries a timestamp, the script name, and a level.
- **No package installation.** Assume prerequisites are baked into the AMI. Detect a missing
  prerequisite and either fail loudly or degrade (per the criticality decision above); document
  required packages in the script header and recipe README.
- **Reference HPC Recipes assets by S3 URI.** Use
  `s3://aws-hpc-recipes/main/recipes/pcs-scripts/‹recipe›/assets/‹script›` in `scriptLocation`
  examples and templates. It keeps the download on the AWS network and needs only
  `s3:GetObject` on the object (the default `pcs-iip-minimal.yaml` instance profile grants it
  via `AmazonS3ReadOnlyAccess`). HTTPS works too but requires outbound internet access.
- **The public bucket is single-Region, and that does not constrain the cluster.** Assets are
  served from `aws-hpc-recipes` in `us-east-1` only, and a node in any Region can fetch them.
  The S3 URI is Region-agnostic; an HTTPS URL keeps the `s3.us-east-1.amazonaws.com` host, so
  do not rewrite that host per Region (this is the opposite of AWS's per-Region
  `aws-pcs-repo-‹region›` buckets, where you do use the cluster's Region).

## When adding a new recipe here

- Follow the standard skeleton (`README.md`, `metadata.yml`, `Makefile`, `assets/`, `docs/`,
  `tests/`); `metadata.yml` uses `type: shell` and tags including `community`.
- Copy `node_lifecycle_demo`'s `Makefile` and `tests/validate.sh` as the starting point — they
  encode the lint/test/checksum loop this namespace expects.
