## Install and Configure Mountpoint for Amazon S3

This recipe installs [Mountpoint for Amazon S3](https://github.com/awslabs/mountpoint-s3) and can configure it to persistently mount one or more Amazon S3 buckets to directories on the cluster. 

## Pre-requisites

1. Your host operating system must use [systemd](https://en.wikipedia.org/wiki/Systemd) for service management. The supported operating systems (see below) all use systemd. 
2. The nodes where you want to mount Amazon S3 buckets must have at least read access to those buckets. 

### Enabling Amazon S3 access

Your cluster head nodes and compute nodes (if you elect to use this recipe there) must have access to the Amazon S3 buckets you want to mount. You can accomplish that either with the AWS ParalllelCluster `S3Access` [configuration option](https://docs.aws.amazon.com/parallelcluster/latest/ug/s3_resources-v3.html) or by attaching an IAM policy, such as `arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess` using the `AdditionalIamPolicies` [configuration option](https://docs.aws.amazon.com/parallelcluster/latest/ug/HeadNode-v3.html#yaml-HeadNode-Iam-AdditionalIamPolicies). 

## Usage

There are two post-install scripts in the assets directory. They are design to work with AWS ParallelCluster [custom bootstrap actions](https://docs.aws.amazon.com/parallelcluster/latest/ug/custom-bootstrap-actions-v3.html). You will need to run both of them on the cluster head node and any compute nodes where you want to mount S3 buckets. 

* `install.sh` - installs Mountpoint for Amazon S3 and prepares the mount point directory.
* `mount.sh` - configures a systemd service that uses Mountpoint for Amazon S3 to mount a bucket to a directory.

 The mount script is parameterizable: `mount.sh BUCKET PATH [OPTIONS]`. You run it once for each bucket you wish to mount on the host system.

### Cluster Head Node

Here is an toy example of mounting bucket `DEMO-BUCKET-NAME` on the cluster head node at `HOST-FILESYSTEM-PATH`.

```yaml
HeadNode:
    CustomActions:
        OnNodeConfigured:
            Sequence:
                - Script1: https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/mountpoint_s3/assets/install.sh
                - Script2: https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/mountpoint_s3/assets/mount.sh
                  Args:
                    - DEMO-BUCKET-NAME
                    - HOST-FILESYSTEM-PATH
```

### Compute Node(s)

Here is an toy example of mounting the same bucket `DEMO-BUCKET-NAME` on some compute nodes in the cluster.

```yaml
Scheduling:
    SlurmQueues:
        - Name: demo
          CustomActions:
            OnNodeConfigured:
                Sequence:
                    - Script1: https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/mountpoint_s3/assets/install.sh
                    - Script2: https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/mountpoint_s3/assets/mount.sh
                    Args:
                        - DEMO-BUCKET-NAME
                        - HOST-FILESYSTEM-PATH
```

### Additional volumes

To mount another bucket at a different path, add an additional instance of `mount.sh` to your `CustomActions`. The mount script is designed to support multiple mounts, so long as the combination of bucket name and path are distinct on the system. 

## Configuring Mountpoint for Amazon S3 mounts

As mentioned earlier, the `mount.sh` script is parameterizable. It accepts up to three arguments. The first is always an Amazon S3 bucket, the second a directory where that bucket should be mounted, and the third are a string of arguments to be passed to the `mount-s3` command. 

The Mountpoint for Amazon S3 user guide is the definitive source for information on [configuring your mount points](https://github.com/awslabs/mountpoint-s3/blob/main/doc/CONFIGURATION.md). 

If you do not pass any arguments to `mount.sh`, it defaults to mounting the designated bucket under the default username and group for an EC2 instance running the selected operating system. This allows the default user access to the files in the bucket, which is presumably the intent. 

Three additional options are set: `--read-only`, `--allow-root`, and  `--debug`. This restricts the mount to read-only, no matter what the S3 or POSIX permissions are, allows the root user to also access the filesystem, and sets the `mount-s3` client to emit debug logging. 

Mountpoint for Amazon S3 gives you a lot of options. Feel free to explore them. In the meantime, let's look at how you might accomplish come common use cases. 

### 1. Mount a public S3 bucket

Add the `--no-sign-request` argument to disable sending AWS credentials.

### 2. Mount a requester-pays bucket

Add the `--requester-pays` argument to acknowledge your account will be billed for data access.

### 3. Enable write access

Override the default `--read-only` configuration. Note that you cannot over-write an object in the bucket. You can delete it and write a new copy. To allow that behavior, enable deletes in the S3 bucket with `--allow-delete`. 

### How to

Pass custom `mount-s3` parameters by adding a third argument to the `mount.sh` script. Here is an example of mounting a public bucket like you might find in the [Registry of Open Data on AWS](https://registry.opendata.aws/).

```yaml
HeadNode:
    CustomActions:
        OnNodeConfigured:
            Sequence:
                - Script1: https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/mountpoint_s3/assets/install.sh
                - Script2: https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/mountpoint_s3/assets/mount.sh
                  Args:
                    - PUBLIC-BUCKET-NAME
                    - /shared/public-data
                    - "--no-sign-request --allow-root --debug"
```

## Operating system support

The recipe is currently validated on the following operating systems:
* Amazon Linux 2
* Amazon Linux 2023
* RHEL8
* RHEL9
* Rocky Linux 8
* Ubuntu 20.04 LTS

Ubuntu 22 can work if you pre-install libfuse2 before running `install.sh`. You could accomplish that with a custom AMI or with your own custom boostrap action script.

## Implementation details

Most of the heavy lifting in this recipe is in configuring each mount to persist between system reboots. 

This is a pretty straightforward process using network fileystems like Amazon FSx for Lustre or Amazon EFS. It's even achievable with other FUSE filesystems. However, `mount-s3` isn't currently designed to be used with common Linux mount configurations. This [may change in the future](https://github.com/awslabs/mountpoint-s3/issues/441) but for the time being, we use `systemd` to automatically run the mount commands. 

Our `mount.sh` script uses the three parameters you can pass to it to generate a systemd service file. It installs that file, enables the service to launch automatically on boot, then starts the service. We generate one service for each combination of bucket name and path. 

Here is an example of one of these service files:

```
[Unit]
Description=Mount s3://DEMO-BUCKET-NAME at /HOST-FILESYSTEM-PATH
Wants=network-online.target
After=cloud-init.target
AssertPathIsDirectory=/HOST-FILESYSTEM-PATH

[Service]
Type=forking
User=ec2-user
Group=ec2-user
ExecStart=/usr/bin/mount-s3 --allow-root --read-only --debug DEMO-BUCKET-NAME /HOST-FILESYSTEM-PATH
ExecStop=/usr/bin/fusermount -u /data

[Install]
WantedBy=default.target
```

Here's what it looks like to interact with that service on one of the cluster hosts:

```
[ec2-user@localhost ~]$ sudo systemctl list-units | grep mountpoint-s3
mountpoint-s3-2283f055.service    loaded    active running   Mount s3://DEMO-BUCKET-NAME at /HOST-FILESYSTEM-PATH
```

The value `2283f055` in the service name is a hash of the bucket and path to allow multiple concurrent services. 

You can interact with this service using standard `systemctl` commands:

* `systemctl status mountpoint-s3-2283f055` - view service status and last lines of its log
* `systemctl restart mountpoint-s3-2283f055` - restart the service
* `systemctl stop mountpoint-s3-2283f055` - stop mounting the bucket to the host directory
* `systemctl start mountpoint-s3-2283f055` - mount the bucket to the host directory
* `systemctl enable mountpoint-s3-2283f055` - make the mount persist across reboots
* `systemctl disable mountpoint-s3-2283f055` - turn off persistent mounting
