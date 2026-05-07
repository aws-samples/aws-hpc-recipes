# NICE DCV Visualization Workstation for PCS with Relion

## Introduction

[NICE DCV](https://aws.amazon.com/hpc/dcv/) is a high-performance remote display protocol that lets users access graphical desktops and applications hosted on AWS. When paired with AWS Parallel Computing Service (PCS), DCV enables interactive visualization workflows — such as pre/post-processing for CFD, molecular visualization, or CAE — directly alongside HPC job submission. 

There are a few different options for integrating visualization with PCS on NICE DCV. Figure 1 provides an overview.

![NICE DCV and PCS Architecture](docs/NICE%20DCV%20and%20PCS.png)

Options for integrating DCV with PCS for visualization:
1. **Standalone DCV workstation** — A customer-managed EC2 instance running DCV, connected to shared storage (EFS/FSx) but with no Slurm connectivity. Users visualize results only; job submission happens separately via SSH to a PCS login node. This is the simplest deployment model.
2. **Standalone DCV + BYO login node** — Same as above, but with `sackd` installed on the DCV instance, turning it into a Slurm client. Users get both visualization and job submission from a single session.
3. **DCV on a PCS login node** — DCV baked into the custom AMI for the PCS login compute node group. Slurm (`sackd`) is pre-configured by PCS. This couples the remote desktop with the cluster's login experience.
4. **DCV on a dedicated visualization compute node group** — A separate PCS compute node group (its own Slurm partition) with GPU instances and DCV pre-installed. Users submit an interactive Slurm job to get an on-demand DCV session. The node group can scale to zero when not in use, mirroring the "elastic visualization queues" concept from ParallelCluster.

This guidance covers **Option 2: Standalone DCV + BYO login node**. We will leverage existing recipes in this repo (getting_started and cfd_cluster) to set up a cluster with a standalone visualization node. We will then use the byo_login guidance to add that visualization node to the cluster.

## Overview

This recipe is a walkthrough that composes existing recipes to create a NICE DCV remote visualization workstation configured as a bring-your-own (BYO) login node for AWS Parallel Computing Service (PCS).

For our visualization workload we'll use Relion (REgularised LIkelihood OptimisatioN), an open-source cryo-EM image processing application that uses GPUs for accelerated visualization and computation. 

With Relion, users both visualize 3D molecules and submit batch jobs to the cluster, all from a single UI running in the DCV session.

Rather than creating net-new infrastructure, this recipe guides you through composing:

1. [**pcs/getting_started**](../getting_started/) — PCS cluster with networking, storage, and compute nodes
2. **Modified DCV workstation template** (included in this recipe at [`assets/dcv-linux-node.yaml`](assets/dcv-linux-node.yaml)) — GPU instance with NICE DCV and configurable username
3. [**Official AWS PCS multi-cluster login script**](https://github.com/aws-samples/aws-hpc-recipes/tree/main/recipes/pcs/byo_login) — sackd configuration for BYO login node connectivity
4. [**pcs/spack_for_pcs**](../spack_for_pcs/) — Spack package manager for HPC dependency management

We will deploy a PCS cluster, launch a DCV workstation, configure it as a login node, and install Relion for interactive cryo-EM processing with GPU acceleration.

## Prerequisites

Before starting this walkthrough, ensure you have:

- An AWS account with permissions to create EC2, IAM, Lambda, FSx, and PCS resources
- An EC2 SSH key pair in the target region
- A CIDR range for DCV/SSH access (e.g., `x.x.x.x/32` for your IP, or `0.0.0.0/0` for open access)
- AWS CLI installed and configured
- Familiarity with AWS PCS (we recommend completing the [Getting Started tutorial](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started.html) first)

## Step 1: Create PCS Cluster

Use the [**pcs/getting_started**](https://github.com/aws-samples/aws-hpc-recipes/tree/main/recipes/pcs/getting_started) recipe to create a PCS cluster with networking, storage, and compute nodes.

### Launch the cluster

Use the "Create a PCS cluster with new networking" quick-launch link from the [pcs/getting_started recipe](https://github.com/aws-samples/aws-hpc-recipes/tree/main/recipes/pcs/getting_started).
Follow the instructions in that recipe with these configuration choices:

- **SlurmVersion**: Select `25.11` (the current default).
- **NodeArchitecture**: Choose `x86`.
- **Compute instance type**: Select a GPU instance type for the compute node group — `g4dn.xlarge`, `g5.xlarge`, or `g6.xlarge` depending on your budget and performance needs.
- **FSx for Lustre**: Ensure it is included (it is by default in the getting_started template).
- **KeyName**: Choose your SSH key pair.
- **ClientIpCidr**: Set to your IP CIDR or leave as `0.0.0.0/0`.

Wait for the CloudFormation stack to reach `CREATE_COMPLETE` status.

### Collect stack outputs

After the stack completes, navigate to the **Outputs** tab in the CloudFormation console and note the following values (you will need them in Step 2):

| Output | Description | How to find |
|--------|-------------|-------------|
| **Cluster ID** | PCS cluster identifier | PCS console or `aws pcs list-clusters` |
| **Cluster Security Group ID** | Security group attached to the PCS cluster | CloudFormation stack outputs |
| **Public Subnet ID** | Public subnet for the DCV workstation | CloudFormation stack outputs |
| **FSx for Lustre Filesystem ID** | Shared filesystem identifier | CloudFormation stack outputs |
| **FSx mount directory** | Mount path on instances (default: `/shared`) | CloudFormation stack outputs |

### Using an existing cluster

If you already have a PCS cluster, it must meet these minimum requirements:

- FSx for Lustre filesystem attached and mounted on compute nodes
- At least one compute node group with GPU instances (g4dn, g5, or g6 family)
- Slurm version 25.05 or later (required for the official multi-cluster login script)
- A public subnet available in the same VPC for the DCV workstation

## Step 2: Deploy DCV Workstation

This step launches a GPU-enabled DCV workstation using the modified CloudFormation template included in this recipe.

### Launch the template

Upload the template [`assets/dcv-linux-node.yaml`](assets/dcv-linux-node.yaml) to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation/home) and create a new stack.

Alternatively, you can use the S3-hosted version:

```
https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/nice_dcv/assets/dcv-linux-node.yaml
```

### Configure parameters

Fill in the following parameters using the outputs from Step 1:

| Parameter | Value | Notes |
|-----------|-------|-------|
| `DcvUsername` | `ec2-user` | Leave as default (recommended for PCS compatibility) |
| `Password` | (your strong password) | Used to log into the DCV web session |
| `OperatingSystem` | `AmazonLinux2-x64-Graphics-Intensive` | Required for GPU support |
| `SshKeyName` | (your SSH key) | For SSH access to the instance |
| `AllowList` | (your IP CIDR) | e.g., `x.x.x.x/32` for your IP |
| `StreamingPort` | `8443` | Leave as default |
| `DiskSize` | `100` | 50 GB minimum; 100 GB recommended for Relion builds |
| `ClusterId` | (from Step 1) | PCS cluster identifier |
| `PublicSubnetId` | (from Step 1) | Public subnet in the cluster VPC |
| `ClusterSecurityGroupId` | (from Step 1) | PCS cluster security group |
| `FSxLustreFilesystemId` | (from Step 1) | FSx for Lustre filesystem ID |
| `FSxLustreMountDirectory` | `/shared` | Must match the cluster mount path |

Under **Capabilities and transforms**, check the boxes to acknowledge IAM resource creation, then choose **Create stack**.

### Why ec2-user is recommended

The `DcvUsername` parameter defaults to `ec2-user` because this user already exists on PCS compute node AMIs with a consistent UID (1000).
When `ec2-user` submits a Slurm job from the DCV workstation, the job runs as `ec2-user` on compute nodes with no UID/GID mismatch.
Shared filesystem access works without `chmod 777` workarounds, and Slurm commands work because PCS accepts jobs from any authenticated user via sackd.

### Verify DCV connectivity

1. Wait for the DCV workstation CloudFormation stack to reach `CREATE_COMPLETE`.
2. Navigate to the **Outputs** tab and find the **LinuxDcvURL** output.
3. Open the URL in your web browser (e.g., `https://<instance-ip>:8443`).
4. You will see a self-signed certificate warning — accept it and proceed.
5. Log in with username `ec2-user` and the password you specified during stack creation.

## Step 3: Configure BYO Login Node

In this step, you configure the DCV workstation as a PCS login node so you can run Slurm commands directly from your DCV session.

### Connect to the instance

SSH into the DCV workstation using your key pair, or use AWS Systems Manager Session Manager:

```bash
ssh -i your-key.pem ec2-user@<instance-public-ip>
```

### Verify prerequisites

Before running the login configuration script, verify these prerequisites on the instance:

```bash
# Verify jq and curl are installed
which jq curl

# Verify the slurm user exists
id slurm

# Verify network connectivity to the PCS cluster endpoint (port 6817)
nc -zv <cluster-endpoint-ip> 6817
```

### Add IAM permissions

The instance role needs permissions to retrieve cluster information and secrets.
Add an inline policy to the DcvHostRole (created by the DCV stack) or attach the `AmazonPCSReadOnlyAccess` managed policy.

The script requires these permissions:

- `pcs:GetCluster`
- `secretsmanager:GetSecretValue`

### Download and run the official script

```bash
# Download the official AWS PCS multi-cluster login configuration script
curl -O https://raw.githubusercontent.com/aws-samples/aws-hpc-recipes/main/recipes/pcs/byo_login/assets/pcs-multi-cluster-login-configure.sh
chmod +x pcs-multi-cluster-login-configure.sh

# Run with your cluster identifier
sudo ./pcs-multi-cluster-login-configure.sh --cluster-identifier <your-cluster-id>
```

The script automatically:

- Detects the AWS region from instance metadata
- Retrieves cluster info (endpoint IP, Slurm version, secret ARN)
- Downloads the auth key from Secrets Manager
- Creates and starts a systemd service (`sackd-pcs-<cluster-name>.service`)
- Generates an activate script for setting up the Slurm environment

### Activate the Slurm environment

Source the activate script generated by the configuration script:

```bash
source ./activate-pcs-<cluster-name>
```

Add it to your `.bashrc` for persistence across sessions:

```bash
echo "source /home/ec2-user/activate-pcs-<cluster-name>" >> ~/.bashrc
```

### Verify Slurm connectivity

```bash
sinfo    # Should show cluster partitions
squeue   # Should show empty queue (or running jobs)
```

### Troubleshooting

If `sinfo` times out or the sackd service fails to start:

- **Security group rules**: Ensure the cluster security group allows inbound traffic on port 6817 from the DCV workstation.
- **IAM permissions**: Verify the instance role has `pcs:GetCluster` and `secretsmanager:GetSecretValue` permissions.
- **Slurm version mismatch**: The official script requires Slurm ≥ 25.05. Check your cluster's Slurm version in the PCS console.
- **Service logs**: Check `journalctl -u sackd-pcs-*` for detailed error messages.

## Step 4: Install Relion

Relion requires Spack for dependency management and is built from source with GPU support.

### Install Spack

First, install Spack on the shared filesystem.
This follows the [pcs/spack_for_pcs](../spack_for_pcs/) recipe pattern:

```bash
# Download the Spack installer
curl -O https://raw.githubusercontent.com/spack/spack-configs/main/AWS/parallelcluster/postinstall.sh
chmod +x postinstall.sh

# Install Spack to the shared filesystem
sudo ./postinstall.sh --prefix /shared

# Load Spack into your environment
source /shared/spack/share/spack/setup-env.sh
```

### Run the Relion install script

Download and run the Relion installation script included in this recipe:

```bash
# Download the install script (from this recipe's assets)
curl -O https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/nice_dcv/assets/install-relion.sh
chmod +x install-relion.sh

# Run the installer (uses Spack for deps, builds Relion from source)
sudo ./install-relion.sh
```

### CUDA architecture selection

The `--cuda-arch` flag should match your GPU instance type.
If omitted, the script attempts auto-detection.

| Instance Family | GPU | CUDA Architecture |
|-----------------|-----|-------------------|
| g4dn (T4) | NVIDIA T4 | `--cuda-arch 75` |
| g5 (A10G) | NVIDIA A10G | `--cuda-arch 86` |
| g6 (L4) | NVIDIA L4 | `--cuda-arch 89` |

Example with explicit architecture:

```bash
sudo ./install-relion.sh --cuda-arch 86
```

### Installation time

Installation takes 30–60 minutes depending on instance type (Spack dependency resolution + Relion compilation).
The script prints status messages for each phase so you can monitor progress.

### Verify Relion installation

```bash
source /etc/profile.d/relion.sh
which relion    # Should show /shared/relion/bin/relion
```

## Step 5: Verify End-to-End

Run through this checklist to confirm everything is working together.

### 1. DCV session accessible

Open `https://<instance-ip>:8443` in your browser and log in with `ec2-user`. ✓

### 2. Slurm connectivity from DCV session

Open a terminal in the DCV desktop session and run:

```bash
sinfo    # Should show cluster partitions
```

### 3. Submit a test job

```bash
sbatch --wrap="hostname && nvidia-smi" -o /shared/test-job.out --gres=gpu:1
squeue   # Watch job status
cat /shared/test-job.out  # Verify output after job completes
```

### 4. Launch Relion GUI

```bash
cd /shared
mkdir -p relion-project && cd relion-project
relion &
```

The Relion GUI should appear in your DCV session.

### 5. Verify shared data access

Confirm that Relion can read and write files on the FSx for Lustre mount at `/shared`.
Any data placed in `/shared` is accessible from both the DCV workstation and compute nodes.

## Operational Guidance

### Connecting to DCV

You can connect to the DCV session using:

- **Web browser**: Navigate to `https://<instance-ip>:8443`. Works from any device without additional software.
- **Native DCV client**: Download from [NICE DCV client downloads](https://docs.aws.amazon.com/dcv/latest/userguide/client.html). Provides better performance for 3D visualization and GPU-accelerated rendering.

### Stop/Start for Cost Savings

Stop the DCV workstation instance when not in use to avoid GPU instance charges.
On restart, the sackd and DCV services restart automatically (systemd enabled).

To resume work after a restart:

```bash
# Source the activate script (or rely on .bashrc if you added it earlier)
source /home/ec2-user/activate-pcs-<cluster-name>
```

### Instance Type Recommendations

| Instance Type | Use Case | Notes |
|---------------|----------|-------|
| g4dn.xlarge | Budget option | Good for basic visualization, 1 T4 GPU |
| g5.xlarge | Recommended | Better GPU (A10G), good for interactive Relion use |
| g5.2xlarge+ | Heavy preprocessing | More CPU/RAM for local preprocessing tasks |

### Service Recovery After Restart

After stopping and starting the instance, verify services are running:

```bash
systemctl status dcvserver       # DCV server should be active
systemctl status sackd-pcs-*     # sackd service should be active
```

Both services are configured to start automatically via systemd.

## Production Considerations

### Active Directory Integration

For production deployments, replace local password authentication with Active Directory (AD):

- Join the DCV instance to AWS Managed Microsoft AD.
- Configure SSSD/PAM for AD authentication.
- AD users get consistent UID/GID across all nodes, eliminating permission workarounds.
- Reference the [`pcs/multiuser_demo`](../multiuser_demo/) recipe for AD integration patterns with PCS.

### Multi-User Access

Multiple AD users can have separate DCV sessions on the same instance, each authenticated via AD credentials.
This enables shared infrastructure with per-user isolation.

### Secrets Management

In production, avoid passing the DCV password as a CloudFormation parameter.
Use AWS Secrets Manager or AD authentication instead for credential management.

## Cost Estimation

Primary cost drivers for this architecture:

| Resource | Approximate Cost | Notes |
|----------|-----------------|-------|
| DCV workstation (g4dn.xlarge) | ~$0.526/hr | Charged while instance is running |
| DCV workstation (g5.xlarge) | ~$1.006/hr | Charged while instance is running |
| Compute nodes (GPU) | Per-job only | PCS scales to zero when idle |
| FSx for Lustre | ~$0.14/GB-month | 1.2 TB minimum ≈ $168/month |
| Data transfer | Minimal | Stays within the same AZ |

**Tip:** Stop the DCV workstation when not in use to avoid GPU instance charges.
Compute nodes are only charged when jobs are running (PCS scales the node group to zero automatically).

## Troubleshooting

### DCV connection refused

- Verify the security group allows inbound traffic on port 8443 from your IP.
- Confirm the instance is in the `running` state.
- Check the DCV server status: `systemctl status dcvserver`.

### sackd service won't start

- Check service logs: `journalctl -u sackd-pcs-*`.
- Verify the security group allows traffic on port 6817 between the DCV workstation and the PCS cluster endpoint.
- Verify IAM permissions (`pcs:GetCluster`, `secretsmanager:GetSecretValue`).

### Slurm commands timeout

- Check network connectivity between the public and private subnets.
- Verify security group egress rules allow outbound traffic to the PCS endpoint.
- Confirm the activate script has been sourced: `echo $SLURM_CONF`.

### Relion GUI won't launch

- Ensure you are in an active DCV session (not just SSH).
- Check the DISPLAY variable: `echo $DISPLAY`.
- Verify the GPU is accessible: `nvidia-smi`.
- Confirm Relion is in PATH: `source /etc/profile.d/relion.sh && which relion`.

### FSx mount not accessible

- Check security group rules allow Lustre ports (988, 1021–1023) between the instance and FSx.
- Verify the mount: `df -h | grep shared`.
- Check the FSx filesystem status in the AWS console.

### Cannot run Slurm commands

- Source the activate script: `source /home/ec2-user/activate-pcs-<cluster-name>`.
- Verify PATH includes Slurm binaries: `which sinfo`.
- Check `sinfo` output for error messages.

## Cleanup

Delete resources in reverse order to avoid orphaned dependencies:

1. **Delete the DCV workstation CloudFormation stack** — removes the GPU instance, security group rules, and IAM role.
2. **Delete the PCS cluster CloudFormation stack** (from `pcs/getting_started`) — removes the cluster, node groups, networking, and FSx filesystem.
3. **If you created filesystems separately**, delete those last after confirming no instances reference them.

**Note:** If you created additional PCS resources (extra node groups, queues) beyond what the CloudFormation stack manages, delete those in the PCS console before deleting the CloudFormation stack.
