# Parakeet audio transcription powered by AWS Batch and NVIDIA GPUs

## Info

This recipe supports the AWS Samples project _Parakeet audio transcription powered by AWS Batch and NVIDIA GPUs_. This CloudFormation template supports one-click deployment of the blog solution.

* Read about the project on the [AWS HPC blog](https://aws.amazon.com/blogs/hpc/)
* [Visit the Github repo](https://github.com/aws-samples/sample-parakeet-transcription-awsbatch-nvidia-blog) to learn about it and launch the solution.

## Quick Infrastructure Deployment

### Prerequisites

* Default VPC with subnets in your target region
* AWS CLI configured with appropriate permissions
* Container image built and pushed to ECR (see the [GitHub repo](https://github.com/aws-samples/sample-parakeet-transcription-awsbatch-nvidia-blog) for instructions)

### Deploy via AWS CLI

```bash
# Set your region
export AWS_REGION=us-east-1

# Get VPC and networking info
VPC_ID=$(aws ec2 describe-vpcs --query 'Vpcs[?IsDefault].VpcId' --output text --region ${AWS_REGION})
SUBNET_IDS=$(aws ec2 describe-subnets --query "Subnets[*].SubnetId" --filters Name=vpc-id,Values=${VPC_ID} --region ${AWS_REGION} --output text | tr '\t' ',')
SG_IDS=$(aws ec2 describe-security-groups --query 'SecurityGroups[*].GroupId' --filters Name=vpc-id,Values=${VPC_ID} Name=group-name,Values=default --region ${AWS_REGION} --output text)
RT_IDS=$(aws ec2 describe-route-tables --query 'RouteTables[*].RouteTableId' --filters Name=vpc-id,Values=${VPC_ID} --region ${AWS_REGION} --output text | sed 's/\s\+/,/g')

# Deploy the stack
aws cloudformation deploy \
  --stack-name batch-gpu-audio-transcription \
  --template-file deployment.yaml \
  --capabilities CAPABILITY_IAM \
  --region ${AWS_REGION} \
  --parameter-overrides \
    VPCId=${VPC_ID} \
    SubnetIds="${SUBNET_IDS}" \
    SGIds="${SG_IDS}" \
    RTIds="${RT_IDS}" \
    CreateS3Endpoint="Yes"
```

### Parameters

* `VPCId` - VPC ID for the Batch compute environment
* `SubnetIds` - Comma-separated list of subnet IDs
* `SGIds` - Security group ID
* `RTIds` - Comma-separated list of route table IDs
* `CreateS3Endpoint` - Whether to create an S3 VPC endpoint (Yes/No)
