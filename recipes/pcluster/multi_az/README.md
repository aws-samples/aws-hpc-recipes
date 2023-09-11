# ParallelCluster with Multiple Availability Zones

## Info

Create an instance of AWS ParallelCluster configured to launch instances in multiple Availability Zones. 

## Usage

### Configure a multi-AZ networking stack

1. Follow the instructions in the [Large-scale HPC Networking Setup](../../net/hpc_large_scale/README.md) recipe. You only need to do this once per Region you want to deploy clusters in. If you named the networking stack something besides **hpc-networking**, make a note of that as you will need it to set up your cluster. 

### Launch the Cluster

1. Ensure you have a Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the Region where you want to launch your cluster.
2. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=multi-az-cluster&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/multi_az/assets/launch.yaml)
3. Follow the instructions in the AWS CloudFormation console. One critical thing to note: The value you enter for **NetworkStackNameParameter** must be the name of your HPC networking stack. Cluster creation will fail if not because our stack imports the public and private subnets from that stack using its name. 
4. Monitor the status of the stack named **multi-az-cluster**. When its status is `CREATE_COMPLETE`, navigate to its **Outputs** tab. Find the output named **HeadNodeIp** - this is the public IP address for your cluster login node.
5. As a test, you can create and submit several batch jobs until all your configured Compute instances have launched. They *may or may not* launch in different availability zones. You can tell by looking at the Availability Zone column in the EC2 instances list. 

**Note**: If you do not wish to import the networking configuration from a stack provided by the **HPC Recipes for AWS** collection. you can use the [alternative CloudFormation template](assets/launch-alt.yaml). 

If you want to learn more about multi-AZ clusters, check out the related article on the [AWS HPC Blog](https://aws.amazon.com/blogs/hpc/multiple-availability-zones-now-supported-in-aws-parallelcluster-3-4/).

### Access the Cluster

If you want to use SSH to access the cluster, you will need its public IP (from above). Using your local terminal, connect via SSH like so: `ssh -i KeyPair.pem ec2-user@HeadNodeIp` where `KeyPair.pem` is the path to the EC2 keypair you specified when launcing the cluster and `HeadNodeIp` is the IP address from above. If you chose one of the Ubuntu operating systems for your cluster, the login name may be `ubuntu` rather than `ec2-user`.

You can also use AWS Systems Manager to access the cluster. Navigate to the **Instances** panel in the [Amazon EC2 Console](https://console.aws.amazon.com/ec2/home?region=us-east-2#Instances). You should see an instance named **HeadNode** - this is your cluster's access node. Select the instance, then choose **Actions** followed by **Connect**. On the **Connect to instance** page, navigate to **Session Manager** then choose **Connect**. A web-based terminal will launch and connect to the instance. 

## Cleaning Up

When you are done using your cluster, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the **latest-pcluster** stack. 

## Cost Estimate

Costs for a cluster created using this recipe will vary depending on the cluster architecture, since different instances types will be selected depending which one you choose. It will also vary based on how many jobs you submit to the cluster, since ParallelCluster can launch instances to run them. Also, there may be some charge from cross-Availability Zone traffic, though it should be nominal. Based on on-demand pricing for the relevant EC2 instances, it should cost between $20 to $40.00 to run this cluster for a week, submitting a handful of jobs each day. 
