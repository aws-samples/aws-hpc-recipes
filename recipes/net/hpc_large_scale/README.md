# HPC Scale Networking

## Info

This recipe demonstrates a cloud networking setup that can support large-scale computation on AWS. Several other recipes rely on the VPC and subnets configuring by this recipe. 

## Background

This recipe includes a CloudFormation template that prepares a VPC suitable for larger-scale computations on AWS. It provisions public and private subnets in three Availability Zones. By default, the template is configured with a `/16` CIDR block and 6 subnet blocks supporting 4096 IP addresses each (`/20`). 

### Usage

You can launch this template in the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation) by importing the [main.yml](assets/main.yml) file or by following this quick-create link:
* [![Launch stack](../../../docs/media/launch-stack.svg)](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=multiuser-cluster&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/net/hpc_large_scale/assets/main.yml)

Once the stack has been launched successfully, you may wish to [activate termination protection](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-protect-stacks.html) for it since you may come to depend on the network assets it creates. 

### Importing into other CloudFormation Stacks

This template exports several variables, namedspaced by stack name. This lets you import them into other stacks. 

* VPC - the provisioned VPC
* PublicSubnets - comma-delimited list of public subnet IDs
* PrivateSubnets - comma-delimited list of private subnet IDs
* DefaultPublicSubnet - the first public subnet (A) in the VPC
* DefaultPrivateSubnet - the first private subnet (A) in the VPC
* InternetGatewayId - the internet gateway for the VPC
* SecurityGroup - a security group allowing inbound and outbound communications from the VPC

## Cost Estimate

* VPC and Subnets - No Charge
* Internet Gateway - No charge, but you pay a small amount for traffic passing out of the VPC.
* NAT Gateway - There is a region-specific hourly cost for the NAT gatway, plus a charge for data sent through the gateway.

See [AWS VPC pricing](https://aws.amazon.com/vpc/pricing/) for details.
