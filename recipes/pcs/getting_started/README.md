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

You can launch a complete AWS PCS cluster with the same design and capabilities as shown in [_Getting started with AWS PCS_](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started.html) using a CloudFormation quick-create link. 

### Create a PCS cluster

To create a demonstration PCS cluster:
1. Ensure you have an Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the region where you will work with PCS.
2. Choose the quick-create link that corresponds to the region where you will work with PCS. 
    * `us-east-1` (Virginia, United States) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `us-east-2` (Ohio, United States) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `us-west-2` (Oregon, United States) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-west-2#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `eu-north-1` (Stockholm, Sweden) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=eu-north-1#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `eu-central-1` (Frankfurt, Germany) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=eu-central-1#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `eu-west-1` (Dubin, Ireland) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `ap-northeast-1` (Tokyo, Japan) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=ap-northeast-1#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `ap-southeast-1` (Singapore) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=ap-southeast-1#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `ap-southeast-2` (Sydney, Australia) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=ap-southeast-2#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
3. Follow the instructions in the AWS CloudFormation console:
    * (Optional) Customize the stack name.
    * Under **Parameters**
        * For **KeyName** choose an SSH key for connecting to the login nodes
        * Leave **AmiId** empty
        * For **ClientIpCidr**, either leave it as its default value or replace with a more restrictive CIDR range
        * Leave the parameters under **HPC Recipes configuration** as their default values.
    * Under **Capabilities and transforms**
        * Check all three boxes
    * Choose **Create stack**
4. Monitor the status of your stack (e.g. **get-started-cfn**). When its status is `CREATE_COMPLETE`, you can interact with the PCS cluster. 

### Interact with the PCS cluster

You can administer your new cluster using the AWS PCS console, or you can connect to one of its login nodes to run jobs and manage data. Your new CloudFormation stack can help you with this. In the [AWS CloudFormation console](https://console.amazonaws.com/cloudformation/home), choose the stack you have created. Then, navigate to the **Outputs** tab. 

There will be two URLs:
* **PcsConsoleUrl** This is a link to the cluster you created, in the PCS console. Go here to explore the cluster, node group, and queue configuration. 
* **Ec2ConsoleUrl** This link takes you to a filtered view of the EC2 console that shows the instance(s) managed by the `login` node group. Select an instance and choose **Connect**. The instance should be configured to support inbound SSH and Amazon SSM connections in the web browser. 

Once you have connected to a login instance, follow along with the **Getting Started with AWS PCS** tutorial starting at [_Explore the cluster environment in AWS PCS_](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started_explore.html). 

### Cleaning Up

When you are done using your PCS cluster, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the stack you created.

**Note** If you have created additional compute node groups or queues in your cluster, beyond the `login` and `compute-1` groups created by the CloudFormation stack, you will need to delete those resources in the PCS console before deleting the CloudFormation stack. 
