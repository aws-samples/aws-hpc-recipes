# # Amazon FSx for OpenZFS Filesystem with Security Group

## Info

This recipe shows how to use CloudFormation to set up an FSx for OpenZFS filesystem. It also illustrates a way to configure security groups to allow access from AWS ParallelCluster.

## Usage

### Configure a networking stack (optional)

Follow the instructions in the [Large-scale HPC Networking Setup](../../net/hpc_large_scale/README.md) recipe. You only need to do this once per Region you want to deploy clusters and FSx filesystems in.

### Create an FSx filesystem

