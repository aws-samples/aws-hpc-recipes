# Create an S3 Bucket

## Info

This recipe is a trivial example of creating an S3 bucket with CloudFormation. Noe that it does demonstrate use of conditionals to automatically generate a name if one is not provided. 

## Usage

There is only one template in this recipe. Stack creation will fail if the bucket already exists.

* Create an [S3 bucket](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=s3-simple&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/storage/s3_demo/assets/main.yaml)

## Cleaning up

Delete the bucket by deleting the relevant stack. Be aware that bucket contents will not be backed up before deletion. 

## Cost Estimate

There is no up-front cost to create an S3 bucket. However, any data storage or access will be billed as documented at [Amazon S3 pricing](https://aws.amazon.com/s3/pricing/).
