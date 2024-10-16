# HPC Basic Networking

## Info

This recipe demonstrates a basic cloud networking setup for HPC on AWS. Several other recipes can consume the VPC and subnets configured by this recipe. 

It is most useful when your HPC cluster meets these criteria:
1. You only launch instances in one Availability Zone (this is fairly standard)
2. You don't need that many instances - the default configuration provided by this template creates subnets with 250 available IP addresses. 

## Usage

This template creates one public and one private subnet in the same Availability Zone. 

* Create [Public and Private subnets](https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=basic-networking&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/net/hpc_basic/assets/public-private.yaml). The only required parameter is **Availabilty Zone** if you want to create a new VPC. 

If you don't wish to use the quick-create links, you can also download the [assets/public-private.yaml](assets/public-private.yaml) file and uploading it to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation).

Once your networking stack has been created, you may wish to [activate termination protection](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-protect-stacks.html) for it since you may come to depend on the network assets it creates. 

### Importing into other CloudFormation Stacks

The template exports several variables, namedspaced by stack name. This lets you import them into other stacks.

* VPC - the pre-existing or provisioned VPC
* DefaultPublicSubnet - the public subnet in the VPC
* DefaultPrivateSubnet - the private subnet in the VPC
* InternetGatewayId - the pre-existing or provisioned internet gateway for the VPC
* SecurityGroupId - either AWS::NoValue if using an existing VPC or the within-VPC security group if creating a new VPC

## Cost Estimate

* VPC and Subnets - No Charge
* Internet Gateway - No charge, but you pay a small amount for traffic passing out of the VPC.
* NAT Gateway - There is a region-specific hourly cost for the NAT gatway, plus a charge for data sent through the gateway.
* Elastic IP - There is a charge for the elastic IP assigned to the NAT gateway

See [AWS VPC pricing](https://aws.amazon.com/vpc/pricing/) for details.

## Cleaning Up

When you are done using this networking configuration, you can delete it by navigating to the AWS CloudFormation console and deleting the relevant stack. If you have enabled termination protection, you will need to disable it first.
