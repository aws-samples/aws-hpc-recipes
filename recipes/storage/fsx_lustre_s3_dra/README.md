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
* Use this quick-launch link to create a [Persistent Filesystem with DRA](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=fsxl-dra&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/fsx_lustre_s3_dra/assets/perisistent-dra.yaml)

The key difference between this template and the read-only version is in resource `FSxLDra`, where we create both an `AutoExportPolicy` and an `AutoImportPolicy`, rather than just an `AutoImportPolicy`.

## Cost Estimate

The cost to operate the FSx for Lustre filesystem will vary based on the capacity and throughput you select. For reference, a 1.2 TB, 1000 MB/s/TiB persistent filesystem will cost around $90.00 to operate for a week. 

## Cleaning Up

When you are done using this resource, you can delete it by navigating to the AWS CloudFormation console and deleting the relevant stack. If you have enabled termination protection, you will need to disable it first.
