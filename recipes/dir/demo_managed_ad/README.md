# demo_managed_ad

## Info

This recipes sets up a basic AWS Managed Microsoft AD deployment that can support a demonstration multi-user AWS ParallelCluster environment. 

**Note** This template uses self-signed certificates to enable encrypted LDAP. Consult the documentation to learn [how to secure an AWS Managed Microsoft AD](https://docs.aws.amazon.com/directoryservice/latest/admin-guide/ms_ad_security.html).

## Usage

1. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=managed_adb&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/dir/demo_managed_ad/assets/main.yaml)
2. Follow the instructions in the AWS CloudFormation console. Choose the VPC and subnets where your AWS ParallelCluster deployment will be created. 
3. Monitor the status of the stack. When its status is `CREATE_COMPLETE`, navigate to its **Outputs** tab. You will find several values you can use to create a ParallelCluster instance.

You can include the Output values directly in a cluster configuration, as per the [ParallelCluster documentation](https://docs.aws.amazon.com/parallelcluster/latest/ug/multi-user-v3.html). Alternatively, if you are deploying a cluster with AWS CloudFormation, these values have been exported so you may import them into your template using the `[Fn::Import](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/intrinsic-function-reference-importvalue.html)` intrinsic function. 

**Note** If you wish to import networking configuration directly from an existing CloudFormation stack, you can use the alternative [import template](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=managed_adb&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/dir/demo_managed_ad/assets/main-import.yaml), providing the name of an active HPC Recipes for AWS networking stack.

## Cost Estimate

It will cost approximately $72.00 to run this directory service for a week. 

## Cleaning Up

When you are done using this resource, you can delete it by navigating to the AWS CloudFormation console and deleting the relevant stack. If you have enabled termination protection, you will need to disable it first.
