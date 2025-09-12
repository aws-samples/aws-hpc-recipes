# Demo PCS cluster using the Terraform AWSCC provider

This repository contains demonstrates how to use the `aws` and `awscc` providers to launch an example AWS Parallel Computing Service cluster. The cluster design mirrors the one found in [Getting Started with AWS Parallel Computing Service](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started.html).

<img src="https://docs.aws.amazon.com/images/pcs/latest/userguide/images/aws-pcs-tutorial-environment-diagram.png" width=600>

## Prerequisites

- Appropriate AWS IAM permissions to deploy AWS resources
- AWS CLI configured with appropriate permissions
- HashiCorp Terraform installed (recommended version: latest)

## Repository Structure

We use [Terraform AWS modules](https://registry.terraform.io/namespaces/terraform-aws-modules) to 
set up a NIST 800-223 zonal VPC and subnets, EFS and FSx for Lustre filesystems, and the cluster 
and SSH security groups. The custom module `iam` sets up the IAM instance profile for 
compute nodes, while the `compute` custom module configures the PCS cluster. 

```
terraform_awscc/
├── README.md
├── assets
│   ├── main.tf # Main Terraform configuration file
│   ├── modules
│   │   ├── compute
│   │   ├── iam
│   ├── outputs.tf # Output definitions
│   ├── providers.tf # Provider configurations
│   └── variables.tf # Variable definitions
```

## Getting Started

```
1. Clone the repository:
   git clone https://github.com/aws-samples/aws-hpc-recipes.git
   cd recipes/pcs/demo_tf_awscc/assets

2. Initialize Terraform:
   terraform init

3. Review and customize the variables as needed.

4. Deploy the custom controls:
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

Note: Find the AMI ID using the following command, subbing `region-code` for the value of `aws_region`: 

```shell
# Export the region where you will deploy PCS
export REGION_CODE=us-east-2

aws ec2 describe-images --region ${REGION_CODE} \
--filters 'Name=name,Values=aws-pcs-sample_ami-amzn2-x86_64-slurm-24.11*' \
          'Name=owner-alias,Values=amazon' \
          'Name=state,Values=available' \
--query 'sort_by(Images, &CreationDate)[-1].[Name,ImageId]' --output text
```

## Outputs

This Terraform project provides the following outputs:

- `vpc_id`: The ID of the VPC created by this project.
- `outputs.tf`: IAM instance profile used by PCS cluster node group instances
- `cluster_security_group_id`: The ID of the PCS cluster security group.
- `ssh_security_group_id`: The ID of a security group allowing inbound SSH access
- `pcs_cluster_id`: The ID of the PCS cluster created by this project
- `pcs_cluster_console_url`: URL to view the created cluster in the PCS console
- `pcs_ec2_console_url`: URL to view to find the PCS cluster login node

These outputs can be used to reference these resources in other parts of your infrastructure or to retrieve information about the deployed resources.

## Connecting to the AWS PCS cluster

View the outputs from `terraform apply`. There will be two URLs. 

1. Navigate to the URL for `pcs_cluster_console_url` to visit the cluster you created in the PCS console. Go here to explore the cluster, node group, and queue configuration.
2. Navigate to the URL for `pcs_ec2_console_url` to visit a filtered view of the EC2 console that will show the login node for the cluster. Connect to the instance by choosing **Connect** then **Session Manager**.

Once you have connected to a login instance, follow along with the **Getting Started with AWS PCS** tutorial starting at [Explore the cluster environment in AWS PCS](https://docs.aws.amazon.com/pcs/latest/userguide/getting-started_explore.html).

## Cleaning Up

When you are done using your PCS cluster, you can delete it and all its associated resources by run the following command in the project directory `terraform destroy`. The command will prompt you to confirm the destruction of the resources. Type `yes` to proceed.

However, if you have created additional resources in your cluster, beyond the `login` and `compute` node groups, or the `demo` queue, you must delete those resources in the PCS console before running `terraform destroy`. Otherwise, deleting the resources will fail and you will need to manually delete several resources by hand. 

To delete extra resources , go to detail page for your PCS cluster:

* Delete any queues besides `demo`
* Delete any node groups besides `login` and `compute-1`

Note: We do not recommend you create or delete any resources in this demonstration cluster. Get started building your own, totally customizable HPC clusters with this tutorial in the AWS PCS user guide.

## Support

Please open an issue in the HPC Recipes GitHub repository for any questions or problems.
