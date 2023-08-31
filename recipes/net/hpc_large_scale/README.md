# HPC Scale Networking

## Info

This recipe demonstrates a cloud networking setup that can support large-scale computation on AWS. Many other recipes rely on the VPC and subnets configuring by this recipe. 

## Background

This recipe includes a CloudFormation template that prepares a VPC suitable for large-scale computations on AWS. It can provision public and/or private subnets in all selected Availability Zones. It can also deploy an Amazon S3 Endpoint, Internet Gateway, and NAT Gateway if you choose. The template creates a VPC with up to 4 CIDR blocks 10.0.0.0/16, 10.1.0.0/16, 10.2.0.0/16 and 10.3.0.0/16 to assist with managing a maximum number of IP addresses. 

You can launch this template in the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation) by importing the [main.yml](assets/main.yml) file or by following this quick-create link:
* [![Launch stack](../../../docs/media/launch-stack.svg)](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=multiuser-cluster&templateURL=https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/net/hpc_large_scale/assets/main.yaml)

Once the stack has been launched successfully, you may wish to [activate termination protection](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-protect-stacks.html) for it since you may come to depend on the network assets it creates. 

## Key Details

The included template is a good example of CloudFormation [Conditions](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/conditions-section-structure.html). They are used to determine how many Availability Zones to create subnets in, whether to create public subnets, and toggle creation of the S3 and DynamoDB endpoints. 

## Cost Estimate

* VPC and Subnets - No Charge
* Internet Gateway - No charge, but you pay a small amount for traffic passing out of the VPC.
* NAT Gateway - There will be a region-specific hourly cost for the NAT gatway, plus a charge for data sent through the gateway. See [AWS VPC pricing](https://aws.amazon.com/vpc/pricing/) for details.

## References

This recipe is based on materials developed for the [AWS HPC Workshops](https://github.com/aws-samples/aws-hpc-tutorials/)

