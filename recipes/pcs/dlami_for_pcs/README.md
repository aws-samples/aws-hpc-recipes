# DLAMI for PCS

## Info

This recipe creates an EC2 ImageBuilder pipeline that produces AWS PCS-ready AMIs based on the Deep Learning AMI (DLAMI) Base GPU images. It targets users who want to run GPU-accelerated workloads (modeling, simulation, ML training, rendering, etc.) on AWS Parallel Computing Service.

The recipe takes a simplified, all-in-one approach: a single CloudFormation template that builds four AMIs in a single deployment:

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

If you need to use Slurm 25.05 client features with a 25.05 controller, you can either use the full path:

```bash
/opt/aws/pcs/scheduler/slurm-25.05/bin/srun your_job.sh
```

Or add the following to your shell profile (e.g., `~/.bashrc` or `~/.bash_profile`) to make 25.05 the default:

```bash
# Use Slurm 25.05 as default
export PATH=/opt/aws/pcs/scheduler/slurm-25.05/bin:$PATH
export MANPATH=/opt/aws/pcs/scheduler/slurm-25.05/share/man:$MANPATH
```

## Usage

### Deploy via AWS CLI

Download the CloudFormation template or reference it directly from the HPC Recipes S3 bucket:

```shell
aws cloudformation create-stack \
    --region us-east-2 \
    --capabilities CAPABILITY_NAMED_IAM \
    --stack-name dlami-for-pcs \
    --template-url https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/dlami_for_pcs/assets/dlami-for-pcs.yaml
```

To specify a custom semantic version for the ImageBuilder recipes:

```shell
aws cloudformation create-stack \
    --region us-east-2 \
    --capabilities CAPABILITY_NAMED_IAM \
    --parameters ParameterKey=SemanticVersion,ParameterValue=1.0.1 \
    --stack-name dlami-for-pcs \
    --template-url https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/dlami_for_pcs/assets/dlami-for-pcs.yaml
```

### Deploy via AWS Console

1. Navigate to the [AWS CloudFormation console](https://console.aws.amazon.com/cloudformation)
2. Choose **Create stack** > **With new resources (standard)**
3. Under **Specify template**, choose **Amazon S3 URL** and enter:
   ```
   https://aws-hpc-recipes.s3.us-east-1.amazonaws.com/main/recipes/pcs/dlami_for_pcs/assets/dlami-for-pcs.yaml
   ```
4. Choose **Next**
5. Enter a stack name (e.g., `dlami-for-pcs`)
6. Configure parameters:
   - **SemanticVersion**: Version for ImageBuilder recipes (default: `1.0.0`)
7. Choose **Next**, then **Next** again
8. Under **Capabilities**, check the box acknowledging IAM resource creation
9. Choose **Submit**

### Monitor Build Progress

The stack creates EC2 ImageBuilder images that build all four AMIs. Building takes approximately 30-45 minutes per image.

To monitor progress:

1. Navigate to the [EC2 Image Builder console](https://console.aws.amazon.com/imagebuilder/home#/images)
2. Look for images with names starting with `dlami-for-pcs-`
3. Check the **Status** column for build progress

Build logs are available in CloudWatch Logs under `/aws/imagebuilder/`.

### Retrieve AMI IDs

After the stack completes, retrieve the AMI IDs from the CloudFormation outputs:

```shell
aws cloudformation describe-stacks \
    --stack-name dlami-for-pcs \
    --query 'Stacks[0].Outputs[?starts_with(OutputKey, `AmiId`)].{Key:OutputKey,Value:OutputValue}' \
    --output table
```

Or view them in the CloudFormation console under the **Outputs** tab.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `SemanticVersion` | String | `1.0.0` | Semantic version for ImageBuilder recipes (format: X.Y.Z) |

## Outputs

### AMI IDs

| Output | Description |
|--------|-------------|
| `AmiIdAl2023X8664` | AMI ID for Amazon Linux 2023 x86_64 |
| `AmiIdAl2023Arm64` | AMI ID for Amazon Linux 2023 arm64 |
| `AmiIdUbuntu2404X8664` | AMI ID for Ubuntu 24.04 x86_64 |
| `AmiIdUbuntu2404Arm64` | AMI ID for Ubuntu 24.04 arm64 |

### ImageBuilder Resources

| Output | Description |
|--------|-------------|
| `ImageAl2023X8664Arn` | ARN of the Amazon Linux 2023 x86_64 Image |
| `ImageAl2023Arm64Arn` | ARN of the Amazon Linux 2023 arm64 Image |
| `ImageUbuntu2404X8664Arn` | ARN of the Ubuntu 24.04 x86_64 Image |
| `ImageUbuntu2404Arm64Arn` | ARN of the Ubuntu 24.04 arm64 Image |
| `ImageBuilderRoleArn` | ARN of the IAM role for Image Builder |
| `ImageBuilderInstanceProfileArn` | ARN of the Instance Profile for Image Builder |

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

## Cost Estimate

Costs are incurred during the AMI build process and when using the resulting AMIs.

### Build Costs (One-Time)

- **EC2 Instance Hours**: The template uses c6i.4xlarge/m6i.4xlarge for x86_64 builds and c7g.4xlarge/m7g.4xlarge for arm64 builds. Each build takes approximately 30-45 minutes.
- **EBS Storage**: 100 GB gp3 volumes are used during builds
- **Data Transfer**: Minimal, primarily for downloading packages

Estimated one-time build cost: **$5-10 USD** for all four AMIs (varies by region)

### Ongoing Costs

- **AMI Storage**: EBS snapshots for each AMI (~100 GB each)
- **EC2 Instances**: Standard EC2 pricing when launching instances from the AMIs

### Cost Optimization Tips

- Delete unused AMIs and their associated snapshots
- Build only the OS/architecture combinations you need by modifying the template
- Use Spot instances for non-production workloads

## Notes

### Source AMI Selection

The template uses SSM parameters to automatically resolve the latest DLAMI Base GPU AMIs. The SSM parameter format follows the pattern documented in [Finding the ID of a DLAMI](https://docs.aws.amazon.com/dlami/latest/devguide/find-dlami-id.html).

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

### Differences from HPC-Ready AMI Recipe

This recipe differs from the [HPC-Ready AMI recipe](../hpc_ready_ami/) in several ways:

| Feature | DLAMI for PCS | HPC-Ready AMI |
|---------|---------------|---------------|
| Source AMI | DLAMI Base GPU | Standard OS AMIs |
| GPU Drivers | Pre-installed (NVIDIA) | Not included |
| OS Updates | Not applied | Applied |
| Build Method | CloudFormation only | CloudFormation + Packer |
| Complexity | Single template | Multiple components |
| Use Case | GPU workloads | General HPC |

Choose this recipe if you need GPU support with pre-installed NVIDIA drivers. Choose the HPC-Ready AMI recipe for general HPC workloads without GPU requirements.

### Troubleshooting

**Build fails with "Unable to resolve SSM parameter"**
- Verify DLAMI Base GPU images are available in your region
- Check that your account has access to the SSM public parameters

**Build fails during component installation**
- Check CloudWatch Logs under `/aws/imagebuilder/` for detailed error messages
- Verify network connectivity (NAT Gateway or Internet Gateway required)

**Stack deletion fails**
- Ensure all ImageBuilder images have completed building before deletion
- Manually delete any AMIs created by the stack if needed

## See Also

- [HPC-Ready AMI Recipe](../hpc_ready_ami/) - General-purpose PCS AMI builder
- [AWS PCS Documentation](https://docs.aws.amazon.com/pcs/)
- [DLAMI Documentation](https://docs.aws.amazon.com/dlami/)
- [EC2 Image Builder Documentation](https://docs.aws.amazon.com/imagebuilder/)

## Contributing

See [`CONTRIBUTING.md`](../../../CONTRIBUTING.md)
