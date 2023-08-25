# ParallelCluster (Latest)

## Info

Create an instance of the latest AWS ParallelCluster release, after configuring a VPC and subnets to host it.

## Usage

### Launch the Cluster

1. Ensure you have a Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the Region where you want to launch your cluster.
2. Launch the template: [![Launch stack](https://raw.githubusercontent.com/buildkite/cloudformation-launch-stack-button-svg/master/launch-stack.svg)](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=latest-pcluster&templateURL=https://cfn3-dev-mwvaughn.s3.us-east-2.amazonaws.com/main/recipes/pcluster/latest/assets/launch.yaml)
3. Follow the instructions in the AWS CloudFormation console. 
4. Monitor the status of the stack named **latest-pcluster**. When its status is `CREATE_COMPLETE`, navigate to its **Outputs** tab. Find the output named **HeadNodeIp** - this is the public IP address for your cluster login node.

### Access the Cluster

If you want to use SSH to access the cluster, you will need its public IP (from above). Using your local terminal, connect via SSH like so: `ssh -i KeyPair.pem ec2-user@HeadNodeIp` where `KeyPair.pem` is the path to the EC2 keypair you specified when launcing the cluster and `HeadNodeIp` is the IP address from above. If you chose one of the Ubuntu operating systems for your cluster, the login name may be `ubuntu` rather than `ec2-user`.

You can also use AWS Systems Manager to access the cluster. Navigate to the **Instances** panel in the [Amazon EC2 Console](https://console.aws.amazon.com/ec2/home?region=us-east-2#Instances). You should see an instance named **HeadNode** - this is your cluster's access node. Select the instance, then choose **Actions** followed by **Connect**. On the **Connect to instance** page, navigate to **Session Manager** then choose **Connect**. A web-based terminal will launch and connect to the instance. 

## Cleaning Up

WHen you are done using your cluster, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the **latest-pcluster** stack. 

## Cost Estimate

Costs for a cluster created using this recipe will vary depending on the cluster architecture, since different instances types will be selected depending which one you choose. It will also vary based on how many jobs you submit to the cluster, since ParallelCluster can launch instances to run them. Based on on-demand pricing for the relevant instances, it should cost between $10 to $25.00 to run the cluster for a week, submitting a handful of jobs. 

