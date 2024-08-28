# # Amazon FSx for OpenZFS Filesystem with Security Group

## Info

This recipe shows how to use CloudFormation to set up an FSx for OpenZFS filesystem. It also illustrates a way to configure security groups to allow access to the filesystem.

## Usage

### Configure a networking stack (optional)

Follow the instructions in the [Large-scale HPC Networking Setup](../../net/hpc_large_scale/README.md) recipe. You only need to do this once per Region you want to deploy clusters and FSx filesystems in.

### Create an FSx filesystem

There is a single template in this recipe. It creates a simple Amazon FSx for OpenZFS filesystem and volume. 

* [Create an OpenZFS filesystem](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=fsx-openzfs&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/fsx_openzfs/assets/main.yaml)

When prompted to choose a VPC and subnet, select the one where you intend to place the majority of your computing. It is possible to access FSx for OpenZFS filesystems from other Availability Zones, but there will be higher latency and additional costs due to cross-zone traffic.

### Use with AWS ParallelCluster

To [connect your FSx filesystem to a ParallelCluster deployment](https://docs.aws.amazon.com/parallelcluster/latest/ug/SharedStorage-v3.html#SharedStorage-v3-FsxOpenZfsSettings), you will need to know the ID for its root volume. You can discover this in the **Outputs** from your newly-created CloudFormation stack as **FSxOpenZFSRootVolumeId**. This and other values are exported, so you can easily import them into other stacks.

You can also find the root volume ID and other details in [Amazon FSx console](https://console.aws.amazon.com/fsx/home) under **File systems**.

```yaml
# Example shared storage configuration
---
SharedStorage:
  - Name: OpenZfs0
    StorageType: FsxOpenZfs
    MountDir: /shared/zfs
    FsxOpenZfsSettings:
      VolumeId: fsvol-0123456789abcdef0
```

You also need to retrieve the `SecurityGroupId` from the CloudFormation stack output and add it to the `HeadNode` and `Scheduling` sections.

```yaml
# Example of allowing head node access
---
HeadNode:
  Networking:
    AdditionalSecurityGroups:
      - sg-0123456789abcdef0
```

## Cost Estimate

The cost to operate an FSx for OpenZFS filesystem will vary based on the capacity and throughput you select. A filesystem configured with the defaults in this template will cost around $7.00 to operate for a week. 

## Cleaning Up

When you are done using this resource, you can delete it by navigating to the AWS CloudFormation console and deleting the relevant stack. If you have enabled termination protection, you will need to disable it first.
