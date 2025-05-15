# Zonal HPC Network Architecture

This sample CloudFormation template demonstrates a multi-zone network architecture for HPC workloads following NIST 800-223 guidelines.

> **⚠️ Important**: This is a sample template intended for learning and development purposes. Additional security controls, monitoring, and operational considerations would be needed for production use.

The template demonstrates how to create a VPC with dedicated subnets for compute, access, management, and storage workloads. It showcases automatic detection of HPC-compatible AZs, configurable internet access patterns, and optional deployment of backup AZs. 

## Usage

Download the [assets/network.cfn.yaml](assets/network.cfn.yaml) file and upload it to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation). Then, proceed with creating a stack. 

The template is is pre-configured with sensible defaults. 

For networking, the IP ranges are:
- VPC CIDR: 10.0.0.0/16
- Compute: 10.0.0.0/21 (larger allocation for compute resources)
- Access: 10.0.8.0/24
- Management: 10.0.9.0/24
- Storage: 10.0.10.0/24
- Transit: 10.0.11.0/24 (when transit mode is enabled)

For external connectivitly, it defaults to direct internet acess via the "access" subnets. It can also implement the transit VPC pattern, or configure no internet connectivity. 

For redundancy, it defaults to creating backup subnets in another AZ. 

On the topic of AZs, by default the template attempts to select the AZ that has HPC* instances. If you are using a region without HPC instances or you wish to manually specify the AZ, you can provide a value for `AvailabilityZoneID`. The backup AZ is also automatically selected, unless you specify it with `AvailabilityZoneBackupID`. 

## Importing into other CloudFormation Stacks

The template export key network identifiers, so you can use them in other stacks:

- VPC ID
- Primary subnet IDs (Compute, Access, Management, Storage, Transit)
- Backup subnet IDs (when enabled)

All outputs include export names following the convention: `${AWS::StackName}-[ResourceType]Id`

## Cost Estimate

* VPC and Subnets - No Charge
* Internet Gateway - No charge, but you pay a small amount for traffic passing out of the VPC.
* NAT Gateway - There is a region-specific hourly cost for the NAT gatway, plus a charge for data sent through the gateway.

See [AWS VPC pricing](https://aws.amazon.com/vpc/pricing/) for details.

## Production considerations

This sample template provides a starting point for understanding HPC networking on AWS while following security best practices. For production use, you would need to consider:
- Security group configurations
- Network ACL rules
- Monitoring and logging
- Backup and recovery procedures
- Cost optimization
- Compliance requirements beyond basic network zoning
- Resource tagging strategy
- Encryption requirements

## Cleaning Up

When you are done using this networking configuration, you can delete it by navigating to the AWS CloudFormation console and deleting the relevant stack. If you have enabled termination protection, you will need to disable it first.
