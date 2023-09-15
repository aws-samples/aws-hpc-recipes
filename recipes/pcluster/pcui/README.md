# ParallelCluster with Web UI Installed

## Info

Creates an instance of AWS ParallelCluster along with a deployment of the ParallelCluster UI web application. This recipe supplements the AWS ParallelCluster [documentation](https://docs.aws.amazon.com/parallelcluster/latest/ug/install-pcui-v3.html).

## Usage

### (Optional) Configure a multi-AZ networking stack

1. Follow the instructions in the [Large-scale HPC Networking Setup](../../net/hpc_large_scale/README.md) recipe. You only need to do this once per Region you want to deploy clusters in. If you named the networking stack something besides **hpc-networking**, make a note of that as you may need it to set up recipes in this collection.

### Launch ParallelCluster UI with an Example Cluster

1. Ensure you have a Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the Region where you want to launch your cluster and AD management instance.
2. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=pcluster-pcui&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/pcui/assets/launch.yaml)
3. Follow the instructions in the AWS CloudFormation console. As you work through the template, mind these points:
    * The value you enter for **NetworkStackNameParameter** is the name of your HPC networking stack
    * You need to be able to receive email at the address you provide for **AdminUserEmail**

**Note**: If you do not wish to import the networking configuration from a stack provided by the **HPC Recipes for AWS** collection. you can use the [alternative CloudFormation template](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=pcluster-pcui&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/pcui/assets/launch-alt.yaml). 

### Logging into ParallelCluster UI

Once the Cloudformation stack status transitions to `CREATE_COMPLETE`, navigate to its Outputs and locate the value for **PclusterUIUrl**. Visit that URL - you will be prompted for a username and password. For username, enter the value you provided for **AdminUserEmail** and for password, enter the password from the email you should have received from AWS titled `[AWS ParallelCluster UI] Welcome to AWS ParallelCluster UI, please verify your account`. Change your password as instructed and log in. You should see your test cluster listed under **Clusters**.

## Cost Estimate

Costs for a cluster created using this recipe will vary depending on the cluster architecture, since different instances types will be selected depending which one you choose. It will also vary based on how many jobs you submit to the cluster, since ParallelCluster can launch instances to run them. Based on on-demand pricing for the relevant instances, it should cost between $10 to $25.00 to run the cluster for a week, submitting a handful of jobs. 

## Cleaning Up

When you are done using your cluster, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the **pcluster-pcui** stack. 
