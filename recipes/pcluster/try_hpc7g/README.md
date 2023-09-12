# Hpc7g Test Cluster

## Info

This recipe creates a ParallelCluster system where you can try out Amazon EC2 [Hpc7g instances](https://aws.amazon.com/ec2/instance-types/hpc7g/). 

The cluster design includes the following features:

* Memory-aware Slurm scheduling is enabled.
* General-purpose shared storage is available at `/shared`.
* High-performance shared scratch storage (based on Amazon FSx for Lustre) is available at `/fsx`.

## Usage

### Check your Service Quota

1. Navigate to the [AWS Service Quotas console](https://console.aws.amazon.com/servicequotas/home/services/ec2/quotas) and change to the **us-east-1** Region.
2. Search for **HPC**, then check the **Running On-Demand HPC instances** quota to ensure your **Applied quota value** is sufficient to allow instance launches. This quota is expressed in vCPUs, not instances. 
3. If it is not sufficient for your needs, choose the **Request increase at account-level** option and wait for your request to be processed. Then, return to this exercise.

### Launch the Cluster

1. Ensure you have an Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the Region where you want to launch your cluster.
2. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?stackName=try-hpc7g&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/try_hpc7g/assets/launch.yaml)
3. Follow the instructions in the AWS CloudFormation console. When you configure the queue sizes (i.e. `ComputeInstanceMax`), choose a value that is consistent with your service quota. 
4. Monitor the status of the AWS CloudFormation stack. When its status reaches `CREATE_COMPLETE`, navigate to its **Outputs** tab. There is information there you can use to access the new cluster. 

**Note**: This template creates a VPC and subnets associcated with the cluster. If you wish to use your own networking configuration, launch your cluster using the [alternative CloudFormation template](https://us-east-1.console.aws.amazon.com/cloudformation/home?region=us-east-1#/stacks/create/review?stackName=try-hpc7g&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/try_hpc7g/assets/launch-alt.yaml). 

### Access the Cluster

If you want to use SSH to access the cluster, you will need its public IP (from above). Using your local terminal, connect via SSH like so: `ssh -i KeyPair.pem ec2-user@HeadNodeIp` where `KeyPair.pem` is the path to the EC2 keypair you specified when launcing the cluster and `HeadNodeIp` is the IP address from above. If you chose one of the Ubuntu operating systems for your cluster, the login name may be `ubuntu` rather than `ec2-user`.

You can also use AWS Systems Manager to access the cluster. You can follow the link found in **Outputs > SystemManagerUrl**. Or, you can navigate to the **Instances** panel in the [Amazon EC2 Console](https://console.aws.amazon.com/ec2/home#Instances). Find the instance named **HeadNode** - this is your cluster's access node. Select that instance, then choose **Actions** followed by **Connect**. On the **Connect to instance** page, navigate to **Session Manager** then choose **Connect**.

Once you are on the system, you can find a queue that will host jobs on Hpc7g instances.

```shell
% sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
hpc7g*       up   infinite      8  idle~ hpc7g-dy-nodes-[1-16]
```

You can use the `/shared` directory for common software and data files, while the `/fsx` directory is well-suited for running jobs. 

## Cleaning Up

When you are done using your cluster, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the relevant stack. Note that data on the `/shared` and `/fsx` volumes will be deleted. If you want to keep it, find the relevant Elastic Block Store and FSx for Lustre volumes in the AWS console and back them up.
