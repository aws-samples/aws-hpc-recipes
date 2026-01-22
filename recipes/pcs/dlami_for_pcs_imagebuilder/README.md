# DLAMI for PCS (ImageBuilder)

## Info

This recipe creates EC2 ImageBuilder pipelines that produce AWS PCS-ready AMIs based on the Deep Learning AMI (DLAMI) Base GPU images. It targets users who want to run GPU-accelerated workloads (modeling, simulation, ML training, rendering, etc.) on AWS Parallel Computing Service.

The recipe builds four AMIs covering two operating systems and two architectures:

| AMI Name | Operating System | Architecture |
|----------|------------------|--------------|
| `dlami-for-pcs-base-al2023-x86_64` | Amazon Linux 2023 | x86_64 |
| `dlami-for-pcs-base-al2023-arm64` | Amazon Linux 2023 | arm64 |
| `dlami-for-pcs-base-ubuntu2404-x86_64` | Ubuntu 24.04 | x86_64 |
| `dlami-for-pcs-base-ubuntu2404-arm64` | Ubuntu 24.04 | arm64 |

### What Gets Installed

Each AMI includes:

- **AWS PCS Agent** - Enables instances to register with and be managed by AWS PCS
- **Slurm 24.11** - Workload manager compatible with PCS clusters running Slurm 24.11
- **Slurm 25.05** - Workload manager compatible with PCS clusters running Slurm 25.05
- **EFS Utils** - Amazon EFS mount helper for shared file systems
- **CloudWatch Agent** - Metrics and log collection for monitoring
- **SSM Agent** - AWS Systems Manager agent for remote management

### Slurm Version Compatibility

Both Slurm 24.11 and 25.05 are installed to ensure compatibility with any PCS cluster Slurm version. The PATH is configured with 24.11 first because Slurm has forward compatibility: older clients can communicate with newer slurmctld servers, but not vice versa.

```bash
# Default PATH configuration in /etc/profile.d/slurm.sh
PATH=/opt/aws/pcs/scheduler/slurm-24.11/bin:/opt/aws/pcs/scheduler/slurm-25.05/bin:$PATH
```

If you need to use Slurm 25.05 client features with a 25.05 controller, you can either use the full path or add the following to your shell profile:

```bash
# Use Slurm 25.05 as default
export PATH=/opt/aws/pcs/scheduler/slurm-25.05/bin:$PATH
export MANPATH=/opt/aws/pcs/scheduler/slurm-25.05/share/man:$MANPATH
```

## Usage

### Deploy via AWS CLI

Deploy with default settings (manual builds, no SSM publishing):

```shell
aws cloudformation create-stack \
    --region us-east-2 \
    --capabilities CAPABILITY_IAM \
    --stack-name dlami-for-pcs \
    --template-url https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/dlami_for_pcs_imagebuilder/assets/dlami-for-pcs.yaml
```

Deploy with weekly automatic builds and SSM parameter publishing:

```shell
aws cloudformation create-stack \
    --region us-east-2 \
    --capabilities CAPABILITY_IAM \
    --stack-name dlami-for-pcs \
    --parameters \
        ParameterKey=BuildSchedule,ParameterValue=Weekly \
        ParameterKey=PublishToSsm,ParameterValue=true \
        ParameterKey=SsmParameterPrefix,ParameterValue=/my-org/dlami-for-pcs \
    --template-url https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/dlami_for_pcs_imagebuilder/assets/dlami-for-pcs.yaml
```

### Deploy via AWS Console

1. Navigate to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation)
2. Choose **Create stack** > **With new resources (standard)**
3. Under **Specify template**, choose **Amazon S3 URL** and enter:
   ```
   https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/dlami_for_pcs_imagebuilder/assets/dlami-for-pcs.yaml
   ```
4. Choose **Next**
5. Enter a stack name (e.g., `dlami-for-pcs`)
6. Configure parameters:
   - **SemanticVersion**: Version for ImageBuilder recipes (default: `1.0.0`)
   - **BuildSchedule**: How often to build (Manual, Weekly, or Monthly)
   - **PublishToSsm**: Enable SSM parameter publishing for AMI discovery
   - **SsmParameterPrefix**: Prefix for SSM parameters (default: `/dlami-for-pcs`)
7. Choose **Next**, then **Next** again
8. Under **Capabilities**, check the box acknowledging IAM resource creation
9. Choose **Submit**

### Trigger a Manual Build

After deploying the stack, trigger a pipeline execution:

```shell
# Get pipeline ARNs from stack outputs
aws cloudformation describe-stacks \
    --stack-name dlami-for-pcs \
    --query 'Stacks[0].Outputs[?contains(OutputKey, `Pipeline`)].{Key:OutputKey,Value:OutputValue}' \
    --output table

# Start a pipeline execution (example for AL2023 x86_64)
aws imagebuilder start-image-pipeline-execution \
    --image-pipeline-arn <pipeline-arn-from-output>
```

Or use the EC2 Image Builder console:
1. Navigate to [Image pipelines](https://console.aws.amazon.com/imagebuilder/home#/pipelines)
2. Select a pipeline (e.g., `dlami-for-pcs-al2023-x86-64-*`)
3. Choose **Actions** > **Run pipeline**

### Monitor Build Progress

Building takes approximately 30-45 minutes per image.

1. Navigate to the [EC2 Image Builder console](https://console.aws.amazon.com/imagebuilder/home#/images)
2. Look for images with names starting with `dlami-for-pcs-`
3. Check the **Status** column for build progress

Build logs are available in CloudWatch Logs under `/aws/imagebuilder/`.

### Retrieve AMI IDs

**From SSM Parameters** (if `PublishToSsm` is enabled):

```shell
# Get the latest AL2023 x86_64 AMI
aws ssm get-parameter \
    --name /dlami-for-pcs/al2023/x86_64/latest \
    --query 'Parameter.Value' \
    --output text

# Use in CloudFormation with dynamic references
# {{resolve:ssm:/dlami-for-pcs/al2023/x86_64/latest}}
```

**From EC2 Console**:

```shell
# List AMIs created by the pipelines
aws ec2 describe-images \
    --owners self \
    --filters "Name=name,Values=dlami-for-pcs-*" \
    --query 'Images[*].{Name:Name,ImageId:ImageId,Created:CreationDate}' \
    --output table
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `SemanticVersion` | String | `1.0.0` | Semantic version for ImageBuilder recipes (format: X.Y.Z) |
| `BuildSchedule` | String | `Manual` | Build frequency: `Manual`, `Weekly` (Sundays at midnight UTC), or `Monthly` (1st of month at midnight UTC) |
| `PublishToSsm` | String | `false` | Publish AMI IDs to SSM Parameter Store for easy discovery |
| `SsmParameterPrefix` | String | `/dlami-for-pcs` | Prefix for SSM parameters (only used if `PublishToSsm` is `true`) |

## Outputs

### Pipeline ARNs

| Output | Description |
|--------|-------------|
| `PipelineAl2023X8664Arn` | ARN of the Amazon Linux 2023 x86_64 pipeline |
| `PipelineAl2023Arm64Arn` | ARN of the Amazon Linux 2023 arm64 pipeline |
| `PipelineUbuntu2404X8664Arn` | ARN of the Ubuntu 24.04 x86_64 pipeline |
| `PipelineUbuntu2404Arm64Arn` | ARN of the Ubuntu 24.04 arm64 pipeline |

### SSM Parameter Paths (when `PublishToSsm` is enabled)

| Output | Description |
|--------|-------------|
| `SsmParameterAl2023X8664` | SSM parameter path for AL2023 x86_64 AMI ID |
| `SsmParameterAl2023Arm64` | SSM parameter path for AL2023 arm64 AMI ID |
| `SsmParameterUbuntu2404X8664` | SSM parameter path for Ubuntu 24.04 x86_64 AMI ID |
| `SsmParameterUbuntu2404Arm64` | SSM parameter path for Ubuntu 24.04 arm64 AMI ID |

### Component ARNs

| Output | Description |
|--------|-------------|
| `PcsAgentInstallerComponentArn` | ARN of the PCS Agent Installer component |
| `Slurm2411InstallerComponentArn` | ARN of the Slurm 24.11 Installer component |
| `Slurm2505InstallerComponentArn` | ARN of the Slurm 25.05 Installer component |
| `SlurmPathConfigComponentArn` | ARN of the Slurm PATH Configuration component |
| `EfsUtilsInstallerComponentArn` | ARN of the EFS Utils Installer component |
| `CloudWatchAgentInstallerComponentArn` | ARN of the CloudWatch Agent Installer component |
| `SsmAgentInstallerComponentArn` | ARN of the SSM Agent Installer component |

### IAM Resources

| Output | Description |
|--------|-------------|
| `ImageBuilderRoleArn` | ARN of the IAM role for Image Builder |
| `ImageBuilderInstanceProfileArn` | ARN of the Instance Profile for Image Builder |

## Cost Estimate

### Build Costs (Per Build)

- **EC2 Instance Hours**: c6i.4xlarge/m6i.4xlarge for x86_64, c7g.4xlarge/m7g.4xlarge for arm64. Each build takes ~30-45 minutes.
- **EBS Storage**: 100 GB gp3 volumes during builds

Estimated cost per full build (all 4 AMIs): **$5-10 USD** (varies by region)

### Ongoing Costs

- **AMI Storage**: EBS snapshots (~100 GB each per AMI)
- **SSM Parameters**: Minimal cost if `PublishToSsm` is enabled
- **Lambda**: Minimal cost for SSM update function (invoked only on build completion)

### Cost Optimization Tips

- Use `Manual` build schedule and trigger builds only when needed
- Delete old AMI versions and their snapshots regularly
- Build only the OS/architecture combinations you need

## Notes

### SSM Parameter Publishing

When `PublishToSsm` is enabled, a Lambda function automatically updates SSM parameters after each successful build. This enables:

- **Dynamic AMI references** in CloudFormation templates using `{{resolve:ssm:/dlami-for-pcs/al2023/x86_64/latest}}`
- **Consistent AMI discovery** across your organization
- **Automatic updates** when new AMIs are built

### Source AMI Selection

The template uses SSM parameters to automatically resolve the latest DLAMI Base GPU AMIs:

| OS | Architecture | SSM Parameter Path |
|----|--------------|-------------------|
| Amazon Linux 2023 | x86_64 | `/aws/service/deeplearning/ami/x86_64/base-oss-nvidia-driver-gpu-amazon-linux-2023/latest/ami-id` |
| Amazon Linux 2023 | arm64 | `/aws/service/deeplearning/ami/arm64/base-oss-nvidia-driver-gpu-amazon-linux-2023/latest/ami-id` |
| Ubuntu 24.04 | x86_64 | `/aws/service/deeplearning/ami/x86_64/base-oss-nvidia-driver-gpu-ubuntu-24.04/latest/ami-id` |
| Ubuntu 24.04 | arm64 | `/aws/service/deeplearning/ami/arm64/base-oss-nvidia-driver-gpu-ubuntu-24.04/latest/ami-id` |

### Regional Availability

This recipe works in any AWS region where:
- AWS PCS is available
- DLAMI Base GPU images are available via SSM parameters
- EC2 Image Builder is available

### Automatic Rebuilds on DLAMI Updates (Optional)

AWS publishes DLAMI updates approximately weekly to an SNS topic. You can optionally deploy a second stack that subscribes to this topic and automatically triggers your pipelines when new DLAMIs are released.

**Architecture:**
```
DLAMI SNS Topic (us-west-2) → SQS Queue → Lambda → ImageBuilder Pipelines (your region)
```

**Deploy the trigger stack:**

```shell
# First, get pipeline ARNs from your main stack
REGION=us-east-2  # Your pipeline region
STACK_NAME=dlami-for-pcs

# Deploy trigger stack in us-west-2 (required - SNS topic location)
aws cloudformation create-stack \
    --region us-west-2 \
    --capabilities CAPABILITY_IAM \
    --stack-name dlami-update-trigger \
    --template-url https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/dlami_for_pcs_imagebuilder/assets/dlami-update-trigger.yaml \
    --parameters \
        ParameterKey=TargetRegion,ParameterValue=${REGION} \
        ParameterKey=PipelineAl2023X8664Arn,ParameterValue=$(aws cloudformation describe-stacks --region ${REGION} --stack-name ${STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='PipelineAl2023X8664Arn'].OutputValue" --output text) \
        ParameterKey=PipelineAl2023Arm64Arn,ParameterValue=$(aws cloudformation describe-stacks --region ${REGION} --stack-name ${STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='PipelineAl2023Arm64Arn'].OutputValue" --output text) \
        ParameterKey=PipelineUbuntu2404X8664Arn,ParameterValue=$(aws cloudformation describe-stacks --region ${REGION} --stack-name ${STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='PipelineUbuntu2404X8664Arn'].OutputValue" --output text) \
        ParameterKey=PipelineUbuntu2404Arm64Arn,ParameterValue=$(aws cloudformation describe-stacks --region ${REGION} --stack-name ${STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='PipelineUbuntu2404Arm64Arn'].OutputValue" --output text)
```

**Trigger stack parameters:**

| Parameter | Description |
|-----------|-------------|
| `TargetRegion` | AWS region where your ImageBuilder pipelines are deployed |
| `PipelineAl2023X8664Arn` | ARN of the AL2023 x86_64 pipeline (from main stack outputs) |
| `PipelineAl2023Arm64Arn` | ARN of the AL2023 arm64 pipeline (from main stack outputs) |
| `PipelineUbuntu2404X8664Arn` | ARN of the Ubuntu 24.04 x86_64 pipeline (from main stack outputs) |
| `PipelineUbuntu2404Arm64Arn` | ARN of the Ubuntu 24.04 arm64 pipeline (from main stack outputs) |

**Test the trigger manually:**

```shell
# Send a test message to the SQS queue
QUEUE_URL=$(aws cloudformation describe-stacks --region us-west-2 --stack-name dlami-update-trigger --query "Stacks[0].Outputs[?OutputKey=='QueueUrl'].OutputValue" --output text)

aws sqs send-message \
    --region us-west-2 \
    --queue-url ${QUEUE_URL} \
    --message-body '{"test": "manual trigger"}'

# Check Lambda logs
aws logs tail /aws/lambda/dlami-update-trigger-trigger --region us-west-2 --follow
```

**Cleanup:** Delete the trigger stack before deleting the main stack:
```shell
aws cloudformation delete-stack --region us-west-2 --stack-name dlami-update-trigger
```

### Extending This Recipe

- **Distribute AMIs to multiple regions**: Modify the `DistributionConfig*` resources to include additional regions. See [Distribute AMIs to specific AWS Regions](https://docs.aws.amazon.com/imagebuilder/latest/userguide/distribute-ami-regions.html).

- **Share AMIs with other AWS accounts**: Add `LaunchPermissionConfiguration` to distribution configs. See [Share AMIs with specific AWS accounts](https://docs.aws.amazon.com/imagebuilder/latest/userguide/cross-account-dist.html).

### Troubleshooting

**Build fails with "Unable to resolve SSM parameter"**
- Verify DLAMI Base GPU images are available in your region
- Check that your account has access to the SSM public parameters

**Build fails during component installation**
- Check CloudWatch Logs under `/aws/imagebuilder/` for detailed error messages
- Verify network connectivity (NAT Gateway or Internet Gateway required)

**SSM parameters not updating after build**
- Verify `PublishToSsm` is set to `true`
- Check Lambda function logs in CloudWatch under `/aws/lambda/<stack-name>-ssm-update`

**Stack deletion fails**
- Cancel any in-progress pipeline executions first
- Manually delete AMIs created by the pipelines if needed

**DLAMI update trigger not working**
- Verify the trigger stack is deployed in us-west-2 (required)
- Check Lambda logs in CloudWatch under `/aws/lambda/<trigger-stack-name>-trigger`
- Verify pipeline ARNs in the trigger stack parameters match your main stack outputs
- Check SQS queue for messages: `aws sqs get-queue-attributes --region us-west-2 --queue-url <queue-url> --attribute-names ApproximateNumberOfMessages`

## See Also

- [HPC-Ready AMI Recipe](../hpc_ready_ami/) - General-purpose PCS AMI builder
- [AWS PCS Documentation](https://docs.aws.amazon.com/pcs/)
- [DLAMI Documentation](https://docs.aws.amazon.com/dlami/)
- [EC2 Image Builder Documentation](https://docs.aws.amazon.com/imagebuilder/)

## Contributing

See [`CONTRIBUTING.md`](../../../CONTRIBUTING.md)
