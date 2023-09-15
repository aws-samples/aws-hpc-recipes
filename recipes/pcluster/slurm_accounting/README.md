# ParallelCluster with Slurm Accounting Enabled

## Info

Creates an instance of AWS ParallelCluster with Slurm accounting enabled, using Amazon RDS as the database management server.

### (Optional) Configure a multi-AZ networking stack

1. Follow the instructions in the [Large-scale HPC Networking Setup](../../net/hpc_large_scale/README.md) recipe. You only need to do this once per Region you want to deploy clusters in. If you named the networking stack something besides **hpc-networking**, make a note of that as you may need it to set up your cluster and other resources.

### Launch the Cluster and Database

1. Ensure you have a Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the Region where you want to launch your cluster.
2. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=sacct-cluster&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/slurm_accounting/assets/launch.yaml)
3. Follow the instructions in the AWS CloudFormation console. As you work through the template, mind these points:
  * The value you enter for **NetworkStackNameParameter** must be the name of your HPC networking stack
  * Don't set a value for **AdminPasswordSecretString** that is used anywhere else
4. Monitor the status of the stack named **sacct-cluster**. When its status is `CREATE_COMPLETE`, navigate to its **Outputs** tab. Find the output named **HeadNodeIp** - this is the public IP address for your cluster login node.

**Note**: If you do not wish to import the networking configuration from a stack provided by the **HPC Recipes for AWS** collection. you can use the [alternative CloudFormation template](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=sacct-cluster&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/slurm_accounting/assets/launch-alt.yaml). 

### Access the Cluster and Try Slurm Accounting

You can either log in via SSH to the **HeadNodeIp** using the keypair you specified, or you can use Amazon Systems Manager to log from the AWS EC2 Console. Once you are logged into the system, you can test out a couple of commands that confirm Slurm accounting is active. 
1. Try using the [sacct](https://slurm.schedmd.com/sacct.html) command to display accounting data for all jobs and job steps in the Slurm database. 
2. Try out the [sacctmgr](https://slurm.schedmd.com/sacctmgr.html) command. It is used to configure accounting in detail. 

## Persistent Databases

In this example, we create the accounting database as a resource in the CloudFormation template. When the stack is deleted, so is the accounting database. If you want your database to be persistent across cluster instances, or if you want to share it between clusters, you can import values from an existing database stack into your ParallelCluster deployment. 

1. Run the the [Slurm Accounting Database](../../db/slurm_accounting_db/assets/serverless-database.yaml) quick-create. Take note of the name of the CloudFormation stack for the database. 
2. Launch ParallelCluster using this alternative template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=sacct-cluster-persistent&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/slurm_accounting/assets/launch-persistent.yaml)
3. When prompted, provide the name of your database CloudFormation stack to **DatabaseStackNameParameter**

Now, the Amazon RDS database will not be deleted when and if you delete your ParallelCluster stack. 

## Key Details

This is an interesting CloudFormation template, since it highlights a pretty complex resource orchestration. Here are key details you can dive deep on:

* The `AdminPasswordSecretString` parameter is an excellent example of using a regular expression to validate user input.
* Make sure to add the security group for the database cluster to the head node (see `Resources.PclusterCluster.Properties.ClusterConfiguration.HeadNode.Networking.AdditionalSecurityGroups`)
* The database cluster in this recipe launches in private subnets shared with the compute nodes. This is  not mandatory as long as its IP is reachable from the head node. 

## Cost Estimate

Costs for a cluster created using this recipe will vary depending on the cluster architecture, since different instances types will be selected depending which one you choose. It will also vary based on how many jobs you submit to the cluster, since ParallelCluster can launch instances to run them. There will also be a charge for the Amazon RDS cluster. Based on on-demand pricing for the relevant instances, it should cost between $30 to $50.00 to run the cluster for a week, submitting a handful of jobs. 

## Cleaning Up

When you are done using your cluster, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the relevant stack.  
