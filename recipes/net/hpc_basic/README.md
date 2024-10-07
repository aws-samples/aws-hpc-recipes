# HPC Basic Networking

## Info

This recipe demonstrates a basic cloud networking setup for HPC on AWS. Several other recipes can consume the VPC and subnets configured by this recipe. 

It is most useful when you will only launch HPC instances and associated resources in one Availability Zone. If you need to support additional AZs, consider using the [HPC Scale Networking](../hpc_large_scale/) recipe.

## Usage

This template creates one public and one private subnet in a single Availability Zone. 

* Create [Public and Private subnets](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=basic-networking&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/net/hpc_basic/assets/public-private.yaml). 

To create a new VPC and subnets:
* Leave **VpcId** and **InternetGatewayId** empty.
* (Optional) Provide a value for **AvailabilityZone**. If you do not specify an Availability Zone, one will be selected for you.
* (Optional) Set your own CIDR blocks for **VpcCIDR**, **PublicCIDR**, and **PrivateCIDR**.

If you create subnets in an existing VPC:
* Provide values for **VpcId** and **InternetGatewayId**.
* Make sure the values for **PublicCIDR** and **PrivateCIDR** fall within the range of available IPs in the existing VPC.
* (Optional) Provide a value for **AvailabilityZone**. If you do not specify an Availability Zone, one will be selected for you.

If you don't wish to use the quick-create links, you can also download the [assets/public-private.yaml](assets/public-private.yaml) file and uploading it to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation).

Once your networking stack has been created, you may wish to [activate termination protection](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-protect-stacks.html) for it since you may come to depend on the network assets it creates. 

### Importing into other CloudFormation Stacks

The template exports several variables, namedspaced by stack name. This lets you import them into other stacks.

* VPC - the pre-existing or provisioned VPC
* PublicSubnets - comma-delimited list of public subnet IDs
* PrivateSubnets - comma-delimited list of private subnet IDs
* DefaultPublicSubnet - the public subnet in the VPC
* DefaultPrivateSubnet - the private subnet in the VPC
* InternetGatewayId - the pre-existing or provisioned internet gateway for the VPC
* SecurityGroup - a security group allowing inbound and outbound communications from IPs in the VPC

## Cost Estimate

* VPC and Subnets - No Charge
* Internet Gateway - No charge, but you pay a small amount for traffic passing out of the VPC.
* NAT Gateway - There is a region-specific hourly cost for the NAT gatway, plus a charge for data sent through the gateway.

See [AWS VPC pricing](https://aws.amazon.com/vpc/pricing/) for details.

## Cleaning Up

When you are done using this networking configuration, you can delete it by navigating to the AWS CloudFormation console and deleting the relevant stack. If you have enabled termination protection, you will need to disable it first.
