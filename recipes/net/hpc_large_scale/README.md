# HPC Scale Networking

## Info

This recipe demonstrates a cloud networking setup that supports large-scale HPC on AWS. Several other recipes can consume the VPC and subnet(s) configured by this recipe.

It is most useful when your HPC infrastructure meets some or all of these criteria:
1. May need to launch instances in more than one Availability Zone
2. Needs many instances - the default configuration provided by this template creates subnets with several thousand available IP addresses.
3. Integrates with other services that are deployed in multiple Availability Zones, such as AWS Managed Microsoft AD or Amazon Aurora.

## Background

This recipe includes a single CloudFormation template that prepares a VPC suitable for larger-scale computations. It provisions public and private subnets in three Availability Zones in the Region of your choice. By default, the template is configured to create a VPC with a `/16` CIDR block (65,536 addresses) and 6 subnet blocks that supporting 4096 IP addresses each (`/20` CIDR block). You can specify your own CIDR block values when you run the template. 

It is recommended that this stack replace the [hpc_basic](../hpc_basic/) stack, rather than operating both concurrently, as they are largely duplicative in function.

### Usage

You can launch this template by following this quick-create link:

* Create [subnets in three Availability Zones](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=hpc-networking&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/net/hpc_large_scale/assets/main.yaml)

If you don't wish to use the quick-create link, you can also download the [assets/main.yaml](assets/main.yaml) file and uploading it to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation).

Once your networking stack has been created, you may wish to [activate termination protection](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-protect-stacks.html) for it since you may come to depend on the network assets it creates. 

### Importing into other CloudFormation Stacks

This template exports several variables, namedspaced by stack name. This lets you import them into other stacks. 

* VPC - the provisioned VPC
* PublicSubnets - comma-delimited list of public subnet IDs
* PrivateSubnets - comma-delimited list of private subnet IDs
* InternetGatewayId - the internet gateway for the VPC
* SecurityGroup - a security group allowing inbound and outbound communications from the VPC

There are two additional exports that provide compatibility with recipes that rely on the Simple HPC Networking stack. Values for these default to one of the public and/or private subnets defined by the template. The subnets will be in the same Availability Zone.

* DefaultPublicSubnet - a public subnet in the VPC
* DefaultPrivateSubnet - a private subnet in the VPC

## Cost Estimate

* VPC and Subnets - No Charge
* Internet Gateway - No charge, but you pay a small amount for traffic passing out of the VPC.
* NAT Gateway - There is a region-specific hourly cost for the NAT gatway, plus a charge for data sent through the gateway.

See [AWS VPC pricing](https://aws.amazon.com/vpc/pricing/) for details.

## Cleaning Up

When you are done using this networking configuration, you can delete it by navigating to the AWS CloudFormation console and deleting the relevant stack. If you have enabled termination protection, you will need to disable it first.
