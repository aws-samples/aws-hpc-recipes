# ParallelCluster with Login Nodes

## Info

This recipe demonstrates the new Login Nodes feature in ParallelCluster 3.7.0.

## Usage

### Launch the Cluster

1. Ensure you have an Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the Region where you want to launch your cluster.
2. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=login-nodes&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/login_nodes/assets/launch.yaml)
3. Follow the instructions in the AWS CloudFormation console. 
4. Monitor the status of the stack named **latest-pcluster**. When its status is `CREATE_COMPLETE`, you can log into the cluster. 

### Access the Cluster

SSH access works differently in clusters configured with Login Nodes. Rather than directly connecting to the head node, it is expected you will connect to a pool of login nodes. These have the same general configuration as the head node, including job submission and management rights, but are not responsible for running the scheduler or the default shared filesystem. This approach keeps the head node from getting overloaded with user processes. In the configuration we demonstrate here, the head node is not even publicly accessible!

1. Retrieve the address for the cluster's Elastic Load Balancer. You can do this by looking for **LoginNodesAddress** in the stack outputs. You can also find it in the EC2 console under **Loading Balancing > Load Balancers**. 
2. Connect to the system via SSH using the key you provided. Here's an example:

```shell
ssh -i mykey.pem ec2-user@login-nodes-ABCDEFG-abcdef0123456789.elb.us-east-2.amazonaws.com
```

You can also log directly into specific login node instances. Navigate to the EC2 console and look for instances named `LoginNode`. You can find their public IPv4 address and DNS name there. Log into them with the same SSH key you used above. 

Finally, even though it is not publicly accessible, you can use AWS Systems Manager to access the cluster head node. Follow the link found in **Outputs > SystemManagerUrl**. You can also log in via SSM from the EC2 console. 

## Cost Estimate

Costs for a cluster created with this recipe will vary depending on the cluster architecture, since different instances types will be selected depending which one you choose. It will also vary based on 1/ how many jobs you submit to the cluster and 2/ how many login nodes you bring up. There is also a recurring charge for the elastic load balancer. Based on on-demand pricing for the relevant instances, it should cost between $20 to $50.00 to run the cluster for a week.

## Cleaning Up

When you are done using your cluster, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the relevant stack.
