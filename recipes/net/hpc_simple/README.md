# HPC Simple Networking

## Info

This recipe demonstrates a basic cloud networking setup for HPC on AWS. Several other recipes can consume the VPC and subnet(s) configured by this recipe. 

## Usage

There are two templates in this recipe. One creates a public subnet in an Availability Zone. The other creates a public and private subnet in the same Availability Zone. 

* Create [Public and Private subnets](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=simple-networking-pubpriv&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/net/hpc_simple/assets/public-private.yaml)
* Create a [Public subnet](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=simple-networking-pub&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/net/hpc_simple/assets/public.yaml)

If you don't wish to use the quick-create links, you can also download the [assets/public-private.yaml](assets/public-private.yaml) or [assets/public.yaml](assets/public.yaml) files and uploading them to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation).

Once your networking stack has been created, you may wish to [activate termination protection](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-protect-stacks.html) for it since you may come to depend on the network assets it creates. 

### Importing into other CloudFormation Stacks

These templates export several variables, namedspaced by stack name. This lets you import them into other stacks.

* VPC - the provisioned VPC
* DefaultPublicSubnet - the public subnet in the VPC
* DefaultPrivateSubnet - the private subnet in the VPC (empty if non-existent)
* InternetGatewayId - the internet gateway for the VPC

## Cost Estimate

* VPC and Subnets - No Charge
* Internet Gateway - No charge, but you pay a small amount for traffic passing out of the VPC.
* NAT Gateway - There is a region-specific hourly cost for the NAT gatway, plus a charge for data sent through the gateway.

See [AWS VPC pricing](https://aws.amazon.com/vpc/pricing/) for details.
