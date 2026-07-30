# pcs-scripts: Community node lifecycle action scripts for AWS PCS

This namespace hosts **community-contributed scripts** for [AWS PCS node lifecycle
actions](https://docs.aws.amazon.com/pcs/latest/userguide/cng-node-lifecycle-actions.html).
Node lifecycle actions let you run custom scripts at defined points in a compute node's
lifecycle (for example, the `nodeBootstrapped` stage) to prepare nodes for work — mounting
storage, tuning the OS, joining a directory, tagging the instance, and so on.

## Community scripts vs. AWS-maintained scripts

AWS publishes a set of **maintained (vetted) scripts** for common tasks, held to a **high**
bar: AWS versions, tests, and maintains them. See
[Use AWS-maintained scripts for node lifecycle actions](https://docs.aws.amazon.com/pcs/latest/userguide/cng-node-lifecycle-actions-vetted-scripts.html)
for the current set. **If an AWS-maintained script covers your need, prefer it.**

The scripts in this namespace **supplement** that set. They are held to the standard
[HPC Recipes contribution bar](../../CONTRIBUTING.md): we review contributions for general
security issues, **but we do not test or maintain them**. Use them as starting points and
examples, and validate them against your own environment before production use.

## How node lifecycle actions consume these scripts

You reference a script by its **Amazon S3 URI** or **HTTPS URL** in the `scriptLocation`
field of a lifecycle action in your compute node group configuration. Scripts in this
repository are published to the public HPC Recipes bucket and are reachable both ways:

```
# HTTPS
https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs-scripts/<recipe>/assets/<script>

# S3 URI
s3://aws-hpc-recipes/main/recipes/pcs-scripts/<recipe>/assets/<script>
```

For an S3 reference, the node's instance role needs `s3:GetObject` on the object, and the
node must be able to reach Amazon S3 — nodes in a private subnet can do so through an S3
gateway VPC endpoint. For an HTTPS reference, the node needs outbound internet access.

The **publish → reference → run → log** loop:

1. **Publish** — the script lands in the bucket under the path above (contributors: it is
   any file under a recipe's `assets/` directory).
2. **Reference** — set `scriptLocation` to the S3 URI or HTTPS URL. Optionally pin a
   `checksum` (64-character SHA-256 hex) so the agent verifies integrity on download.
   Compute it with `sha256sum <script>`; each script here ships a companion `.sha256` file.
3. **Run** — the agent runs the script as `root` at the stage you choose, passing your
   `arguments` and honoring `onError` and `executionPolicy`.
4. **Log** — the agent captures the script's stdout/stderr to
   `/var/log/amazon/pcs/lifecycle/actions/<stage>/<script-name>.log`.

See [Configure node lifecycle actions](https://docs.aws.amazon.com/pcs/latest/userguide/cng-node-lifecycle-actions-configure.html)
for the full configuration reference (`onError`, `executionPolicy`, `scriptCachingPolicy`,
checksums, the injected context variables, and logging).

## Community quality checklist

Every script contributed to this namespace should meet this bar. The scripts in the
`node_lifecycle_demo` recipe are written to it, so read them as reference implementations of
each point below. Most items are review guidance; one is **enforced by CI** and is called
out below.

- **Idempotent and reboot-safe.** A script set to `EVERY_BOOT` must be safe to run repeatedly
  and converge to the same result. If a script is inherently one-time, document that it is
  intended for `FIRST_BOOT_ONLY`. Use the `PCS_IS_FIRST_BOOT` context variable to branch
  when needed.
- **Portable across supported operating systems** — Amazon Linux 2, Amazon Linux 2023, RHEL,
  Ubuntu, and Rocky Linux. Detect the OS via `/etc/os-release`; do not assume a distribution.
- **Named-flag arguments.** Accept `--flag value` style arguments (not bare positionals) and
  provide `--help`. Document every flag, its default, and whether it is required.
- **Clean, prefixed logging to stdout/stderr.** The agent captures stdout/stderr for you —
  do not manage your own log files. Emit consistent, greppable messages.
- **No package installation.** Assume prerequisites are baked into the AMI. Detect missing
  prerequisites and either fail loudly (with a clear message) or degrade to best-effort and
  exit 0, depending on the action's criticality. Document required packages.
- **Least-privilege IAM, documented.** If the script calls AWS APIs, list the exact
  permissions the node instance role needs, scoped as tightly as possible.
- **Passes ShellCheck — REQUIRED (enforced by CI).** Every script under
  `recipes/pcs-scripts/` **must** pass [`shellcheck`](https://github.com/koalaman/shellcheck)
  cleanly at its default severity. This is a blocking check: a finding fails the build. (For
  scripts elsewhere in this repository, ShellCheck is advisory only.) Run it locally with
  `make lint` in the recipe directory, or `python -m scripts.validate_shellcheck` from the
  repository root.
- **Robust shell hygiene.** Start with `#!/usr/bin/env bash` and
  `set -o errexit -o pipefail -o nounset`, and confirm `bash -n` parses the script.
- **Partition safety.** Do not hardcode `arn:aws:` or `amazonaws.com`; derive the partition
  and region at runtime so scripts work in AWS GovCloud and China Regions.
- **Integrity.** Ship a companion `<script>.sha256` so users can pin a `checksum`.

## Recipes in this namespace

Browse the subdirectories here, or see the generated [recipes index](../README.md). New to
the pattern? Start with `node_lifecycle_demo`.
