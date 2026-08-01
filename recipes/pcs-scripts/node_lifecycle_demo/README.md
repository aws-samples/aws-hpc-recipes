# node_lifecycle_demo: Community node lifecycle action scripts for AWS PCS

![Tags: pcs, lifecycle, community](https://img.shields.io/badge/tags-pcs%20%7C%20lifecycle%20%7C%20community-lightgrey)

## Introduction

This recipe is a worked example of community-contributed scripts for
[AWS PCS node lifecycle actions](https://docs.aws.amazon.com/pcs/latest/userguide/cng-node-lifecycle-actions.html).
A node lifecycle action runs a script at a defined point in a compute node's
lifecycle to get the node ready for work. The recipe ships four small scripts and
walks through how you'd reference them from a compute node group.

It's also a demonstration of the conventions we ask community contributors to
follow; the [namespace README](../README.md) has the full quality checklist. For
common tasks, it's worth checking the
[AWS-maintained scripts](https://docs.aws.amazon.com/pcs/latest/userguide/cng-node-lifecycle-actions-vetted-scripts.html)
first. These examples are here to learn from and adapt.

## The scripts

The four scripts run from simplest to richest. Each one accepts `--help`, takes
named-flag arguments, runs as `root`, and is safe to run more than once.

### 1. `set-cluster-motd-v1.0.0.sh`: reading lifecycle context

Writes a `/etc/motd` banner describing the cluster and node. It's the simplest way
to see the lifecycle context that the PCS agent injects into every script as
environment variables:

| Variable | Contains |
| --- | --- |
| `PCS_CLUSTER_ID` / `PCS_CLUSTER_NAME` | Cluster identifier / name |
| `PCS_COMPUTE_NODE_GROUP_ID` / `PCS_COMPUTE_NODE_GROUP_NAME` | Compute node group identifier / name |
| `PCS_NODE_ID` | Node identifier |
| `PCS_IS_FIRST_BOOT` | `1` on first boot, `0` on subsequent reboots |

It pairs those with instance facts pulled from IMDSv2: instance ID, type, and
Availability Zone. No prerequisites, no IAM. Suggested `EVERY_BOOT`, `onError:
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

### 2. `apply-node-name-tag-v1.0.0.sh`: context + IMDS + IAM

Tags the EC2 instance `Name=<PCS_NODE_ID>` so you can line instances up against PCS
nodes at a glance. It shows three things working together:

1. Context: `PCS_NODE_ID` supplies the tag value.
2. Instance metadata: the EC2 instance ID (needed for the API call) and the Region
   come from IMDSv2, using token-based requests.
3. IAM: the call needs `ec2:CreateTags` on the node's instance.

Tagging here is best-effort. If the AWS CLI isn't on the AMI, or the `CreateTags`
call is denied, the script logs a warning and exits `0` rather than failing the
node. Pair it with `onError: CONTINUE`. Suggested `FIRST_BOOT_ONLY`, since the Name
tag doesn't change.

Flags: `--tag-key KEY` (default `Name`), `--tag-value VALUE` (default
`$PCS_NODE_ID`), `--region REGION` (default from IMDSv2).

The node instance role needs a policy along these lines. Scope `Resource` down
further wherever you can.

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

### 3. `prepare-hpc-node-v1.0.0.sh`: idempotent system tuning

Raises resource limits (open files, processes, locked memory) through a drop-in
under `/etc/security/limits.d/`, applies a couple of network sysctls via
`/etc/sysctl.d/`, and can disable Transparent Huge Pages. It rewrites its drop-in
files on each run instead of appending to them, which is what keeps it safe on
`EVERY_BOOT`. No prerequisites, no IAM. Suggested `EVERY_BOOT`, `onError: TERMINATE`,
on the reasoning that an untuned node may fail jobs.

Flags: `--nofile N` (default `131072`), `--nproc N` (default `65536`),
`--memlock VALUE` (default `unlimited`), `--somaxconn N` (default `65535`),
`--disable-thp`.

### 4. `setup-local-scratch-v1.0.0.sh`: idempotent storage

Finds an instance-store (local NVMe) device, creates a filesystem only if there
isn't one already, mounts it, and sets permissions. It won't reformat a device that
already has a filesystem, and it's a no-op when the mount point is already mounted,
so it's safe on `EVERY_BOOT`. Suggested `onError: CONTINUE`, so that nodes without
local NVMe still start. It identifies the device with `lsblk` (util-linux), so
`nvme-cli` isn't required.

If the AMI has already prepared the instance-store volume, the script leaves it
alone and exits 0. The AWS Deep Learning AMI (DLAMI), for example, mounts the
instance store at `/opt/dlami/nvme` via LVM; the script sees that the device is
already claimed (mounted elsewhere, or part of an LVM/RAID set) and won't reformat
storage that's in use. On those AMIs, use the volume the AMI provides
(such as `/opt/dlami/nvme`) rather than expecting a fresh `/scratch`.

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

Every asset in this recipe is published to the public AWS HPC Recipes bucket, and
you can reach it by S3 URI or HTTPS URL. Replace `<script>` with a versioned
filename. The bucket lives in `us-east-1`; use these hosts as-is no matter which
Region your cluster is in.

```
# S3 URI
s3://aws-hpc-recipes/main/recipes/pcs-scripts/node_lifecycle_demo/assets/<script>

# HTTPS URL
https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs-scripts/node_lifecycle_demo/assets/<script>
```

### Verify integrity with a checksum

Each script ships a companion `.sha256` file. Read its hash and set it as the
script's `checksum`, and the PCS agent will verify the download against it:

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
stage. Apply it like this:

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

- `executionPolicy`: `FIRST_BOOT_ONLY` (default) or `EVERY_BOOT`.
- `onError`: `TERMINATE` (default), `STOP_SEQUENCE`, or `CONTINUE`.
- `scriptCachingPolicy` (applies to all scripts): `CACHE_ONCE` (default) or
  `REFRESH_ON_REBOOT`.

Changing a node group's lifecycle configuration only affects new instances, and it
triggers the `DRAIN` strategy so running jobs finish before nodes get replaced.

## Reading the logs

The agent captures each script's stdout/stderr to a per-script log on the node:

```
/var/log/amazon/pcs/lifecycle/actions/nodeBootstrapped/<script-name>.log
```

The agent's own operational log, covering downloads, checksums, and orchestration,
is at `/var/log/amazon/pcs/lifecycle/actions/executor.log`. A node that fails with
`TERMINATE` gets replaced, and its logs go with it, so if you'll want them for a
post-mortem, forward them off-instance first (the AWS-maintained
`configure-cloudwatch-logs.sh` script is one way to do that).

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

Use these scripts as templates for your own. And if you go on to contribute a new
community script to the `pcs-scripts` namespace, work through the quality checklist
in the [namespace README](../README.md): idempotent and portable, named-flag
arguments, clean stdout/stderr logging, no package installation, documented
least-privilege IAM, and a companion `.sha256`.
