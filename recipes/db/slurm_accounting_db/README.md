# Slurm Accounting Database using Amazon RDS

## Info

This recipe sets up an Amazon RDS database that can support AWS ParallelCluster Slurm Accounting. 

## Usage

1. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=slurm-accounting-db&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/db/slurm_accounting_db/assets/serverless-database.yaml)
2. Follow the instructions in the AWS CloudFormation console. 
3. Monitor the status of the stack named **slurm-accounting-db**. When its status is `CREATE_COMPLETE`, navigate to its **Outputs** tab. You will find several values you can either use to creating an AWS ParallelCluster instance directly, or that you can imoport if you choose to create a cluster using CloudFormation.

For more details on how to use the resulting database resource, consult the [AWS ParallelCluster documentation](https://docs.aws.amazon.com/parallelcluster/latest/ug/tutorials_07_slurm-accounting-v3.html) or the [ParallelCluster with Slurm Accounting Enabled](../../pcluster/slurm_accounting/README.md) recipe. 

## Cost Estimate

It will cost approximately $22.00 to run this database for one week. 

## Cleaning Up

When you are done using this database, you can delete it by navigating to the AWS CloudFormation console and deleting the relevant stack. If you have enabled termination protection, you will need to disable it first.
