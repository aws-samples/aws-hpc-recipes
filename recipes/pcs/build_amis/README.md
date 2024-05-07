# Build PCS AMIs

## Info

This recipe contains assets to build PCS-compatible AMIs. 

It demonstrates the current (05/2024) minimum requirements for an AMI to be used with PCS: 

* Slurm 23.11.05 or higher must be installed
* Relevant users and groups must be present
* PCS client configuration scripts (and their dependencies) must be installed

## Usage

There are two scripts [`rocky8.sh`](assets/rocky8.sh) and [`ubuntu22.sh`](assets/ubuntu22.sh) in the assets directory. They are constructed as executable Bash programs, but you should probably manually step through them interactively, since they are not extensively tested. 

To build a PCS beta-compatible AMI:

1. Launch a builder instance using the source AMI (such as Rocky8 or Ubuntu22), making sure it is configured so you can log into it.
2. Log into the builder instance over SSH. 
3. Become the `root` user 
4. Follow along the build instructions in `rocky8.sh` or `ubuntu22.sh`
5. Run /opt/aws/pcs/bin/pcs_ami_cleanup.sh
6. In AWS EC2 console, navigate to your builder instance
7. Under **Actions, Image and templates** choose **Create image**
8. Wait for the AMI to finish building. Note the AMI ID. 
9. Create or update a PCS compute node group using the new AMI ID.

Here is an example of creating a static node group that exercises a custom AMI. 

```shell
aws pcs \
    --region us-east-1 \
    create-compute-node-group \
    --cluster-identifier MYCLUSTER \
    --compute-node-group-name CUSTOM-AMI-CNG \
    --subnet-ids SUBNET-ID \
    --custom-launch-template id=LAUNCH-TEMPLATE-ID,version='$Latest' \
    --iam-instance-profile-arn arn:aws:iam::111111111111:instance-profile/AWSPCS-Role \
    --scaling-config minInstanceCount=1,maxInstanceCount=1 \
    --instances instanceType=c6i.xlarge \
    --ami-id CUSTOM-AMI-ID
```

You can validate that the AMI + node group is working as intended.  Log into an instance belonging to a static node group featuring the new AMI and run `sinfo`. If Slurm and the client scripts are all installed correctly, and the IAM instance profile used to create the node group has permission to call `pcs:RegisterComputeNodeGroupInstance`, `sinfo` will run without error. 

### Rocky Linux 8

There are no AWS-official Rocky Linux AMIs, but you can subscribe to them in the **AWS Marketplace** and use them to build PCS AMIs. 

To launch a Rocky 8 builder instance:

1. Under **Instances** in the EC2 console, choose **Launch instances**
2. For **Name and tags, Name** provide a distinctive name for the instance
3. Under **Application and OS Images (Amazon Machine Image)**, search for `Rocky`
4. Navigate to the **AwS Marketplace AMIs** tab and choose **Rocky Linux 8 (Official)**.
5. Choose **Subscribe now**
6. Finish launching the instance, choosing an instance type, networking, SSH key, and so on.

### Rocky Linux 9

Rocky Linux 9 is not currently supported by this repository.

### Ubuntu 22

To launch an Ubuntu 22 builder instance:

1. Under **Instances** in the EC2 console, choose **Launch instances**
2. For **Name and tags, Name** provide a distinctive name for the instance
3. Under **Application and OS Images (Amazon Machine Image)**, search for `Ubuntu`
4. Navigate to the **Quickstart AMIs** tab and choose **Ubuntu Server 22.04 LTS (HVM), SSD Volume Type**.
5. Finish launching the instance, choosing an instance type, networking, SSH key, and so on.

### PCS Client Scripts

There are four client scripts in [`assets/client`](assets/client/). PCS will call these scripts automatically as part of the instance launch cycle. In order of execution, they are:

1. [`pcs_bootstrap_init.sh`](assets/client/pcs_bootstrap_init.sh) - Registers the instance with the `RegisterComputeNodeGroupInstance` and caches information such as the SlurmCtld endpoint and the cluster secret in a file.
2. [`pcs_bootstrap_config_always.sh`](assets/client/pcs_bootstrap_config_always.sh) - Currently a placeholder. Does nothing. 
3. [`pcs_bootstrap_config_per_instance.sh`](assets/client/pcs_bootstrap_config_per_instance.sh) - Configures Slurm using the output from `pcs_bootstrap_init.sh`.
4. [`pcs_bootstrap_finalize.sh`](assets/client/pcs_bootstrap_finalize.sh) - Enables and starts SlurmD daemon on the host. 

Internal implementation is subject to change between beta and GA. Don't rely on anything you see in these files except the need to call `RegisterComputeNodeGroupInstance`.

