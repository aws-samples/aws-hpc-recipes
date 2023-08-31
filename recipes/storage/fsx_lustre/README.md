# Amazon FSx for Lustre Filesystem with Security Group

## Info

This recipe shows how to use CloudFormation to set up an FSx for Lustre filesystem. It also illustrates a way to configure security groups to allow filesystem access from AWS ParallelCluster

## Usage

### Configure a networking stack (optional)

Follow the instructions in the [Large-scale HPC Networking Setup](../../net/hpc_large_scale/README.md) recipe. You only need to do this once per Region you want to deploy clusters and FSx filesystems in.

### Create an FSx filesystem

There are two templates. One creates a "scratch" filesystem, suitable for short-term high-performance storage. The other creates a "persistent" filesystem that is high performance, but also has higher durability. 

* Create a [Scratch Filesystem](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=fsxl-scratch&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/fsx_lustre/assets/scratch.yaml)
* Create a [Persistent Filesystem](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=fsxl-persistent&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/fsx_lustre/assets/persistent.yaml)

When prompted to choose a subnet, select the one where you intend to place the majority of your computing. It is possible to access FSx for Lustre filesystems across Availability Zones, but there will be higher latency and additional costs due to cross-zone traffic.

To connect your FSx filesystem to a ParallelCluster deployment, you will need to know its filesystem ID. You can discover this in the **Outputs** from your newly-created CloudFormation stack. Note that the filesysted ID and the security group are also exported, so you can easily import them into other stacks. You can also find the filesytem ID and other details in [Amazon FSx console](https://console.aws.amazon.com/fsx/home) under **File systems**.

## Cleaning Up

When you are done using your filesystem, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the relevant stack. Note that any data on these filesystems will not be backed up if you do this. 

## Cost Estimate

The cost to operate an FSx for Lustre filesystem will vary based on the capacity and throughput you select. For reference, a 1.2 TB, 1000 MB/s/TiB persistent filesystem will cost around $90.00 to operate for a week. The same capacity scratch filesystem will cost about $42.00. 
