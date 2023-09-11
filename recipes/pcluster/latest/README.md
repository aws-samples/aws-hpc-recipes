# ParallelCluster (Latest)

## Info

Create an instance of the latest AWS ParallelCluster release, after configuring a VPC and subnets to host it.

## Usage

### Launch the Cluster

1. Ensure you have an Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the Region where you want to launch your cluster.
2. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=latest-pcluster&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/latest/assets/launch.yaml)
3. Follow the instructions in the AWS CloudFormation console. 
4. Monitor the status of the stack named **latest-pcluster**. When its status is `CREATE_COMPLETE`, navigate to its **Outputs** tab. Find the output named **HeadNodeIp** - this is the public IP address for your cluster login node.

**Note**: This template creates a VPC and subnets. If you wish to use your own networking configuration, launch your cluster using the [alternative CloudFormation template](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=latest-pcluster&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/latest/assets/launch-alt.yaml). 

#### Notes

1. This template selects head node and compute node instance types based on the architecture you choose. Since this is a demonstration, rather than a production cluster, smaller instance types have been selected.
2. Your cluster nodes will have a shared directory mounted at `/shared`. It uses Amazon Elastic Filesystem (EFS), since that is simple to configure and relatively inexpensive. Consider using [more performance-optimized storage](https://docs.aws.amazon.com/parallelcluster/latest/ug/SharedStorage-v3.html#SharedStorage-v3.properties) for production workloads. 

### Access the Cluster

To SSH into the cluster, you will need its public IP (from above). Using your local terminal, connect via SSH like so: `ssh -i KeyPair.pem ec2-user@HeadNodeIp` where `KeyPair.pem` is the path to the EC2 keypair you specified when launcing the cluster and `HeadNodeIp` is the IP address from above. If you chose one of the Ubuntu operating systems for your cluster, the login name may be `ubuntu` rather than `ec2-user`.

You can also use AWS Systems Manager to access the cluster. You can follow the link found in **Outputs > SystemManagerUrl**. Or, you can navigate to the **Instances** panel in the [Amazon EC2 Console](https://console.aws.amazon.com/ec2/home?region=us-east-2#Instances). Find the instance named **HeadNode** - this is your cluster's access node. Select that instance, then choose **Actions** followed by **Connect**. On the **Connect to instance** page, navigate to **Session Manager** then choose **Connect**.

## Cost Estimate

Costs for a cluster created using this recipe will vary depending on the cluster architecture, since different instances types will be selected depending which one you choose. It will also vary based on how many jobs you submit to the cluster, since ParallelCluster can launch instances to run them. Based on on-demand pricing for the relevant instances, it should cost between $10 to $25.00 to run the cluster for a week, submitting a handful of jobs. 

## Cleaning Up

When you are done using your cluster, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the **latest-pcluster** stack. 
