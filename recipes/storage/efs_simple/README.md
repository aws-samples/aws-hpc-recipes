# Amazon EFS Filesystem with Security Group

## Info

This recipe shows how to use CloudFormation to set up an EFS filesystem, along with mount targets in three Availability Zones. It also shows one way to configure a security group to allow filesystem access from AWS ParallelCluster.

## Usage

### Configure a networking stack (optional)

Follow the instructions in the [Large-scale HPC Networking Setup](../../net/hpc_large_scale/README.md) recipe. This will help ensure you have subnets configured in multiple Availablity Zones. You only need to do this once per Region you want to deploy clusters and their associated resources in. 

### Create an EFS filesystem

There is only one template in this recipe, whichj creates a simple EFS filesystem. 

* Create an [EFS Filesystem](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=efs-simple&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/efs_simple/assets/main.yaml)

### Use with AWS ParallelCluster

To use this filesystem as shared storage on a ParallelCluster system:

1. Make sure the HeadNode and ComputeResource nodes launch in the same VPC as your EFS. 
2. Retrieve `EFSFilesystemId` from your CloudFormation stack outputs or by inspecting the filesystem directly in the [EFS Console](https://console.aws.amazon.com/efs).  Use it for the `FileSystemId` in the `SharedStorage` section of your cluster configuration.

```yaml
# Example shared storage
---
SharedStorage:
  - Name: Efs0
    StorageType: Efs
    MountDir: /shared/efs
    EfsSettings:
      FileSystemId: fs-0123456789abcdef0
```

3. Also, retrieve the `SecurityGroupId` from the CloudFormation stack output and add it to the `HeadNode` and `Scheduling` sections.

```yaml
# Example of allowing head node access
---
HeadNode:
  Networking:
    AdditionalSecurityGroups:
      - sg-0123456789abcdef0
```

## Cost Estimate

There is no upfront cost to create and operate an EFS filesystem. However, there can be charges based on how much data you store in it and what your access pattern is. For reference, a 100 GB EFS filesystem should cost around $1.00 to run for a week. 

## Cleaning Up

When you are done using this resource, you can delete it by navigating to the AWS CloudFormation console and deleting the relevant stack. If you have enabled termination protection, you will need to disable it first.
