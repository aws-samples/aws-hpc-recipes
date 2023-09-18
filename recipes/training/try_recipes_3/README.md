# Try HPC Recipes for AWS: Recipe 3

## Info

This recipe demonstrates an all-in-one launch template, where networking, storage, and cluster are provisioned in a single template that uses nested CloudFormation stacks. 

## Directions

Launch the cluster:

* Choose [Launch stack](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=try-recipes-3&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/training/try_recipes_3/assets/nested.yaml)
* Select an operating system, system architecture, and maximum number of compute instances to launch. 
* Finish launching the cluster stack and wait until its status reaches `CREATE_COMPLETE`. 
* Consult its outputs tab to find **SystemManagerUrl**. Navigate to that address to log into the system using a web terminal. 

Once you are on the system you can inspect its queues, install software, run jobs, and so on. 

## Cleaning up

1. Delete your cluster stack. Other resources created by this recipe will automatically be deleted. 
