# open_shared_dir: Open permissions on a shared filesystem for AWS PCS

![Tags: pcs, lifecycle, community](https://img.shields.io/badge/tags-pcs%20%7C%20lifecycle%20%7C%20community-lightgrey)

## Introduction

This recipe is a small, community-contributed script for
[AWS PCS node lifecycle actions](https://docs.aws.amazon.com/pcs/latest/userguide/cng-node-lifecycle-actions.html).
It opens permissions on an **already-mounted** shared directory so that every
user on the node can read and write to it.

A shared filesystem such as FSx for Lustre or EFS is usually mounted root-owned.
On a single-user "try it out" cluster you often want any user to be able to write
to it (for example `/fsx`) without `sudo`. The AWS-maintained
[`mount-fsx-lustre.sh`](https://docs.aws.amazon.com/pcs/latest/userguide/cng-node-lifecycle-actions-vetted-scripts.html)
action mounts the filesystem but does not change its permissions; this script fills
that gap as a follow-on lifecycle action.

See the [namespace README](../README.md) for the full quality checklist. For common
tasks, also check the
[AWS-maintained scripts](https://docs.aws.amazon.com/pcs/latest/userguide/cng-node-lifecycle-actions-vetted-scripts.html).

> **This script is an example.** It is reviewed for general security but is not
> tested or maintained by AWS. Validate it in your own environment before
> production use.

## The script

### `set-shared-dir-mode-v1.0.0.sh`

Applies a `chmod` mode to a mounted shared directory. It is **ordering-safe**: it
only acts on a real mount point, so if the mount action that provides the directory
has not run yet (or was skipped), it logs a warning and exits `0` rather than
chmod'ing a local directory or failing the node. Because it re-applies the mode on
each run, it is safe on `EVERY_BOOT`.

By default it applies mode `1777` — world-writable with the sticky bit, like `/tmp`,
so users cannot delete each other's files. Pass `--mode 0777` for a plain
`chmod 777` with no sticky bit.

- **Prerequisites:** `coreutils` (`chmod`) and `util-linux` (`mountpoint`) — present
  on supported OSes. No package installation.
- **IAM:** none.
- **Suggested `executionPolicy`:** `EVERY_BOOT` (re-apply after the mount on reboot).
- **Suggested `onError`:** `CONTINUE` (a node should still start if the share is absent).

Flags:

- `--path PATH` — absolute path of the mounted shared directory (**required**), e.g. `/fsx`.
- `--mode MODE` — `chmod` mode to apply (default `1777`).
- `-h`, `--help` — show help and exit.

## Prerequisites

- An AWS PCS cluster and a compute node group you can create or update.
- Compute nodes running the PCS agent **1.5.0-1 or later** (node lifecycle actions
  requirement).
- For S3 references: `s3:GetObject` on the script object in the node instance role.
  Nodes in a private subnet can reach the bucket through an S3 gateway VPC endpoint.
- For HTTPS references: outbound internet access from the nodes.
- A prior lifecycle action that mounts the shared directory this script targets
  (for example the AWS-maintained `mount-fsx-lustre.sh` action). Order this script
  **after** that mount in the same stage.

## Referencing the script

Every asset in this recipe is published to the public AWS HPC Recipes bucket and is
reachable by S3 URI or HTTPS URL. The bucket lives in `us-east-1`; use these hosts
as-is regardless of your cluster's Region.

```
# S3 URI
s3://aws-hpc-recipes/main/recipes/pcs-scripts/open_shared_dir/assets/set-shared-dir-mode-v1.0.0.sh

# HTTPS URL
https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs-scripts/open_shared_dir/assets/set-shared-dir-mode-v1.0.0.sh
```

### Verify integrity with a checksum (recommended for production)

The script ships a companion `.sha256` file. Read its hash and set it as the
script's `checksum` so the PCS agent verifies integrity on download:

```bash
curl -fsSL https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs-scripts/open_shared_dir/assets/set-shared-dir-mode-v1.0.0.sh.sha256
# -> <64-char-hex>  set-shared-dir-mode-v1.0.0.sh
```

## Wiring the script into a compute node group

Add it to the `nodeBootstrapped` stage **after** the action that mounts the shared
directory. For example, alongside the AWS-maintained `mount-fsx-lustre.sh`:

```json
{
  "scriptCachingPolicy": "CACHE_ONCE",
  "stages": {
    "nodeBootstrapped": [
      {
        "name": "mount-fsx-lustre",
        "scriptSource": {
          "scriptLocation": "s3://aws-pcs-repo-us-east-2/aws-pcs-node-lifecycle-scripts/mount-fsx-lustre-v1.0.0.sh"
        },
        "arguments": ["--fsx-dns-name", "fs-0123.fsx.us-east-2.amazonaws.com", "--mount-name", "abcdefgh", "--mount-point", "/fsx"],
        "onError": "CONTINUE",
        "executionPolicy": "EVERY_BOOT"
      },
      {
        "name": "set-shared-dir-mode",
        "scriptSource": {
          "scriptLocation": "s3://aws-hpc-recipes/main/recipes/pcs-scripts/open_shared_dir/assets/set-shared-dir-mode-v1.0.0.sh"
        },
        "arguments": ["--path", "/fsx", "--mode", "1777"],
        "onError": "CONTINUE",
        "executionPolicy": "EVERY_BOOT"
      }
    ]
  }
}
```

Apply it with:

```bash
aws pcs update-compute-node-group \
  --cluster-identifier my-cluster \
  --compute-node-group-identifier my-cng \
  --node-lifecycle-actions file://node-lifecycle-actions.json
```

Changing a node group's lifecycle configuration affects only **new** instances and
triggers the `DRAIN` strategy so running jobs finish before nodes are replaced.

## Reading the logs

The agent captures the script's stdout/stderr to a per-script log on the node:

```
/var/log/amazon/pcs/lifecycle/actions/nodeBootstrapped/set-shared-dir-mode.log
```

The agent's own operational log (download, checksum, orchestration) is at
`/var/log/amazon/pcs/lifecycle/actions/executor.log`.

## Testing this recipe

From the recipe directory:

```bash
make lint    # shellcheck + yamllint
make test    # tests/validate.sh: syntax, shellcheck, metadata, partition safety, checksums
```

If you modify the script, regenerate its checksum:

```bash
make checksums
```
