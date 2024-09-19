# Getting started with AWS PCS

## Info

This recipe supports the [_Getting started with AWS PCS_](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started.html) section of the AWS PCS User Guide. 

## Usage

This section of the AWS PCS user guide contains references to several CloudFormation templates. Follow the directions in the tutorial to use them. 

Follow these links to inspect their source code:
* [`pcs-cluster-sg.yaml`](assets/pcs-cluster-sg.yaml) - Creates a cluster-wide security group for your PCS controller and attached nodes.
* [`pcs-iip-minimal.yaml`](assets/pcs-iip-minimal.yaml) - Creates a minimal IAM instance profile for your PCS compute node groups.
* [`pcs-lt-simple.yaml`](assets/pcs-lt-simple.yaml) - Creats a minimal launch template for PCS compute node groups.
* [`pcs-lt-efs-fsxl.yaml`](assets/pcs-lt-efs-fsxl.yaml) - Creates launch templates with a shared home (EFS) and high-speed storage filesystem (FSx for Lustre).

Feel free to use or adapt these basic templates for your own clusters.

## Quick-start Links

You can launch a complete AWS PCS cluster with the exact same design as shown in [_Getting started with AWS PCS_](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started.html) using a CloudFormation quick-create link. 

To create a demonstration PCS cluster:
1. Ensure you have an Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the Region where you will try PCS.
2. Choose the quick-create link that corresponds to the region where you will try PCS. 
    * `us-east-1` (Virginia, United States) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?stackName=get-started&templateURL=https://aws-hpc-recipes-dev.s3.us-east-1.amazonaws.com/cfn/recipes/pcs/getting_started/assets/cluster.yaml&param_HpcRecipesS3Bucket=aws-hpc-recipes-dev&param_HpcRecipesBranch=cfn&ClientIpCidr=0.0.0.0%2F0)
    * `us-east-2` (Ohio, United States) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=get-started&templateURL=https://aws-hpc-recipes-dev.s3.us-east-1.amazonaws.com/cfn/recipes/pcs/getting_started/assets/cluster.yaml&param_HpcRecipesS3Bucket=aws-hpc-recipes-dev&param_HpcRecipesBranch=cfn&ClientIpCidr=0.0.0.0%2F0)
    * `us-west-2` (Oregon, United States) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-west-2#/stacks/create/review?stackName=get-started&templateURL=https://aws-hpc-recipes-dev.s3.us-east-1.amazonaws.com/cfn/recipes/pcs/getting_started/assets/cluster.yaml&param_HpcRecipesS3Bucket=aws-hpc-recipes-dev&param_HpcRecipesBranch=cfn&ClientIpCidr=0.0.0.0%2F0)
    * `eu-north-1` (Stockholm, Sweden) ![Launch](../../../docs/media/launch-stack.svg)
    * `eu-central-1` (Frankfurt, Germany) ![Launch](../../../docs/media/launch-stack.svg)
    * `eu-west-1` (Dubin, Ireland) ![Launch](../../../docs/media/launch-stack.svg)
    * `ap-northeast-1` (Tokyo, Japan) ![Launch](../../../docs/media/launch-stack.svg)
    * `ap-southeast-1` (Singapore) ![Launch](../../../docs/media/launch-stack.svg)
    * `ap-southeast-2` (Sydney, Australia) ![Launch](../../../docs/media/launch-stack.svg)
3. Follow the instructions in the AWS CloudFormation console.
4. Monitor the status of the stack named **get-started**. When its status is `CREATE_COMPLETE`, navigate to its **Outputs** tab. Find the output named **HeadNodeIp** - this is the public IP address for your cluster login node.

