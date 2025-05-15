# Amazon FSx for Lustre Filesystem with an example Data Repository Association

## Info

This recipe shows how to use AWS CloudFormation to set up an Amazon FSx for Lustre filesystem backed by a Data Repository Association.

## Usage

Before you start, there are two items to be aware of:

1. The FSx for Lustre file system and the linked S3 bucket to be [in the same region](https://docs.aws.amazon.com/fsx/latest/LustreGuide/autoimport-data-repo-dra.html#auto-import-prereqs-dra). 
2. In **Networking and Access*, select the subnet ID where the majority of your compute instances will launch. If you don't have a preference, that's OK, too. This is important to minimize cross-AZ traffic to your EC2 instances.
3. To connect your new FSx filesystem to a ParallelCluster deployment, you will need its filesystem ID. You can discover this in the **Outputs** from this newly-created CloudFormation stack. Note that the filesysted ID and the security group are also exported, so you can easily import them into other stacks. You can also find the filesytem ID and other details in [Amazon FSx console](https://console.aws.amazon.com/fsx/home) under **File systems**.

### Create an FSx filesystem with a DRA

By default, this template will create a bidirectional DRA. That means that files you add to/change/delete from the Lustre filesystem will show up in S3 and vice versa. The template gives you an option to *Create a read-only DRA*. This will make the DRA unidirectional, where changes to the S3 resource will show up in Lustre, but not the other way around. This is implemented with a CloudFormation conditional that creates the DRA with or without an `AutoExportPolicy`. 

* Switch to the region where your source S3 bucket exists.
* Use this quick-launch link to create a [Persistent Filesystem with DRA](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=fsxl-dra&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/fsx_lustre_s3_dra/assets/persistent-dra.yaml)

The key difference between this template and the read-only version is in resource `FSxLDra`, where we create both an `AutoExportPolicy` and an `AutoImportPolicy`, rather than just an `AutoImportPolicy`.

### FSx for Lustre Automated Release Tasks

This repository contains also CloudFormation templates to automate the release of files from FSx for Lustre file systems. Two different release strategies are available:

#### 1. Time-Based Release Task

Automatically releases files that haven't been accessed for a specified period, helping to optimize storage usage.

When files haven't been accessed for the specified timeframe, they are [released](https://docs.aws.amazon.com/fsx/latest/LustreGuide/release-files-task.html) from the file system but remain in the S3 bucket. Subsequent access attempts automatically retrieve the files from S3 back to the file system.

**Features**
- Configurable Lambda function that scans the file system periodically
- Customizable file access age threshold
- Configurable scan frequency
- Files remain available in S3 and are automatically retrieved when accessed

If you want to use this template:

1. Ensure you're in the AWS region where your source S3 bucket exists
2. Deploy using this quick-launch link: [Time-based release task](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=fsxl-timebased-release&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/fsx_lustre_s3_dra/assets/fsxl-time_based-release.yaml)

#### 2. Space-Based Release Task

Monitors available file system space and automatically releases files when space becomes constrained.

The system monitors the available file system space through CloudWatch. When free space falls below the configured threshold, it triggers a Lambda function that releases files based on their last access time.

**Features**

- Configurable free space threshold
- CloudWatch event-driven architecture
- Customizable file access age for release criteria
- Automatic file release when space threshold is reached

If you want to use this template:

1. Ensure you're in the AWS region where your source S3 bucket exists
2. Deploy using this quick-launch link: [Space-based release task](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=fsxl-spacebased-release&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/fsx_lustre_s3_dra/assets/fsxl-space_based-release.yaml)

#### Note

Both templates are optional and can be used independently or together based on your storage management needs.

### Use with AWS ParallelCluster

Add the new FSx for Lustre filesystem to your ParallelCluster deployment with an entry in the `SharedStorage` configuration section. 

```yaml
# Example shared storage configuration
---
SharedStorage:
  - Name: FsxLustre0
    StorageType: FsxLustre
    MountDir: /shared/fsx
    FsxLustreSettings:
      VolumeId: fs-0123456789abcdef0
```

You also need to retrieve `FSxLustreSecurityGroupId` from the CloudFormation stack output and add its value the `HeadNode` and `Scheduling` sections.

```yaml
# Example of allowing head node access
---
HeadNode:
  Networking:
    AdditionalSecurityGroups:
      - sg-0123456789abcdef0
```

### Testing It Out

1. Upload files to the source S3 bucket (if it doesn't already have some in it). 
2. Log into your ParallelCluster system. The files in your S3 bucket should be visible when you list the shared storage mount directory for the FSx for Lustre resource. 
3. Now, create some files on the cluster in the mount directory. 
4. View the contents of the S3 bucket using the AWS CLI/SDK or the AWS S3 Console. The new files should be visible there.
5. Delete or rename some files on either side (S3 or FSx) - the changes should propagate quickly between systems.

## Cost Estimate

The cost to operate the FSx for Lustre filesystem will vary based on the capacity and throughput you select. For reference, a 1.2 TB, 1000 MB/s/TiB persistent filesystem will cost around $90.00 to operate for a week. 

## Cleaning Up

When you are done using this resource, you can delete it by navigating to the AWS CloudFormation console and deleting the relevant stack. If you have enabled termination protection, you will need to disable it first.
