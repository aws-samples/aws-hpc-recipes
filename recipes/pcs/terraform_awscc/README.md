# Demo PCS cluster using the Terraform AWSCC provider

This repository demonstrates how to use the `aws` and `awscc` providers to launch an AWS Parallel Computing Service cluster with Slurm scheduler. The cluster implements a hybrid scaling architecture with static baseline capacity and elastic overflow nodes.

## Cluster Architecture

### Network Topology
- **Management Subnet**: PCS control plane (private)
- **Storage Subnet**: EFS and FSx Lustre filesystems (private)  
- **Compute Subnet**: Compute nodes (private)
- **Access Subnet**: Login nodes with SSH access (public)

### Storage Systems
- **EFS**: Mounted as `/home` on all nodes for user directories
- **FSx Lustre**: Mounted as `/shared` for high-performance scratch workloads

### Compute Node Groups
- **Login**: 1x c6a.xlarge for user access and job submission
- **Static Compute**: 4x c6a.2xlarge always-on nodes (Slurm weight=10)
- **Dynamic Compute**: 0-4x c6a.2xlarge elastic nodes (Slurm weight=100, 5min idle timeout)

### Slurm Configuration
- **Scheduler**: Slurm 25.05 with AWS PCS managed accounting enabled
- **Normal Queue**: Default queue, 48-hour limit, uses static and dynamic nodes
- **Long Queue**: Unlimited runtime, static nodes only
- **Scheduling**: Lower weight = higher priority (static nodes preferred, dynamic for overflow)
- **Accounting**: Standard mode with 7-day purge policy, enforces associations, limits, and QoS

## Prerequisites

- Appropriate AWS IAM permissions to deploy AWS resources
- AWS CLI configured with appropriate permissions
- HashiCorp Terraform installed (version 1.0 or later)
- AWS provider version ~> 6.0
- AWSCC provider version >= 1.59.0 (required for Slurm custom settings support)
- Valid EC2 key pair in target AWS region

## Repository Structure

This project uses both `aws` and `awscc` Terraform providers. The `aws` provider manages VPC, EFS, FSx, IAM, and security groups using [Terraform AWS modules](https://registry.terraform.io/namespaces/terraform-aws-modules). The `awscc` provider manages PCS-specific resources (cluster, compute node groups, queues) that require the latest AWS Cloud Control API features.

```
terraform_awscc/
├── README.md
└── assets/
    ├── main.tf                    # Main configuration (VPC, EFS, FSx, modules)
    ├── variables.tf               # Input variables and validation
    ├── outputs.tf                 # Output definitions
    ├── providers.tf               # AWS and AWSCC provider configuration
    ├── terraform.tfvars.sample    # Sample variable values
    └── modules/
        ├── compute/               # PCS cluster resources (awscc provider)
        │   ├── main.tf           # Cluster, node groups, queues, launch templates
        │   ├── variables.tf      # Compute module variables
        │   ├── outputs.tf        # Compute module outputs
        │   └── templates/        # User data templates
        │       ├── login_userdata.tpl
        │       └── compute_userdata.tpl
        └── iam/                   # IAM roles and policies (aws provider)
            ├── main.tf           # Instance roles and policies
            ├── variables.tf      # IAM module variables
            └── outputs.tf        # IAM module outputs
```

## Getting Started

```
1. Clone the repository:
   git clone https://github.com/aws-samples/aws-hpc-recipes.git
   cd recipes/pcs/demo_tf_awscc/assets

2. Initialize Terraform:
   terraform init

3. Create terraform.tfvars from the sample and customize variables:
   cp terraform.tfvars.sample terraform.tfvars
   # Edit terraform.tfvars with your specific values

4. Deploy the cluster:
   terraform plan
   terraform apply
```

## Configuration

Configure your AWS credentials and region either through environment variables or AWS CLI configuration:

```
export AWS_REGION=<your-region>
export AWS_PROFILE=<your-profile>
```

## Variables

The following variables need to be configured when using this repository:

### Required Variables

| Variable Name      | Description                     | Type   |
| -------------------|---------------------------------|--------|
| `project_name`     | Name prefix for all resources   | string |
| `aws_region`       | Name of the Region to run PCS   | string |
| `availability_zone`| AZ for PCS-related subnets      | string |
| `pcs_cluster_name` | Name of the PCS cluster         | string |
| `ssh_key_name`     | Name of the SSH key pair to use | string |
| `pcs_cng_ami_id`   | ID for PCS sample AMI           | string |

### Optional Variables

| Variable Name                      | Description                           | Type   | Default      |
| -----------------------------------|---------------------------------------|--------|--------------|
| `vpc_cidr`                        | CIDR block for VPC                    | string | 10.0.0.0/16  |
| `ssh_cidr_block`                  | CIDR block allowed for SSH access     | string | 0.0.0.0/0    |
| `pcs_cluster_size`                | Size of PCS cluster (SMALL/MEDIUM/LARGE) | string | SMALL     |
| `pcs_cluster_slurm_version`       | Slurm version                         | string | 25.05        |
| `pcs_cluster_scaledown_idletime`  | Idle timeout for dynamic nodes (seconds) | number | 300       |
| `pcs_cng_login_instance_type`     | Instance type for login nodes         | string | c6a.xlarge   |
| `pcs_cng_compute_instance_type`   | Instance type for compute nodes       | string | c6a.2xlarge  |

Note: Find the AMI ID using the following command, subbing `region-code` for the value of `aws_region`: 

```shell
# Export the region where you will deploy PCS
export REGION_CODE=us-east-2

aws ec2 describe-images --region ${REGION_CODE} \
--filters 'Name=name,Values=aws-pcs-sample_ami-amzn2-x86_64-slurm-25.05*' \
          'Name=owner-alias,Values=amazon' \
          'Name=state,Values=available' \
--query 'sort_by(Images, &CreationDate)[-1].[Name,ImageId]' --output text
```

## Outputs

This Terraform project provides the following outputs:

### Infrastructure Outputs
- `vpc_id`: ID of the created VPC
- `efs_id`: ID of the EFS filesystem
- `efs_dns_name`: DNS name of the EFS filesystem
- `fsx_id`: ID of the FSx Lustre filesystem
- `fsx_dns_name`: DNS name of the FSx Lustre filesystem
- `fsx_mount_name`: Mount name of the FSx Lustre filesystem
- `iam_instance_profile_arn`: ARN of the IAM instance profile

### Security Outputs
- `cluster_security_group_id`: ID of the PCS cluster security group
- `ssh_security_group_id`: ID of the SSH security group

### PCS Cluster Outputs
- `pcs_cluster_id`: ID of the PCS cluster
- `pcs_cluster_console_url`: URL to view the cluster in the PCS console
- `pcs_ec2_console_url`: URL to view the login node in the EC2 console

These outputs can be used to reference resources in other Terraform configurations or to retrieve connection information for the deployed cluster.

## Connecting to the AWS PCS cluster

View the outputs from `terraform apply`. There will be two URLs. 

1. Navigate to the URL for `pcs_cluster_console_url` to visit the cluster you created in the PCS console. Go here to explore the cluster, node group, and queue configuration.
2. Navigate to the URL for `pcs_ec2_console_url` to visit a filtered view of the EC2 console that will show the login node for the cluster. Connect to the instance by choosing **Connect** then **Session Manager**.

Once you have connected to a login instance, follow along with the **Getting Started with AWS PCS** tutorial starting at [Explore the cluster environment in AWS PCS](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started_explore.html).

## IAM Permissions

The deployment requires the following AWS IAM permissions:

### Required AWS Services
- **EC2**: VPC, subnets, security groups, launch templates, instances
- **EFS**: Filesystem creation and management
- **FSx**: Lustre filesystem creation and management
- **IAM**: Role and instance profile creation
- **PCS**: Cluster, compute node group, and queue management
- **SSM**: Session Manager access for login nodes

### Instance Profile Permissions
The created IAM instance profile includes:
- `pcs:RegisterComputeNodeGroupInstance` - Required for PCS node registration
- `AmazonSSMManagedInstanceCore` - Session Manager access
- `AmazonS3ReadOnlyAccess` - S3 access for applications
- `CloudWatchAgentServerPolicy` - CloudWatch logging and monitoring

## Troubleshooting

### Common Issues

**AMI Not Found**
- Ensure the AMI ID is correct for your region
- Verify the AMI is available in your target region
- Use the provided AWS CLI command to find the latest AMI

**SSH Key Pair Not Found**
- Create an EC2 key pair in your target region before deployment
- Ensure the key pair name matches the `ssh_key_name` variable

**Provider Version Conflicts**
- Run `terraform init -upgrade` to update providers
- Ensure AWSCC provider version >= 1.59.0 for Slurm custom settings support

**VPC CIDR Conflicts**
- Modify `vpc_cidr` variable if 10.0.0.0/16 conflicts with existing networks
- Ensure the CIDR block provides sufficient IP addresses for all subnets

**Terraform Destroy Failures**
- Delete additional PCS resources (queues, node groups) in the console first
- Wait for all EC2 instances to terminate before retrying destroy

## Cleaning Up

When you are done using your PCS cluster, you can delete it and all its associated resources by run the following command in the project directory `terraform destroy`. The command will prompt you to confirm the destruction of the resources. Type `yes` to proceed.

However, if you have created additional resources in your cluster, beyond the `login`, `compute-st`, and `compute-dy` node groups, or the `normal` and `long` queues, you must delete those resources in the PCS console before running `terraform destroy`. Otherwise, deleting the resources will fail and you will need to manually delete several resources by hand. 

To delete extra resources, go to detail page for your PCS cluster:

* Delete any queues besides `normal` and `long`
* Delete any node groups besides `login`, `compute-st`, and `compute-dy`

Note: We do not recommend you create or delete any resources in this demonstration cluster. Get started building your own, totally customizable HPC clusters with this tutorial in the AWS PCS user guide.

## Support

Please open an issue in the HPC Recipes GitHub repository for any questions or problems.
