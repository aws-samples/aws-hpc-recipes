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
* [`cluster-byovpc.yaml`](assets/cluster-byovpc.yaml) - Complete cluster template that uses an existing VPC instead of creating new networking resources.

Feel free to use or adapt these basic templates for your own clusters.

## Quick-start Links

You can launch a complete AWS PCS cluster with the same design and capabilities as shown in [_Getting started with AWS PCS_](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started.html) using a CloudFormation quick-create link. 

### Create a PCS cluster with new networking

To create a demonstration PCS cluster with its own VPC and networking:
1. Ensure you have an Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the region where you will work with PCS.
2. Choose the quick-create link that corresponds to the region where you will work with PCS. 
    * `us-east-1` (Virginia, United States) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `us-east-2` (Ohio, United States) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `us-west-2` (Oregon, United States) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-west-2#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `eu-north-1` (Stockholm, Sweden) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=eu-north-1#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `eu-central-1` (Frankfurt, Germany) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=eu-central-1#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `eu-west-1` (Dublin, Ireland) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `eu-west-2` (London, United Kingdom) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=eu-west-2#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `ap-northeast-1` (Tokyo, Japan) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=ap-northeast-1#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `ap-southeast-1` (Singapore) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=ap-southeast-1#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `ap-southeast-2` (Sydney, Australia) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=ap-southeast-2#/stacks/create/review?stackName=get-started-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster.yaml&param_ClientIpCidr=0.0.0.0%2F0)
3. Follow the instructions in the AWS CloudFormation console:
    * (Optional) Customize the stack name.
    * Under **Parameters**
        * For **SlurmVersion** choose any available version of Slurm.
        * For **ManagedAccounting** choose whether to enable accounting. Note that accounting is only supported for Slurm version 24.11 or newer.
        * For **AccountingPolicyEnforcement** choose whether to turn on enforcement of associations, limits, and safe job launching. Note that this requires accounting to be enabled. 
        * For **NodeArchitecture** choose either `x86` or `Graviton` for your login and compute node groups.
        * For **KeyName** choose an SSH key for connecting to the login nodes
        * For **ClientIpCidr**, either leave it as its default value or replace with a more restrictive CIDR range
        * Leave the parameters under **HPC Recipes configuration** as their default values.
    * Under **Capabilities and transforms**
        * Check all three boxes
    * Choose **Create stack**
4. Monitor the status of your stack (e.g. **get-started-cfn**). When its status is `CREATE_COMPLETE`, you can interact with the PCS cluster. 

### Create a PCS cluster in an existing VPC

Use this option if you want to deploy the cluster into an existing VPC, such as corporate networking or shared infrastructure.

**Network requirements:**
* The VPC, public subnet, and private subnet must all be in the same VPC
* The public subnet must have an Internet Gateway (for SSH access to login nodes)
* The private subnet must have a NAT Gateway (for compute nodes to reach AWS APIs)
* The VPC must have DNS hostnames enabled

To create a PCS cluster in your existing VPC:
1. Ensure you have an Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the region where you will work with PCS.
2. Choose the quick-create link that corresponds to the region where you will work with PCS.
    * `us-east-1` (Virginia, United States) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?stackName=get-started-byovpc&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster-byovpc.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `us-east-2` (Ohio, United States) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=get-started-byovpc&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster-byovpc.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `us-west-2` (Oregon, United States) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-west-2#/stacks/create/review?stackName=get-started-byovpc&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster-byovpc.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `eu-north-1` (Stockholm, Sweden) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=eu-north-1#/stacks/create/review?stackName=get-started-byovpc&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster-byovpc.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `eu-central-1` (Frankfurt, Germany) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=eu-central-1#/stacks/create/review?stackName=get-started-byovpc&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster-byovpc.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `eu-west-1` (Dublin, Ireland) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=eu-west-1#/stacks/create/review?stackName=get-started-byovpc&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster-byovpc.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `eu-west-2` (London, United Kingdom) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=eu-west-2#/stacks/create/review?stackName=get-started-byovpc&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster-byovpc.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `ap-northeast-1` (Tokyo, Japan) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=ap-northeast-1#/stacks/create/review?stackName=get-started-byovpc&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster-byovpc.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `ap-southeast-1` (Singapore) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=ap-southeast-1#/stacks/create/review?stackName=get-started-byovpc&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster-byovpc.yaml&param_ClientIpCidr=0.0.0.0%2F0)
    * `ap-southeast-2` (Sydney, Australia) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=ap-southeast-2#/stacks/create/review?stackName=get-started-byovpc&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/getting_started/assets/cluster-byovpc.yaml&param_ClientIpCidr=0.0.0.0%2F0)
3. Follow the instructions in the AWS CloudFormation console:
    * (Optional) Customize the stack name.
    * Under **Parameters**
        * For **VPC ID** choose your existing VPC.
        * For **Public Subnet ID** choose a public subnet in that VPC (must have Internet Gateway access).
        * For **Private Subnet ID** choose a private subnet in that VPC (must have NAT Gateway access).
        * For **SlurmVersion** choose any available version of Slurm.
        * For **ManagedAccounting** choose whether to enable accounting. Note that accounting is only supported for Slurm version 24.11 or newer.
        * For **AccountingPolicyEnforcement** choose whether to turn on enforcement of associations, limits, and safe job launching. Note that this requires accounting to be enabled.
        * For **NodeArchitecture** choose either `x86` or `Graviton` for your login and compute node groups.
        * For **KeyName** choose an SSH key for connecting to the login nodes.
        * For **ClientIpCidr**, either leave it as its default value or replace with a more restrictive CIDR range.
        * Leave the parameters under **HPC Recipes configuration** as their default values.
    * Under **Capabilities and transforms**
        * Check all three boxes
    * Choose **Create stack**
4. Monitor the status of your stack (e.g. **get-started-byovpc**). When its status is `CREATE_COMPLETE`, you can interact with the PCS cluster.

**Note:** The template validates that your subnets belong to the specified VPC. If there's a mismatch, the stack will fail early with a clear error message. 

### Interact with the PCS cluster

You can administer your new cluster using the AWS PCS console, or you can connect to one of its login nodes to run jobs and manage data. Your new CloudFormation stack can help you with this. In the [AWS CloudFormation console](https://console.amazonaws.com/cloudformation/home), choose the stack you have created. Then, navigate to the **Outputs** tab. 

There will be two URLs:
* **PcsConsoleUrl** This is a link to the cluster you created, in the PCS console. Go here to explore the cluster, node group, and queue configuration. 
* **Ec2ConsoleUrl** This link takes you to a filtered view of the EC2 console that shows the instance(s) managed by the `login` node group. Select an instance and choose **Connect**. The instance should be configured to support inbound SSH and Amazon SSM connections in the web browser. 

Once you have connected to a login instance, follow along with the **Getting Started with AWS PCS** tutorial starting at [_Explore the cluster environment in AWS PCS_](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started_explore.html). 

### Cleaning Up

When you are done using your PCS cluster, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the stack you created.

**Note** If you have created additional compute node groups or queues in your cluster, beyond the `login` and `compute-1` groups created by the CloudFormation stack, you will need to delete those resources in the PCS console before deleting the CloudFormation stack. 

### Deprecation Notice

Versions of this recipe released prior to 12/17/2024 use an AWS CloudFormation helper to manage the AWS PCS cluster. With the release of official CloudFormation support for PCS, this is no longer necessary. The file [pcs-cfn.yaml](assets/pcs-cfn.yaml), which provides this helper, will be deleted from this recipe on January 17, 2025. 
