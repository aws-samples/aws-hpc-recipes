# RES Blue/Green Deployment Infrastructure

## Info

This recipe provides infrastructure resources to support a blue/green deployment pattern for [Research and Engineering Studio (RES) on AWS](https://aws.amazon.com/hpc/res/). It enables you to maintain two parallel RES environments (blue and green) for zero-downtime upgrades and easy rollback capabilities.

The recipe includes:
- ACM wildcard certificate management with automatic renewal
- Lambda function for VDI certificate updates
- EC2 Image Builder infrastructure for custom AMI creation

## How It Works

### Blue/Green Deployment Pattern

This recipe enables a blue/green deployment strategy where:
- **Blue environment**: Your current production RES installation
- **Green environment**: New version for testing and validation

**Benefits for RES:**

- **Zero-downtime upgrades**: Deploy and validate new RES versions without impacting active users or disrupting running virtual desktops
- **Risk mitigation**: Test RES upgrades, configuration changes, and new features in the green environment while blue remains operational
- **Instant rollback**: Quickly revert to the previous environment if issues arise by updating DNS records
- **Extended validation**: Keep both environments running simultaneously to validate performance, stability, and compatibility with your workflows
- **User session continuity**: Active VDI sessions remain connected during the switch, as both environments share the same wildcard certificate and can access the same backend storage

**Typical workflow:**
1. Deploy RES v1.0 to the blue environment (production)
2. Build and deploy RES v1.1 to the green environment
3. Validate green environment functionality and performance
4. Update Route 53 DNS to point to green environment
5. Monitor green environment as new production
6. Keep blue environment available for quick rollback if needed
7. Once green is stable, repurpose blue for the next upgrade cycle

### Switching Between Environments with CNAME Records

The key to zero-downtime blue/green deployments is using DNS CNAME records to control which environment receives production traffic. This approach allows you to instantly switch between blue and green environments or quickly rollback if issues arise.

#### DNS Setup

When deploying RES in a blue/green pattern, configure your Route 53 hosted zone with the following DNS records:

```
# Blue environment (web portal and VDI gateway)
web.blue.yourresdomain.com → A record (alias) → blue-res-alb-123456789.us-east-1.elb.amazonaws.com
vdi.blue.yourresdomain.com → A record (alias) → blue-res-nlb-123456789.us-east-1.elb.amazonaws.com

# Green environment (web portal and VDI gateway)
web.green.yourresdomain.com → A record (alias) → green-res-alb-987654321.us-east-1.elb.amazonaws.com
vdi.green.yourresdomain.com → A record (alias) → green-res-nlb-987654321.us-east-1.elb.amazonaws.com

# Production pointers (initially point to blue)
web.yourresdomain.com → CNAME → web.blue.yourresdomain.com
vdi.yourresdomain.com → CNAME → vdi.blue.yourresdomain.com
```

**Key concepts:**
- **Separate web and VDI endpoints**: RES uses different endpoints for the web portal (ALB) and VDI gateway (NLB)
- **Environment-specific A records**: `web.blue.yourresdomain.com` and `vdi.blue.yourresdomain.com` use A records (alias records) pointing directly to their respective load balancer DNS names
- **Production CNAMEs**: `web.yourresdomain.com` and `vdi.yourresdomain.com` are CNAMEs that point to either the blue or green environment subdomains
- **Atomic switching**: Update both production CNAMEs together to switch all traffic from one environment to another
- **Wildcard certificate coverage**: The `*.yourresdomain.com` certificate created by this recipe covers the `blue` and `green` subdomains

#### Switching to Green Environment

Once you've validated your green environment, switch production traffic with a single DNS update:

**Using AWS CLI:**
```bash
# Get the current hosted zone ID
ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name yourresdomain.com \
  --query "HostedZones[0].Id" \
  --output text | cut -d'/' -f3)

# Update both production CNAMEs to point to green environment
aws route53 change-resource-record-sets \
  --hosted-zone-id $ZONE_ID \
  --change-batch '{
    "Changes": [
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "web.yourresdomain.com",
          "Type": "CNAME",
          "TTL": 60,
          "ResourceRecords": [{"Value": "web.green.yourresdomain.com"}]
        }
      },
      {
        "Action": "UPSERT",
        "ResourceRecordSet": {
          "Name": "vdi.yourresdomain.com",
          "Type": "CNAME",
          "TTL": 60,
          "ResourceRecords": [{"Value": "vdi.green.yourresdomain.com"}]
        }
      }
    ]
  }'
```

**Using AWS Console:**
1. Navigate to Route 53 → Hosted zones
2. Select your domain's hosted zone
3. Find the CNAME record for `web.yourresdomain.com`
4. Click **Edit record**
5. Change the value from `web.blue.yourresdomain.com` to `web.green.yourresdomain.com`
6. Set TTL to 60 seconds (for faster propagation)
7. Click **Save changes**
8. Repeat steps 3-7 for the `vdi.yourresdomain.com` CNAME record, changing from `vdi.blue.yourresdomain.com` to `vdi.green.yourresdomain.com`

#### TTL Considerations

- **Before switching**: Lower the TTL on your production CNAME records (`web.yourresdomain.com` and `vdi.yourresdomain.com`) to 60 seconds (or lower) at least 24 hours before the planned switch. This ensures faster propagation when you make the switch.
- **During operation**: Keep TTL at 60 seconds during the validation period for quick rollback capability.
- **After stabilization**: Once the new environment is stable and the old environment is decommissioned, you can increase TTL to 300-3600 seconds to reduce DNS query costs.

#### Monitoring the Switch

After updating DNS records DNS propagation can be verified:

   ```bash
   # Check what DNS servers are returning for web endpoint
   dig web.yourresdomain.com CNAME +short
   
   # Check what DNS servers are returning for VDI endpoint
   dig vdi.yourresdomain.com CNAME +short
   
   # Check from specific DNS servers (Google DNS)
   dig @8.8.8.8 web.yourresdomain.com CNAME +short
   dig @8.8.8.8 vdi.yourresdomain.com CNAME +short
   ```
   
### Certificate Management

This recipe creates a wildcard ACM certificate (e.g., `*.yourresdomain.com`) that covers both blue and green RES environments, allowing seamless switching between deployments without certificate issues. The Terraform modules handle the initial certificate creation and automatic DNS validation through Route 53.

When ACM automatically renews the certificate (typically 60 days before expiration), a Lambda function triggered by EventBridge exports the renewed certificate and private key, then updates AWS Secrets Manager secrets. This ensures both RES environments always have access to valid certificates for VDI sessions through the VDC Gateway, maintaining uninterrupted secure connections during blue/green transitions.

### Image Builder Integration

The recipe creates an EC2 Image Builder infrastructure configuration customized to work with a blue/green deployment pattern, allowing you to build custom AMIs with pre-installed software and configurations for your RES environments.

## Prerequisites

Before using this recipe, ensure you have:

- **Terraform** (v1.0 or later) - [Install Terraform](https://developer.hashicorp.com/terraform/install)
- **Docker** - Required for building Lambda deployment packages
- **AWS CLI** configured with appropriate credentials
- A registered domain name for RES access
- Networking (VPC, Subnet(s)) for RES environment
- Route 53 hosted zone for DNS validation
- Sufficient AWS permissions to create IAM roles, Lambda functions, and EC2 resources

## Quick Start

1. **Clone the repository and navigate to the recipe:**
   ```bash
   git clone https://github.com/aws-samples/aws-hpc-recipes.git
   cd recipes/res/res_blue_green/assets
   ```
   
2. **Initialize Terraform:**
   ```bash
   terraform init   
   ```

3. **Configure your deployment:**
   ```bash
   cp terraform.tfvars.sample terraform.tfvars
   ```
   
   Edit `terraform.tfvars` with your settings (_example below_):
   ```hcl
   region = "us-east-1"
   domain_name = "yourresdomain.com"
   additional_tags = {
     "project" = "res-blue-green"
   }
   vpc_id                              = "vpc-XXXXXXXXXX"
   image_builder_infrastructure_subnet = "subnet-YYYYYYYYY"
   ```

4. **Deploy the Terraform infrastructure:**
   ```bash
   terraform plan
   terraform apply
   ```

### Variables

#### Required Variables

| Variable Name                           | Description                                      | Type   |
| ----------------------------------------|--------------------------------------------------|--------|
| `domain_name`                           | Your RES Domain Name                             | string |
| `vpc_id`                                | The VPC ID for RES-Ready AMI infrastructure      | string |
| `image_builder_infrastructure_subnet`   | The subnet ID for RES-Ready AMI infrastructure   | string |

#### Optional Variables

| Variable Name      | Description                              | Type         | Default      |
| -------------------|------------------------------------------|--------------|--------------|
| `region`           | AWS Deployment region                    | string       | `us-east-1`  |
| `additional_tags`  | Additional tags to apply to all resources| map(string)  | `{}`         |

### Outputs

After deployment, you'll have access to:
- ACM wildcard certificate for your domain to handle blue/green RES deployment
- Lambda function for certificate renewal
- EC2 ImageBuilder Infrastructure configuration for building [RES-Ready AMIs](https://docs.aws.amazon.com/res/latest/ug/res-ready-ami.html)

The following outputs will be used when deploying your RES environment.  Refer to [Launch your product](https://docs.aws.amazon.com/res/latest/ug/launch-the-product.html) for more details on these parameters.

| Output | Description | 
| --- | ---| 
| ACMCertificateARNforWebApp | Certificate ARN for the RES portal|
| CertificateSecretARNforVDI | Secrets Manager ARN for the certificate used for the VDC Gateway| 
| PrivateKeySecretARNforVDI | Secrets Manager ARN for the private key used for the VDC Gateway|

_A snippet of the expected outputs_

```
Outputs:

ACMCertificateARNforWebApp = "arn:aws:acm:us-east-1:..."
CertificateSecretARNforVDI = "arn:aws:secretsmanager:us-east-1:654654228593:secret:Certificate-res-blue-green-..."
PrivateKeySecretARNforVDI = "arn:aws:secretsmanager:us-east-1:654654228593:secret:PrivateKey-res-blue-green-..."
```

## Cleaning Up

To remove all resources:

   ```bash
   terraform destroy
   ```

## Cost Estimate

Running this infrastructure incurs costs for:
- AWS Lambda invocations (minimal, only on certificate renewal)
- CloudWatch Logs retention
- EC2 Image Builder (only when building AMIs)
- ACM certificates - $149 for wildcard domain

Most resources are serverless or pay-per-use, keeping idle costs minimal.
