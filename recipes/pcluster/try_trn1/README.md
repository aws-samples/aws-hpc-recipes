# Trn1 Test Cluster

## Info

This recipe creates a ParallelCluster system where you can try out Amazon EC2 [Trn1 instances](https://aws.amazon.com/ec2/instance-types/trn1/). The cluster is builds is the same architecture as the one in [Train a model on AWS Trn1 ParallelCluster](https://github.com/aws-neuron/aws-neuron-parallelcluster-samples) and as such can be used to complete the exercises in that repository.

The cluster design includes the following features:

* AWS [Neuron SDK](https://awsdocs-neuron.readthedocs-hosted.com/en/latest/) pre-installed.
* Elastic compute queue featuring Trn1 instances
* High-speed, low-latency networking with Amazon [Elastic Fabric Adapter](https://aws.amazon.com/hpc/efa/) (EFA).
* Performant shared scratch storage (based on Amazon FSx for Lustre) available at `/fsx`.

## Usage

### Validate that you can use Trainium

If you are not sure whether your account can use Trn1 instances, try to launch one in the Amazon EC2 console before using this recipe. If you are unable to, reach out to your account manager to ensure Trainium access is enabled for your account. 

### Launch the Cluster

1. Create a basic HPC networking configuration in a Region and Availability Zone where [Trn1 instances are available](https://aws.amazon.com/ec2/instance-types/trn1/). You can do this manually or using the [net/hpc_basic](https://console.aws.amazon.com/cloudformation/home?region=us-west-2#/stacks/create/review?stackName=basic-networking&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/net/hpc_basic/assets/public-private.yaml) recipe. 
2. Ensure you have an Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the Region where you want to launch your Trn1 cluster.
3. [Launch the cluster template](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=try-trn1&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/try_trn1/assets/launch-alt.yaml)
    * Follow the instructions in the AWS CloudFormation console. When you configure the queue sizes (i.e. `ComputeInstanceMax`), choose a value that is consistent with your service quota. 
4. Monitor the status of the AWS CloudFormation stack. When its status reaches `CREATE_COMPLETE`, navigate to its **Outputs** tab to find information you need to access the cluster.

### Access the Cluster

If you want to use SSH to access the cluster, you will need its public IP (from above). Using your local terminal, connect via SSH like so: `ssh -i KeyPair.pem ubuntu@HeadNodeIp` where `KeyPair.pem` is the path to the EC2 keypair you specified when launcing the cluster and `HeadNodeIp` is the IP address from above. 

You can also use AWS Systems Manager to access the cluster. You can follow the link found in **Outputs > SystemManagerUrl**. Or, you can navigate to the **Instances** panel in the [Amazon EC2 Console](https://console.aws.amazon.com/ec2/home#Instances). Find the instance named **HeadNode** - this is your cluster's access node. Select that instance, then choose **Actions** followed by **Connect**. On the **Connect to instance** page, navigate to **Session Manager** then choose **Connect**.

Once you are on the system, consult the repo [Train a model on AWS Trn1 ParallelCluster](https://github.com/aws-neuron/aws-neuron-parallelcluster-samples) to learn what to do next.

## Cleaning Up

When you are done using your cluster, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the relevant stack. Note that data on the `/fsx` volume will be deleted. If you want to keep it, find the relevant FSx for Lustre volume in the AWS console and back it up.
