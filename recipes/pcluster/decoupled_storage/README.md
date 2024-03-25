# ParallelCluster Decoupled Storage

## Info

Build two example clusters that demonstrate the new decoupled storage features in Pcluster 3.9 and higher. In the first recipe, we demonstrate use of the `SharedStorageType` parameter which transitions the head node from hosting its own NFS shares to provide cluster state and home directory to using Amazon EFS shared provisioned by Pcluster. The second recipe demonstrates using an external EFS share as the basis for the cluster's home directory. 

## Usage

## Usage

### Configure a multi-AZ networking stack

* Follow the instructions in the [Large-scale HPC Networking Setup](../../net/hpc_large_scale/README.md) recipe. You only need to do this once per Region you want to deploy clusters in. If you named the networking stack something besides **hpc-networking**, make a note of that as you will need it to set up the recipes in this collection.

### Create an Amazon Elastic Filesystem (EFS) share

* Follow the instructions in the [Amazon EFS Filesystem with Security Group](../../stroage/efs_simple/README.md) recipe. Make sure you create your EFS in the same VPC you created above. If you named the networking stack something besides **efs-simple**, make a note of that as you may will need it to set up the external home directory recipe. 

### Launch Cluster 1 (Managed EFS Shares)

1. Ensure you have a Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the Region where you want to launch your cluster.
2. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=managed-efs&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/decoupled_storage/assets/managed_efs.yaml)
3. Follow the instructions in the AWS CloudFormation console. As you work through the template, mind these points:
  * The value you enter for **NetworkStackNameParameter** is the name of your HPC networking stack.
  * The template asks you to provide a valid CIDR notation (X.X.X.X/X) to secure access to the login node. You can choose a value that is more restrictive than `0.0.0.0/0`.

### Launch Cluster 2 (Managed and External EFS Shares)

1. Ensure you have a Amazon EC2 [SSH key created](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html#having-ec2-create-your-key-pair) in the Region where you want to launch your cluster.
2. Launch the template: [![Launch stack](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=bring-own-efs&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcluster/decoupled_storage/assets/managed_external_efs.yaml)
3. Follow the instructions in the AWS CloudFormation console. As you work through the template, mind these points:
  * The value you enter for **NetworkStackNameParameter** is the name of your HPC networking stack.
  * The template asks you to provide a valid CIDR notation (X.X.X.X/X) to secure access to the login node. You can choose a value that is more restrictive than `0.0.0.0/0`.

### Access the Clusters

To access either cluster, connect via Amazon Systems Manager (SSM) using the link provided in the CloudFormation console:
1. Navigate to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation/home)
2. Choose the stack for the cluster where you want to log in. 
3. Go to the **Outputs** tab. Follow the link at **SystemManagerUrl** to log into the system head node. 

### Compare the two clusters

Log into each cluster and note the following differences. On the *managed-efs** cluster, where Pcluster manages the `/opt/*` and `/home` mounts, a listing of all filesystem mounts will resemble this:

```shell
[ec2-user@ip-10-3-13-181 ~]$ df -h
Filesystem                                                                                Size  Used Avail Use% Mounted on
devtmpfs                                                                                  1.9G     0  1.9G   0% /dev
tmpfs                                                                                     1.9G     0  1.9G   0% /dev/shm
tmpfs                                                                                     1.9G  496K  1.9G   1% /run
tmpfs                                                                                     1.9G     0  1.9G   0% /sys/fs/cgroup
/dev/nvme0n1p1                                                                             40G   20G   21G  50% /
fs-0a1884ac02ef7da51.efs.us-east-2.amazonaws.com:/opt/parallelcluster/shared              8.0E  949M  8.0E   1% /opt/parallelcluster/shared
fs-0a1884ac02ef7da51.efs.us-east-2.amazonaws.com:/opt/parallelcluster/shared_login_nodes  8.0E  949M  8.0E   1% /opt/parallelcluster/shared_login_nodes
fs-0a1884ac02ef7da51.efs.us-east-2.amazonaws.com:/opt/slurm                               8.0E  949M  8.0E   1% /opt/slurm
fs-0a1884ac02ef7da51.efs.us-east-2.amazonaws.com:/opt/intel                               8.0E  949M  8.0E   1% /opt/intel
fs-0a1884ac02ef7da51.efs.us-east-2.amazonaws.com:/home                                    8.0E  949M  8.0E   1% /home
tmpfs  
```

The filesystem (`fs-0a1884ac02ef7da51`) is the same for the `/opt/*` mounts and `/home`. 

On the **bring-own-efs** cluster, the mount listing is similar...

```shell
[ec2-user@ip-10-3-3-57 ~]$ df -h
Filesystem                                                                                Size  Used Avail Use% Mounted on
devtmpfs                                                                                  1.9G     0  1.9G   0% /dev
tmpfs                                                                                     1.9G     0  1.9G   0% /dev/shm
tmpfs                                                                                     1.9G  496K  1.9G   1% /run
tmpfs                                                                                     1.9G     0  1.9G   0% /sys/fs/cgroup
/dev/nvme0n1p1                                                                             40G   20G   21G  50% /
fs-0997226bf76e27cd1.efs.us-east-2.amazonaws.com:/opt/parallelcluster/shared              8.0E  949M  8.0E   1% /opt/parallelcluster/shared
fs-0997226bf76e27cd1.efs.us-east-2.amazonaws.com:/opt/parallelcluster/shared_login_nodes  8.0E  949M  8.0E   1% /opt/parallelcluster/shared_login_nodes
fs-0997226bf76e27cd1.efs.us-east-2.amazonaws.com:/opt/slurm                               8.0E  949M  8.0E   1% /opt/slurm
fs-0997226bf76e27cd1.efs.us-east-2.amazonaws.com:/opt/intel                               8.0E  949M  8.0E   1% /opt/intel
fs-0f776ba6ca83469df.efs.us-east-2.amazonaws.com:/                                        8.0E     0  8.0E   0% /home
tmpfs  
```

However, the `/opt/*` shares and the `/home` shares are on different filesystems. In this case, `fs-0997226bf76e27cd1` is managed by Pcluster, while `fs-0f776ba6ca83469df` was created with an external stack and connected to the cluster. 

## Next steps

1. In **bring-own-efs** cluster template, we build the EFS filesystem and the cluster at the same time. In a production setting where you care about persisting the `/home` filesystem, you would create them independently so they have their own separate life cycles. 
2. We use EFS because it is relatively inexpensive and simple to set up for a demonstration. You can also use FSx filesystems, such as FSx for Lustre or (even more appropriately) FSx for OpenZFS for a shared, persistent home filesystem. 

## Cost Estimate

Costs for a cluster created using this recipe will vary depending on the cluster architecture, since different instances types will be selected depending which one you choose. It will also vary based on how many jobs you submit to the cluster, since ParallelCluster can launch instances to run them. Based on on-demand pricing for the relevant instances, it should cost between $10 to $25.00 to run the cluster for a week, submitting a handful of jobs. 

## Cleaning Up

When you are done using your clusters, you can delete them and their associated resources by navigating to the AWS CloudFormation console and deleting the relevant stacks. 
