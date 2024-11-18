# Try AWS PCS with AMD-powered EC2 instances

## Info

This recipe helps you launch a Slurm cluster using AWS Parallel Computing Service, powered by Amazon EC2 instances with AMD processors.

## Pre-requisites

1. An active AWS account with an adminstrative user. To sign up for one if you do not have one, please see [Sign up for AWS and create an administrative user](https://docs.aws.amazon.com/pcs/latest/userguide/setting-up.html) in the AWS PCS user guide.
2. Sufficient Amazon EC2 service quota to launch the cluster. To check your quotas:
    * Navigate to the [AWS Service Quotas console](https://console.aws.amazon.com/servicequotas/home/services/ec2/quotas). 
    * Change to the **us-east-2** Region. 
    * Search for **Running On-Demand Standard (A, C, D, H, I, M, R, T, Z) instances**
    * Make sure your **Applied account-level quota value** is at least 16
    * Search for **Running On-Demand HPC instances**
    * Make sure your **Applied quota value** is at least 192 to run two HPC instances or 384 to run four HPC instances.
    * If either quota is too low, choose the **Request increase at account-level** option and wait for your request to be processed. Then, return to this exercise. 

## Create an AWS PCS cluster powered by AMD processors

Launch the cluster using AWS CloudFormation:
    * `us-east-2` (Ohio, United States) [![Launch](../../../docs/media/launch-stack.svg)](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=try-amd-cfn&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/try_amd/assets/cluster.cfn.yaml)

* Follow the instructions in the AWS CloudFormation console:
    * Under **Parameters**
        * (Optional) Customize the stack name
        * For **AmiId** leave this blank
        * For **ClientIpCidr**, either leave it as its default value or replace with a more restrictive CIDR range
        * Leave the parameters under **HPC Recipes configuration** as their default values.
    * Under **Capabilities and transforms**
        * Check all three boxes
    * Choose **Create stack**
* Monitor the status of your stack (e.g. **try-amd-cfn**). When its status is `CREATE_COMPLETE`, you can interact with the PCS cluster. 

## Interact with the PCS cluster

You can work with your new cluster using the AWS PCS console, or you can connect to its login node to run jobs and manage data. Your new CloudFormation stack can help you with this. In the [AWS CloudFormation console](https://console.amazonaws.com/cloudformation/home), choose the stack you have created. Then, navigate to the **Outputs** tab. 

There will be three URLs:
* **SshKeyPairSsmParameter** This link takes you to where you can download an SSH key that has been generated to enable SSH access to the cluster. See below `Extra: Connecting via SSH` to learn how to use this information.
* **PcsConsoleUrl** This is a link to the cluster you created, in the PCS console. Go here to explore the cluster, node group, and queue configurations. 
* **Ec2ConsoleUrl** This link takes you to a filtered view of the EC2 console that shows the instance(s) managed by the `login` node group. 

### Connect to the cluster

You can connect to your PCS cluster login node right in the browser. 
1. Navigate to the **Ec2ConsoleUrl** URL.
2. Select an instance and choose **Connect**.
3. On the **Connect to instance** choose **Session Manager**.
4. Click on the **Connect** button. You will be taken to a terminal session. 
5. Become the `ec2-user` user by typing `sudo su - ec2-user`

### Cluster design

There are two Slurm partitions on the system `small` and `large`. The `small` partition sends jobs to nodes managed by the `c7a-xlarge` node group. These will be [`c7a.xlarge`](https://aws.amazon.com/ec2/instance-types/c7a/) compute instances without Elastic Fabric Adapter (EFA) networking. The `large` partition sends work to the `hpc7a-48xlarge` node group, which features [`hpc7a.48xlarge`](https://aws.amazon.com/ec2/instance-types/hpc7a/) instances that have EFA built in. 

Find the queues by running `sinfo` and inspect the nodes with `scontrol show nodes`. 

The `/home` and `/fsx` directories are network file systems. The `home` directory is provided by [Amazon Elastic Filesystem](https://aws.amazon.com/efs/), while the `fsx` directory is powered by [Amazon FSx for Lustre](https://aws.amazon.com/fsx/lustre/). You can install software on the `/home` or `/fsx` directory. We recommend you run jobs out of the `/fsx` directory. 

Verify that these filesystems are present with `df -h`. It will return a screen that resembles this.

```shell
[ec2-user@ip-10-0-8-20 ~]$ df -h
Filesystem                                          Size  Used Avail Use% Mounted on
devtmpfs                                            3.8G     0  3.8G   0% /dev
tmpfs                                               3.8G     0  3.8G   0% /dev/shm
tmpfs                                               3.8G  612K  3.8G   1% /run
tmpfs                                               3.8G     0  3.8G   0% /sys/fs/cgroup
/dev/nvme0n1p1                                       24G   20G  4.2G  83% /
fs-0d0a17eaafcc0d0e6.efs.us-east-2.amazonaws.com:/  8.0E     0  8.0E   0% /home
10.0.10.150@tcp:/xjmflbev                           1.2T  4.5G  1.2T   1% /fsx
tmpfs                                               774M     0  774M   0% /run/user/0
```

### Run some jobs

Once you have connected to the login instance, follow along with the **Getting Started with AWS PCS** tutorial starting at [_Explore the cluster environment in AWS PCS_](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started_explore.html). 

## Cleaning Up

When you are done using your PCS cluster, you can delete it and all its associated resources by navigating to the AWS CloudFormation console and deleting the stack you created.

However, if you have created additional resources in your cluster, beyond the `login`, `c7a-xlarge`, and `hpc7a-48xlarge` node groups, or the `large` and `small` queues, **you must delete those resources** in the PCS console before deleting the CloudFormation stack. Otherwise, deleting the stack will fail and you will need to manually delete several resources on your own. 

If you do need to delete extra resources , go to detail page for your PCS cluster. 
* Delete any queues besides `small` and `large`
* Delete any node groups besides `login`, `c7a-xlarge`, and `hpc7a-48xlarge`

**Note** We do not recommend you create or delete any resources in this demonstration cluster. Get started building your own, totally customizable HPC clusters with [this tutorial](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started.html) in the AWS PCS user guide. 

## Extra: Connecting via SSH

By default, we have configured the cluster to support logins via Session Manager, in the browser. If you want to connect using regular SSH, here's how. 

### Retrieve the SSH key

We generated an SSH key as part of deploying the cluster. It is stored in [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html). You can download the key and use it to connect to the public IP address of your PCS cluster login node. 

* Go to the **SshKeyPairSsmParameter** URL
* Copy the name of the SSH key - it will look like this `/ec2/keypair/key-HEXADECIMAL-DATA`
* Use the AWS CLI to download the key

`aws ssm get-parameter —-name "/ec2/keypair/key-HEXADECIMAL-DATA" —-query "Parameter.Value" —-output text —-region us-east-2 —-with-decryption | tee > key-HEXADECIMAL-DATA.pem`

* Set permissions on the key to owner-readable `chmod 400 key-HEXADECIMAL-DATA.pem`

### Log in to the cluster

* Log in to the login node public IP, which you can retrieve via **Ec2ConsoleUrl**.

`ssh -i key-HEXADECIMAL-DATA.pem ec2-user@LOGIN-NODE-PUBLIC-IP`

