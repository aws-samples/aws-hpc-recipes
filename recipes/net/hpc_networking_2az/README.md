# hpc_networking_2az

## Info

This template will create a virtual private cloud (VPC) with private and public subnets in two availability zones. It is designed to support infrastructure deployments where you need the added capacity or resilience that comes from more than one availability zone. 

## Usage

Five values are required to parameterize this template:
1. A CIDR block for the VPC you will create 
2. A CIDR block for the first public subnet
3. A CIDR block for the second public subnet. This must be in a *different AZ* from the first public subnet.
4. A CIDR block for the first private subnet. It must be in the same AZ as the *first* public subnet.
5. A CIDR block for the second private subnet. It must be in the same AZ as the *second* public subnet.

You can quick-launch in the AWS CloudFormation Console: [![Launch](https://samdengler.github.io/cloudformation-launch-stack-button-svg/images/us-east-2.svg)](https://us-east-2.console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks/create/review?stackName=tutorial-networking&templateURL=https://cfn3-dev-mwvaughn.s3.us-east-2.amazonaws.com/main/recipes/net/hpc_networking_2az/assets/public-private.cfn.yml)

You can also import the template into the AWS CloudFormation console. Navigate to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation/home). Choose **Create stack**, then on the following page, make sure Amazon S3 URL is set as the Template URL. Enter the complete S3 URL for this recipe `https://cfn3-dev-mwvaughn.s3.us-east-2.amazonaws.com/main/recipes/net/hpc_networking_2az/assets/public-private.cfn.yml` and follow through the rest of the launch workflow.

If you want to combine this stack with another, you can embed it as a nested stack. Here's what that might look like.

```yaml
  MyNestedVpc:
    Type: AWS::CloudFormation::Stack
    Properties:
      Parameters:
        CidrBlock: 10.3.0.0/16
        CidrPublicSubnetA: 10.3.128.0/20
        CidrPublicSubnetB: 10.3.144.0/20
        CidrPrivateSubnetA: 10.3.0.0/18
        CidrPrivateSubnetB: 10.3.64.0/18
      TemplateURL: !Sub
        - https://cfn3-dev-mwvaughn.s3.us-east-2.amazonaws.com/main/recipes/net/hpc_networking_2az/assets/public-private.cfn.yml
        - { Region: !Ref AWS::Region }
      TimeoutInMinutes: 10
```

## Acknowledgements

This recipe is based on the networking stack in [1click-HPC](https://github.com/aws-samples/1click-hpc).
