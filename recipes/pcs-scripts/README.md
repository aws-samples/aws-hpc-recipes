# pcs-scripts: Community node lifecycle action scripts for AWS PCS

This namespace collects community-contributed scripts for [AWS PCS node lifecycle
actions](https://docs.aws.amazon.com/pcs/latest/userguide/cng-node-lifecycle-actions.html).
A node lifecycle action runs a script at a defined point in a compute node's
lifecycle. The `nodeBootstrapped` stage is one such point, and it's where you'd
mount storage, tune the OS, join a directory, or tag the instance.

## Community scripts vs. AWS-maintained scripts

AWS publishes its own set of maintained scripts for common tasks, and holds them to
a high bar: AWS versions, tests, and maintains them. See
[Use AWS-maintained scripts for node lifecycle actions](https://docs.aws.amazon.com/pcs/latest/userguide/cng-node-lifecycle-actions-vetted-scripts.html)
for the current set. When one of those covers what you need, reach for it first.

The scripts here are something different. They exist to show you how the pieces fit
together, and they follow the [HPC Recipes contribution bar](../../CONTRIBUTING.md):
we review them for general security issues, but we don't test or maintain them.
Treat them as starting points: read them, take them apart, and rework them for your
own environment.

## How node lifecycle actions consume these scripts

You point a lifecycle action at a script through the `scriptLocation` field in your
compute node group configuration, using either an Amazon S3 URI or an HTTPS URL.
Scripts in this repository are published to the public HPC Recipes bucket and work
either way:

```
# HTTPS
https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs-scripts/<recipe>/assets/<script>

# S3 URI
s3://aws-hpc-recipes/main/recipes/pcs-scripts/<recipe>/assets/<script>
```

An S3 reference needs `s3:GetObject` on the object in the node's instance role, plus
a path to Amazon S3. Nodes in a private subnet reach it through an S3 gateway VPC
endpoint. An HTTPS reference needs outbound internet access instead.

Once referenced, a script goes through four steps:

1. **Publish.** The script lands in the bucket under the path above. (For
   contributors, that's any file under a recipe's `assets/` directory.)
2. **Reference.** You set `scriptLocation` to the S3 URI or HTTPS URL. You can also
   pin a `checksum` (a 64-character SHA-256 hex string) so the agent verifies the
   download. Compute it with `sha256sum <script>`; every script here ships a
   companion `.sha256` file.
3. **Run.** The agent runs the script as `root` at the stage you chose, passing your
   `arguments` and honoring `onError` and `executionPolicy`.
4. **Log.** The agent captures stdout and stderr to
   `/var/log/amazon/pcs/lifecycle/actions/<stage>/<script-name>.log`.

For the full configuration reference, see
[Configure node lifecycle actions](https://docs.aws.amazon.com/pcs/latest/userguide/cng-node-lifecycle-actions-configure.html):
`onError`, `executionPolicy`, `scriptCachingPolicy`, checksums, the injected context
variables, and logging.

## Community quality checklist

Scripts contributed to this namespace are expected to meet the bar below. The
`node_lifecycle_demo` scripts are written to it, so they double as reference
implementations. Most of these are review guidance; the ShellCheck requirement is
enforced by CI.

- **Idempotent and reboot-safe.** A script set to `EVERY_BOOT` has to be safe to run
  again and again and land in the same place each time. If it's inherently one-time,
  say so and mark it `FIRST_BOOT_ONLY`. The `PCS_IS_FIRST_BOOT` context variable is
  there when you need to branch on first boot.
- **Portable across the supported operating systems**: Amazon Linux 2, Amazon Linux
  2023, RHEL, Ubuntu, and Rocky Linux. Read `/etc/os-release` rather than assuming a
  distribution.
- **Named-flag arguments.** Take `--flag value` arguments instead of bare positionals,
  and provide `--help`. Document each flag, its default, and whether it's required.
- **Clean, prefixed logging to stdout/stderr.** The agent captures both for you, so
  don't open your own log files. Keep messages consistent and greppable.
- **No package installation.** Assume prerequisites are already on the AMI. If one is
  missing, either fail loudly with a clear message or degrade to best-effort and exit
  0, depending on how critical the action is. Note any packages you depend on.
- **Least-privilege IAM, documented.** When a script calls AWS APIs, list the exact
  permissions the node instance role needs and scope them as tightly as you can.
- **Passes ShellCheck (enforced by CI).** Every script under `recipes/pcs-scripts/`
  must pass [`shellcheck`](https://github.com/koalaman/shellcheck) cleanly at its
  default severity. This one is blocking: a finding fails the build. (Elsewhere in
  the repository, ShellCheck is only advisory.) Run it with `make lint` in the recipe
  directory, or `python -m scripts.validate_shellcheck` from the repository root.
- **Robust shell hygiene.** Start with `#!/usr/bin/env bash` and
  `set -o errexit -o pipefail -o nounset`, and make sure `bash -n` parses the script.
- **Partition safety.** Don't hardcode `arn:aws:` or `amazonaws.com`; derive the
  partition and region at runtime so the script works in AWS GovCloud and China
  Regions too.
- **Integrity.** Ship a companion `<script>.sha256` so users can pin a `checksum`.

## Recipes in this namespace

Browse the subdirectories here, or see the generated [recipes index](../README.md).
If you're new to the pattern, start with `node_lifecycle_demo`.
