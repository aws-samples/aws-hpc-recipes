# node_lifecycle_demo: Community node lifecycle action scripts for AWS PCS

![Tags: pcs, lifecycle, community](https://img.shields.io/badge/tags-pcs%20%7C%20lifecycle%20%7C%20community-lightgrey)

## Introduction

This recipe is a worked example of **community-contributed scripts for
[AWS PCS node lifecycle actions](https://docs.aws.amazon.com/pcs/latest/userguide/cng-node-lifecycle-actions.html)**.
Node lifecycle actions run custom scripts at defined points in a compute node's
lifecycle so nodes are ready for work. This recipe ships four small, portable,
idempotent scripts and shows how to reference them from a compute node group.

It also demonstrates the conventions we ask community contributors to follow —
see the [namespace README](../README.md) for the full quality checklist. For
common tasks, also check the
[AWS-maintained scripts](https://docs.aws.amazon.com/pcs/latest/userguide/cng-node-lifecycle-actions-vetted-scripts.html).

> **These scripts are examples.** They are reviewed for general security but are
> not tested or maintained by AWS. Validate them in your own environment before
> production use.

## The scripts

The scripts are ordered from simplest to richest. All accept `--help`, use
named-flag arguments, run as `root`, and are safe to run repeatedly.

### 1. `set-cluster-motd-v1.0.0.sh` — reading lifecycle context

Writes a `/etc/motd` banner describing the cluster and node. This is the simplest
demonstration of the **lifecycle context** that the PCS agent injects into every
script as environment variables:

| Variable | Contains |
| --- | --- |
| `PCS_CLUSTER_ID` / `PCS_CLUSTER_NAME` | Cluster identifier / name |
| `PCS_COMPUTE_NODE_GROUP_ID` / `PCS_COMPUTE_NODE_GROUP_NAME` | Compute node group identifier / name |
| `PCS_NODE_ID` | Node identifier |
| `PCS_IS_FIRST_BOOT` | `1` on first boot, `0` on subsequent reboots |

It combines those with instance facts from IMDSv2 (instance ID, type, and
Availability Zone). No prerequisites, no IAM. Suggested `EVERY_BOOT`, `onError:
CONTINUE`.

On Ubuntu, `/etc/motd` is only rendered by `pam_motd` on a true SSH login;
sessions opened with **SSM Session Manager** or `sudo -i` skip that PAM stack and
never see it. So the script also installs a small `/etc/profile.d` drop-in that
prints the banner for interactive login shells that `pam_motd` misses, while
staying quiet on SSH (where it was already shown) to avoid a double banner. Pass
`--no-profile-dropin` to write only `/etc/motd`.

Flags: `--message TEXT` (optional welcome line), `--motd-file PATH` (default
`/etc/motd`), `--profile-dropin PATH` (default `/etc/profile.d/zz-pcs-motd.sh`),
`--no-profile-dropin` (skip the login-shell dispatcher).

### 2. `apply-node-name-tag-v1.0.0.sh` — context + IMDS + IAM

Tags the EC2 instance `Name=<PCS_NODE_ID>` so instances are easy to correlate with
PCS nodes. It shows three things working together:

1. **Context** — `PCS_NODE_ID` supplies the tag value.
2. **Instance metadata** — the EC2 instance ID (needed for the API call) and the
   Region come from **IMDSv2** (token-based).
3. **IAM** — the call needs `ec2:CreateTags` on the node's instance.

Tagging is **best-effort**: if the AWS CLI is not installed on the AMI, or the
`CreateTags` call is denied, the script logs a warning and exits `0`. Pair it with
`onError: CONTINUE`. Suggested `FIRST_BOOT_ONLY` (the Name tag does not change).

Flags: `--tag-key KEY` (default `Name`), `--tag-value VALUE` (default
`$PCS_NODE_ID`), `--region REGION` (default from IMDSv2).

The node instance role needs a policy like the following. Scope `Resource` more
tightly if you can.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TagOwnInstance",
      "Effect": "Allow",
      "Action": "ec2:CreateTags",
      "Resource": "*"
    }
  ]
}
```

### 3. `prepare-hpc-node-v1.0.0.sh` — idempotent system tuning

Raises resource limits (open files, processes, locked memory) via a drop-in under
`/etc/security/limits.d/`, applies network sysctls via `/etc/sysctl.d/`, and can
disable Transparent Huge Pages. It rewrites its drop-in files each run rather than
appending, so it is safe on `EVERY_BOOT`. No prerequisites, no IAM. Suggested
`EVERY_BOOT`, `onError: TERMINATE` (an untuned node may fail jobs).

Flags: `--nofile N` (default `131072`), `--nproc N` (default `65536`),
`--memlock VALUE` (default `unlimited`), `--somaxconn N` (default `65535`),
`--disable-thp`.

### 4. `setup-local-scratch-v1.0.0.sh` — idempotent storage

Finds an instance-store (local NVMe) device, creates a filesystem only if none is
present, mounts it, and sets permissions. It never reformats a device that already
has a filesystem and is a no-op if the mount point is already mounted, so it is
safe on `EVERY_BOOT`. Suggested `onError: CONTINUE` (nodes without local NVMe
should still start).

Flags: `--mount-point PATH` (default `/scratch`), `--fstype FS` (default `ext4`),
`--mode MODE` (default `1777`).

## Prerequisites

- An AWS PCS cluster and a compute node group you can create or update.
- Compute nodes running the PCS agent **1.5.0-1 or later** (node lifecycle actions
  requirement).
- For S3 references: `s3:GetObject` on the script object in the node instance role.
  Nodes in a private subnet can reach the bucket through an S3 gateway VPC endpoint.
- For HTTPS references: outbound internet access from the nodes.
- Per-script prerequisites and IAM as noted above (`apply-node-name-tag` needs the
  AWS CLI on the AMI and `ec2:CreateTags`).

## Referencing the scripts

Every asset in this recipe is published to the public AWS HPC Recipes bucket and is
reachable by S3 URI or HTTPS URL. Replace `<script>` with a versioned filename. The
bucket lives in `us-east-1`; use these hosts as-is regardless of your cluster's Region.

```
# S3 URI
s3://aws-hpc-recipes/main/recipes/pcs-scripts/node_lifecycle_demo/assets/<script>

# HTTPS URL
https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs-scripts/node_lifecycle_demo/assets/<script>
```

### Verify integrity with a checksum (recommended for production)

Each script ships a companion `.sha256` file. Read its hash and set it as the
script's `checksum` so the PCS agent verifies integrity on download:

```bash
curl -fsSL https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs-scripts/node_lifecycle_demo/assets/set-cluster-motd-v1.0.0.sh.sha256
# -> <64-char-hex>  set-cluster-motd-v1.0.0.sh
```

Add the hash to the script's `scriptSource`:

```json
"scriptSource": {
  "scriptLocation": "https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs-scripts/node_lifecycle_demo/assets/set-cluster-motd-v1.0.0.sh",
  "checksum": "<64-char-hex>"
}
```

## Wiring the scripts into a compute node group

[`assets/example-node-lifecycle-actions.json`](assets/example-node-lifecycle-actions.json)
is a ready-to-edit payload that wires all four scripts into the `nodeBootstrapped`
stage. Apply it with:

```bash
aws pcs update-compute-node-group \
  --cluster-identifier my-cluster \
  --compute-node-group-identifier my-cng \
  --node-lifecycle-actions file://example-node-lifecycle-actions.json
```

To reference a script over an **S3 URI** instead of HTTPS, swap the `scriptLocation`:

```json
"scriptLocation": "s3://aws-hpc-recipes/main/recipes/pcs-scripts/node_lifecycle_demo/assets/set-cluster-motd-v1.0.0.sh"
```

Key per-script settings (see
[Configure node lifecycle actions](https://docs.aws.amazon.com/pcs/latest/userguide/cng-node-lifecycle-actions-configure.html)):

- `executionPolicy` — `FIRST_BOOT_ONLY` (default) or `EVERY_BOOT`.
- `onError` — `TERMINATE` (default), `STOP_SEQUENCE`, or `CONTINUE`.
- `scriptCachingPolicy` (applies to all scripts) — `CACHE_ONCE` (default) or
  `REFRESH_ON_REBOOT`.

Changing a node group's lifecycle configuration affects only **new** instances and
triggers the `DRAIN` strategy so running jobs finish before nodes are replaced.

## Reading the logs

The agent captures each script's stdout/stderr to a per-script log on the node:

```
/var/log/amazon/pcs/lifecycle/actions/nodeBootstrapped/<script-name>.log
```

The agent's own operational log (download, checksum, orchestration) is at
`/var/log/amazon/pcs/lifecycle/actions/executor.log`. Because nodes that fail with
`TERMINATE` are replaced, forward these logs off-instance (for example with the
AWS-maintained `configure-cloudwatch-logs.sh` script) if you need them for
post-mortem debugging.

## Testing this recipe

From the recipe directory:

```bash
make lint    # shellcheck + yamllint
make test    # tests/validate.sh: syntax, shellcheck, metadata, partition safety, checksums
```

If you modify a script, regenerate its checksum:

```bash
make checksums
```

## Adapting or contributing

Use these scripts as templates. If you contribute a new community script to the
`pcs-scripts` namespace, follow the quality checklist in the
[namespace README](../README.md): idempotent and portable, named-flag arguments,
clean stdout/stderr logging, no package installation, documented least-privilege
IAM, and a companion `.sha256`.
