# DLAMI for PCS (ImageBuilder)

Build [AWS PCS](https://docs.aws.amazon.com/pcs/)-ready AMIs from [DLAMI Base GPU](https://docs.aws.amazon.com/dlami/) images using [EC2 Image Builder](https://docs.aws.amazon.com/imagebuilder/) pipelines.

## Overview

This recipe deploys Image Builder pipelines that create PCS-compatible AMIs based on the Deep Learning AMI (DLAMI). It's designed for users running GPU-accelerated workloads (ML training, simulation, rendering, etc.) on AWS Parallel Computing Service.

**What you get:**

- Four AMI pipelines covering Amazon Linux 2023 and Ubuntu 24.04 on both x86_64 and arm64
- Each AMI pre-installed with: AWS PCS Agent, Slurm 24.11 & 25.05, EFS Utils, CloudWatch Agent, SSM Agent
- Flexible build options: manual triggers, scheduled builds (weekly/monthly), or automatic rebuilds when AWS releases new DLAMIs
- Optional SSM Parameter Store publishing for easy AMI discovery in your infrastructure code
- Optional lifecycle policy to automatically deprecate old AMIs (keeps your console clean without breaking existing PCS clusters)

**AMIs produced:**

| AMI Name | OS | Architecture |
|----------|-----|--------------|
| `dlami-for-pcs-base-al2023-x86_64` | Amazon Linux 2023 | x86_64 |
| `dlami-for-pcs-base-al2023-arm64` | Amazon Linux 2023 | arm64 |
| `dlami-for-pcs-base-ubuntu2404-x86_64` | Ubuntu 24.04 | x86_64 |
| `dlami-for-pcs-base-ubuntu2404-arm64` | Ubuntu 24.04 | arm64 |

## Quick Start

### 1. Deploy the Stack

Deploy in the **same region where you run PCS** (pipelines build AMIs locally):

```shell
aws cloudformation create-stack \
    --region us-east-2 \
    --capabilities CAPABILITY_IAM \
    --stack-name dlami-for-pcs \
    --template-url https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/dlami_for_pcs_imagebuilder/assets/dlami-for-pcs.yaml
```

Or use the [CloudFormation Console](https://console.aws.amazon.com/cloudformation) with this template URL:
```
https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/dlami_for_pcs_imagebuilder/assets/dlami-for-pcs.yaml
```

### 2. Build an AMI

By default, builds are manual. Trigger a pipeline:

```shell
# Get pipeline ARN (example: AL2023 x86_64)
PIPELINE_ARN=$(aws cloudformation describe-stacks \
    --stack-name dlami-for-pcs \
    --query "Stacks[0].Outputs[?OutputKey=='PipelineAl2023X8664Arn'].OutputValue" \
    --output text)

# Start the build (~30-45 minutes per AMI)
aws imagebuilder start-image-pipeline-execution --image-pipeline-arn $PIPELINE_ARN
```

Or use the [Image Builder Console](https://console.aws.amazon.com/imagebuilder/home#/pipelines): select a pipeline → **Actions** → **Run pipeline**.

### 3. Get the AMI ID

```shell
# List your built AMIs
aws ec2 describe-images \
    --owners self \
    --filters "Name=name,Values=dlami-for-pcs-*" \
    --query 'Images[*].{Name:Name,ImageId:ImageId,Created:CreationDate}' \
    --output table
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `SemanticVersion` | `1.0.0` | Version for ImageBuilder recipes (format: X.Y.Z) |
| `BuildSchedule` | `Manual` | Build frequency: `Manual`, `Weekly` (Sundays 00:00 UTC), or `Monthly` (1st of month) |
| `PublishToSsm` | `false` | Publish AMI IDs to [SSM Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html) for easy discovery |
| `SsmParameterPrefix` | `/dlami-for-pcs` | Prefix for SSM parameters (e.g., `/dlami-for-pcs/al2023/x86_64/latest`) |
| `EnableLifecyclePolicy` | `false` | Auto-deprecate old AMIs to reduce console clutter |
| `LifecycleDeprecateAfterWeeks` | `4` | Deprecate AMIs older than N weeks (1-52) |

## Scheduled Builds

For automated AMI freshness, deploy with a build schedule:

```shell
aws cloudformation create-stack \
    --region us-east-2 \
    --capabilities CAPABILITY_IAM \
    --stack-name dlami-for-pcs \
    --parameters \
        ParameterKey=BuildSchedule,ParameterValue=Weekly \
        ParameterKey=PublishToSsm,ParameterValue=true \
        ParameterKey=EnableLifecyclePolicy,ParameterValue=true \
    --template-url https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/dlami_for_pcs_imagebuilder/assets/dlami-for-pcs.yaml
```

This configuration:
- Rebuilds all 4 AMIs every Sunday at midnight UTC
- Publishes AMI IDs to SSM parameters for easy reference
- Deprecates AMIs older than 4 weeks (they remain usable, just hidden from searches)

### Using SSM Parameters

When `PublishToSsm=true`, reference AMIs dynamically in CloudFormation:

```yaml
# Always uses the latest built AMI
ImageId: '{{resolve:ssm:/dlami-for-pcs/al2023/x86_64/latest}}'
```

Or retrieve via CLI:
```shell
aws ssm get-parameter --name /dlami-for-pcs/al2023/x86_64/latest --query 'Parameter.Value' --output text
```

## Auto-Rebuild on DLAMI Updates

AWS publishes DLAMI updates approximately weekly to a public SNS topic. You can deploy an optional trigger stack that automatically starts your pipelines when new DLAMIs are released.

**Architecture:**
```
AWS DLAMI SNS Topic (us-west-2) → SQS Queue → Lambda → Your ImageBuilder Pipelines
```

**Deploy the trigger stack** (must be in `us-west-2` where the SNS topic lives):

```shell
# Set your main stack's region and name
REGION=us-east-2
STACK_NAME=dlami-for-pcs

# Deploy trigger in us-west-2
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

The trigger stack subscribes to AWS's DLAMI update notifications and invokes your pipelines cross-region whenever a new DLAMI is published.

**Cleanup:** Delete the trigger stack before deleting the main stack:
```shell
aws cloudformation delete-stack --region us-west-2 --stack-name dlami-update-trigger
```

## AMI Lifecycle Management

With weekly or event-driven builds, AMIs accumulate quickly. Enable lifecycle management to keep your EC2 console clean:

```shell
--parameters ParameterKey=EnableLifecyclePolicy,ParameterValue=true
```

**How it works:**
- AMIs older than `LifecycleDeprecateAfterWeeks` are marked as **deprecated**
- Deprecated AMIs **remain fully functional** — PCS compute node groups can still launch instances
- Deprecated AMIs are hidden from EC2 console searches and `describe-images` (use `--include-deprecated` to see them)
- At least 1 AMI is always kept visible, regardless of age

**To also delete old AMIs** (and reclaim snapshot storage), manually add a DELETE rule via the [Image Builder Lifecycle Policies console](https://console.aws.amazon.com/imagebuilder/home#/lifecyclePolicies). The DELETE action supports both age-based and count-based filters.

## Stack Outputs

| Output | Description |
|--------|-------------|
| `PipelineAl2023X8664Arn` | Amazon Linux 2023 x86_64 pipeline ARN |
| `PipelineAl2023Arm64Arn` | Amazon Linux 2023 arm64 pipeline ARN |
| `PipelineUbuntu2404X8664Arn` | Ubuntu 24.04 x86_64 pipeline ARN |
| `PipelineUbuntu2404Arm64Arn` | Ubuntu 24.04 arm64 pipeline ARN |
| `SsmParameterAl2023X8664` | SSM parameter path for AL2023 x86_64 AMI (when enabled) |
| `SsmParameterAl2023Arm64` | SSM parameter path for AL2023 arm64 AMI (when enabled) |
| `SsmParameterUbuntu2404X8664` | SSM parameter path for Ubuntu 24.04 x86_64 AMI (when enabled) |
| `SsmParameterUbuntu2404Arm64` | SSM parameter path for Ubuntu 24.04 arm64 AMI (when enabled) |
| `LifecyclePolicyArn` | Lifecycle policy ARN (when enabled) |

## Cost Estimate

| Item | Cost |
|------|------|
| Per build (all 4 AMIs) | ~$5-10 USD (EC2 + EBS for ~30-45 min each) |
| AMI storage | ~100 GB EBS snapshots per AMI |
| SSM parameters | Minimal |
| Lambda (SSM updates) | Minimal |

**Tips:** Use `Manual` builds if you don't need frequent updates. Enable lifecycle policy to deprecate (or delete) old AMIs and reduce snapshot storage costs.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Build fails with "Unable to resolve SSM parameter" | DLAMI may not be available in your region. Check [DLAMI availability](https://docs.aws.amazon.com/dlami/latest/devguide/find-dlami-id.html). |
| Build fails during component installation | Check [CloudWatch Logs](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups$3FlogGroupNameFilter$3D$252Faws$252Fimagebuilder) under `/aws/imagebuilder/` for details. Ensure instances have internet access (NAT Gateway or IGW). |
| SSM parameters not updating after build | Verify `PublishToSsm=true`. Check Lambda logs at `/aws/lambda/<stack-name>-ssm-update`. |
| Stack deletion fails | Cancel any in-progress pipeline executions first. You may need to manually delete AMIs created by the pipelines. |
| DLAMI update trigger not firing | Trigger stack must be in `us-west-2`. Check Lambda logs at `/aws/lambda/<trigger-stack-name>-trigger`. |

## Additional Details

### Slurm Version Compatibility

Both Slurm 24.11 and 25.05 are installed for compatibility with any PCS cluster version. The default PATH prioritizes 24.11 (forward-compatible with newer controllers):

```bash
# Default: /opt/aws/pcs/scheduler/slurm-24.11/bin is first in PATH

# To use Slurm 25.05 instead:
export PATH=/opt/aws/pcs/scheduler/slurm-25.05/bin:$PATH
```

### Source AMIs

Pipelines automatically resolve the latest DLAMI Base GPU images via [AWS public SSM parameters](https://docs.aws.amazon.com/dlami/latest/devguide/find-dlami-id.html):

| OS | Architecture | SSM Parameter |
|----|--------------|---------------|
| Amazon Linux 2023 | x86_64 | `/aws/service/deeplearning/ami/x86_64/base-oss-nvidia-driver-gpu-amazon-linux-2023/latest/ami-id` |
| Amazon Linux 2023 | arm64 | `/aws/service/deeplearning/ami/arm64/base-oss-nvidia-driver-gpu-amazon-linux-2023/latest/ami-id` |
| Ubuntu 24.04 | x86_64 | `/aws/service/deeplearning/ami/x86_64/base-oss-nvidia-driver-gpu-ubuntu-24.04/latest/ami-id` |
| Ubuntu 24.04 | arm64 | `/aws/service/deeplearning/ami/arm64/base-oss-nvidia-driver-gpu-ubuntu-24.04/latest/ami-id` |

### Extending This Recipe

- **Multi-region distribution:** Modify `DistributionConfig*` resources. See [Distribute AMIs to specific AWS Regions](https://docs.aws.amazon.com/imagebuilder/latest/userguide/distribute-ami-regions.html).
- **Cross-account sharing:** Add `LaunchPermissionConfiguration` to distribution configs. See [Share AMIs with specific AWS accounts](https://docs.aws.amazon.com/imagebuilder/latest/userguide/cross-account-dist.html).

## See Also

- [AWS PCS Documentation](https://docs.aws.amazon.com/pcs/)
- [DLAMI Developer Guide](https://docs.aws.amazon.com/dlami/)
- [EC2 Image Builder User Guide](https://docs.aws.amazon.com/imagebuilder/)
- [Image Builder Lifecycle Management](https://docs.aws.amazon.com/imagebuilder/latest/userguide/manage-image-lifecycles.html)
