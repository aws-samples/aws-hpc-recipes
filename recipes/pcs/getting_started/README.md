# Getting started with AWS PCS

## Info

This recipe supports the [_Getting started with AWS PCS_](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started.html) section of the AWS PCS User Guide. 

## Usage

This section of the AWS PCS user guide contains references to several CloudFormation templates. Follow the directions in the tutorial to use them. 

Follow these links to inspect their source code:
* [`pcs-cluster-sg.yaml`](assets/pcs-cluster-sg.yaml) - Creates a cluster-wide security group for your PCS controller and attached nodes.
* [`pcs-iip-minimal.yaml`](assets/pcs-iip-minimal.yaml) - Creates a minimal IAM instance profile for your PCS compute node groups.
* [`pcs-lt-simple.yaml`](assets/pcs-lt-simple.yaml) - Creates a minimal launch template for PCS compute node groups.
* [`pcs-lt-efs-fsxl.yaml`](assets/pcs-lt-efs-fsxl.yaml) - Creates launch templates for compute node groups that use a shared home (EFS) and a high-speed shared filesystem (FSx for Lustre). The file systems are mounted by node lifecycle actions, not by the launch template.
* [`cluster.yaml`](assets/cluster.yaml) - Complete cluster template that creates its own VPC and networking.
* [`cluster-byovpc.yaml`](assets/cluster-byovpc.yaml) - Complete cluster template that uses an existing VPC instead of creating new networking resources.

You don't have to use a launch template to set the security groups and SSH key pair for a compute node group. You can set the AMI, security groups, and SSH key pair on the compute node group itself, as [instance settings](https://docs.aws.amazon.com/pcs/latest/userguide/working-with_cng_instance-settings.html). The complete cluster templates do this. Use a launch template when you need other Amazon EC2 settings, such as Elastic Fabric Adapter (EFA) network interfaces or capacity reservations.

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
        * For **SlurmVersion** select the Slurm version.
        * For **ManagedAccounting** choose whether to enable accounting.
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
        * For **SlurmVersion** select the Slurm version.
        * For **ManagedAccounting** choose whether to enable accounting.
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

### Shared storage and logging

The cluster mounts two shared file systems on every node using AWS PCS node lifecycle actions, which run when each instance boots:

* `/home` is an [Amazon EFS](https://aws.amazon.com/efs/) file system for user home directories. Files written here are available on all nodes.
* `/shared` is an [Amazon FSx for Lustre](https://aws.amazon.com/fsx/lustre/) file system for high-speed shared data. It is world-writable with the sticky bit set (mode `1777`), so any user can write to it. Run jobs out of `/shared`.

Confirm both are present by running `df -h` on the login node.

The same node lifecycle actions forward instance logs to Amazon CloudWatch Logs under the log group `/aws/pcs/<cluster-id>/lifecycle`, where `<cluster-id>` is the PCS cluster Id from the stack **Outputs**.

The stack also sends three types of cluster logs to CloudWatch Logs. It keeps each type in its own log group for 30 days:

| Log type | Log group | Contents |
|----------|-----------|----------|
| [Scheduler logs](https://docs.aws.amazon.com/pcs/latest/userguide/monitoring_scheduler-logs.html) | `/aws/vendedlogs/pcs/cluster/PCS_SCHEDULER_LOGS/<cluster-id>` | Logs from `slurmctld`, `slurmdbd`, and `slurmrestd` |
| [Job completion logs](https://docs.aws.amazon.com/pcs/latest/userguide/monitoring_job-completion-logs.html) | `/aws/vendedlogs/pcs/cluster/PCS_JOBCOMP_LOGS/<cluster-id>` | One record for each finished Slurm job |
| [Scaling logs](https://docs.aws.amazon.com/pcs/latest/userguide/monitoring_scaling-logs.html) | `/aws/vendedlogs/pcs/cluster/PCS_SCALING_LOGS/<cluster-id>` | Node launches, registrations, terminations, and launch failures |

To set up these log deliveries, the IAM principal that deploys the stack needs permission for the `pcs:AllowVendedLogDeliveryForResource` action. When you delete the stack, CloudFormation deletes these log groups too.

### How the compute node groups are configured

The `login` and `compute-1` compute node groups don't use custom EC2 launch templates. Each one sets [instance settings](https://docs.aws.amazon.com/pcs/latest/userguide/working-with_cng_instance-settings.html) instead, with `LaunchTemplateMode: MANAGED`:

| Instance setting | `login` | `compute-1` |
|------------------|---------|-------------|
| AMI (`AmiId`) | The PCS sample AMI for the Slurm version and architecture you chose | Same as `login` |
| Security groups (`SecurityGroupIds`) | VPC default, cluster, inbound SSH, EFS, and FSx for Lustre | VPC default, cluster, EFS, and FSx for Lustre |
| SSH key pair (`SshKeyName`) | The key pair you chose for **KeyName** | Same as `login` |

With this configuration, compute nodes use Instance Metadata Service Version 2 (IMDSv2). Because the stack sets an SSH key pair, the IAM principal that deploys the stack also needs permission for the `ec2:DescribeKeyPairs` action.

If you update a stack that you created from an earlier version of this template, AWS PCS replaces the nodes in both compute node groups. It waits for running jobs to finish first. The launch templates that the earlier version created are deleted with their nested stack.

### See what each job costs

AWS PCS can split the cost of each Amazon EC2 instance in your cluster across the Slurm jobs that ran on it. This is [split cost allocation data for AWS PCS](https://docs.aws.amazon.com/pcs/latest/userguide/monitoring-cost-allocation.html). It shows the cost of the CPU, memory, and GPU resources that each job requested, and you can total the cost by job, user, Slurm account, queue, compute node group, node, or cluster.

The cluster doesn't need any extra configuration. AWS PCS produces the data for clusters that run Slurm 25.11 or later, so leave **SlurmVersion** at its default (26.05) or choose 25.11. A cluster that runs Slurm 25.05 doesn't produce it.

To see the data:

1. Opt in. Only the management account of an AWS organization, or a standalone account, can opt in, and its choice applies to every member account. Open the [AWS Billing and Cost Management console](https://console.aws.amazon.com/costmanagement/). Choose **Cost Management preferences**. Under **Split cost allocation data**, select **AWS Parallel Computing Service (PCS)**.
2. Create a Cost and Usage Report that includes split cost allocation data, or add it to a report that you already have. You can use a legacy Cost and Usage Report or Cost and Usage Report 2.0 (CUR 2.0) with [AWS Data Exports](https://docs.aws.amazon.com/cur/latest/userguide/what-is-data-exports.html). Split cost allocation data isn't available in AWS Cost Explorer.
3. Run jobs, then look for the split line items in the report.

When you opt in, AWS PCS activates these cost allocation tags. Use them to group the cost data:

| Tag | Value |
|-----|-------|
| `aws:pcs:cluster-name` | The ID of the AWS PCS cluster |
| `aws:pcs:slurm-account` | The Slurm account that the job ran under |
| `aws:pcs:slurm-job-id` | The Slurm job ID |
| `aws:pcs:username` | The user who submitted the job |
| `aws:pcs:queue` | The queue that the job ran in |
| `aws:pcs:compute-node-group` | The compute node group that provided the node |
| `aws:pcs:node-name` | The Slurm node name that ran the job |

To group costs by Slurm account, set **ManagedAccounting** to `enabled` and run jobs under the Slurm accounts that you create. For the Regions where the feature is available and the cases that it doesn't cover, see [View costs by job in AWS billing with split cost allocation data](https://docs.aws.amazon.com/pcs/latest/userguide/monitoring-cost-allocation.html).

### Cleaning Up

When you are done using your PCS cluster, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the stack you created.

**Note** If you have created additional compute node groups or queues in your cluster, beyond the `login` and `compute-1` groups created by the CloudFormation stack, you will need to delete those resources in the PCS console before deleting the CloudFormation stack. 

### Deprecation Notice

Versions of this recipe released prior to 12/17/2024 use an AWS CloudFormation helper to manage the AWS PCS cluster. With the release of official CloudFormation support for PCS, this is no longer necessary. The file [pcs-cfn.yaml](assets/pcs-cfn.yaml), which provides this helper, will be deleted from this recipe on January 17, 2025. 
