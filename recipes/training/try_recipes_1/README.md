# Try HPC Recipes for AWS: Recipe 1

## Info

This recipe demonstrates setting up foundational resources using other recipes, then manually connecting those resources to an HPC cluster. 

## Directions

Start by setting up the dependencies:

1. Create a simple HPC-ready VPC configuration using [net/hpc_basic](../../net/hpc_basic/).
2. Make an S3 bucket with the [storage/s3_demo](../../storage/s3_demo/) recipe. Make sure it's in the same region as your networking setup.
3. Now, provision an Amazon FSx for Lustre filesystem. This resource will be special because it has a directory that automatically synchronizes with an Amazon S3 bucket. For that, we'll use the bucket from step #2. Launch the [storage/fsx_lustre_s3_sra](../../storage/fsx_lustre_s3_dra/) template. It will prompt you for a VPC, subnet ID, and DataRepositoryPath. For the network details, consult the outputs tab from your networking stack created in step 1. You need the values for **VPC** **DefaultPrivateSubnet**. For the S3 details, look in the outputs from your S3 stack for **BucketName**. Format it as an S3 URL when you enter it into **DataRepositoryPath**. Now, finish launching the stack. 

Now, you can launch the cluster.

* Choose [Launch stack](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=try-recipes-1&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/training/try_recipes_1/assets/manual.yaml)
* Select an operating system, system architecture, and maximum number of compute instances to launch. 
* Next, configure where the cluster instances will launch with outputs from your networking stack. Use the value from **DefaultPublicSubnet** for **HeadNodeSubnetId** and the value from **DefaultPrivateSubnet** for **ComputeNodeSubnetId**. 
* Now, configure the shared filesystem. Look up **FSxLustreFilesystemId** and **FSxLustreSecurityGroupId** in the storage stack and use those values for **FilesystemId** and **FilesystemSecurityGroupId** respectively. 
* Finish launching the stack and wait until its status reaches `CREATE_COMPLETE`. 
* Consult its outputs tab to find **SystemManagerUrl**. Navigate to that address to log into the system using a web terminal. 

Once you are on the system you can inspect its queues, install software, run jobs, and so on. 

## Cleaning up

1. Delete your cluster stack. When that has finished, delete the storage stack. Then, delete your s3 stack. Finally, delete your networking stack. 
