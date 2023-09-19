# Try HPC Recipes for AWS: Recipe 2

## Info

This recipe demonstrates setting up foundational resources using other recipes, then using CloudFormation stack imports to simplify connecting them to the HPC cluster.

## Directions

Start by setting up the dependencies:

1. Create a simple HPC-ready VPC configuration using [net/hpc_basic](../../net/hpc_basic/). Take note of the name of your networking stack, since you will need it later. 
2. Make an S3 bucket with the [storage/s3_demo](../../storage/s3_demo/) recipe. Note the name of the bucket. 
3. Now, launch an Amazon FSx for Lustre filesystem with using the alternative ["import template"](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=fsxl-dra&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/fsx_lustre_s3_dra/assets/perisistent-dra-import.yaml). Give it the name the S3 bucket provisioned in step 2, formatted as an S3 URL, for **DataRepositoryPath**. Enter the name of your networking stack in **NetworkStackNameParameter**. When the FSx for Lustre stack has been created, you can proceed to the next step.  

Launch the cluster:

* Choose [Launch stack](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=try-recipes-2&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/training/try_recipes_2/assets/import.yaml)
* Select an operating system, system architecture, and maximum number of compute instances to launch. 
* Enter the name of your networking stack into **NetworkStackNameParameter**.
* Enter the name of your FSx for Lustre storage stack into **StorageStackNameParameter**
* Finish launching the cluster stack and wait until its status reaches `CREATE_COMPLETE`. 
* Consult its outputs tab to find **SystemManagerUrl**. Navigate to that address to log into the system using a web terminal. 

Once you are on the system you can inspect its queues, install software, run jobs, and so on. 

## Cleaning up

1. Delete your cluster stack. When that has finished, delete the storage stack. Then, delete your s3 stack. Finally, delete your networking stack. 
