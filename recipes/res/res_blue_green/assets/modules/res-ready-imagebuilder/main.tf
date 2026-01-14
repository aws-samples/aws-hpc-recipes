# Security Group for Image Builder Infrastructure
resource "aws_security_group" "infrastructure_config" {
  name        = "res-blue-green-image-builder-infra-sg"
  description = "RES blue-green Image Builder Infrastructure Config SG"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "res-blue-green-image-builder-infra-sg"
  }
}

# Security Group Self-Referencing Ingress Rule
resource "aws_security_group_rule" "infrastructure_config_self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.infrastructure_config.id
  source_security_group_id = aws_security_group.infrastructure_config.id
  description              = "Allow outbound traffic to SG members"
}

# IAM Role for EC2 Instance Profile (Image Builder)
resource "aws_iam_role" "ec2_instance_profile" {
  name = "res-blue-green-EC2InstanceProfileForImageBuilder"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "res-blue-green-EC2InstanceProfileForImageBuilder"
  }
}

resource "aws_iam_role_policy_attachment" "s3_readonly_attach" {
  role       = aws_iam_role.ec2_instance_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}
resource "aws_iam_role_policy_attachment" "ssm_managed_instance_core_attach" {
  role       = aws_iam_role.ec2_instance_profile.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "ec2_instance_profile_for_imagebuilder_attach" {
  role       = aws_iam_role.ec2_instance_profile.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

# IAM Policy for RES Environment Access
resource "aws_iam_role_policy" "res_environment_policy" {
  name = "res-blue-green-RES-EnvironmentPolicy"
  role = aws_iam_role.ec2_instance_profile.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RESDynamoDBAccess"
        Effect = "Allow"
        Action = "dynamodb:GetItem"
        Resource = [
          "arn:${data.aws_partition.current.partition}:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.res_blue_environment}.cluster-settings",
          "arn:${data.aws_partition.current.partition}:dynamodb:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:table/${var.res_green_environment}.cluster-settings"
        ]
        Condition = {
          "ForAllValues:StringLike" = {
            "dynamodb:LeadingKeys" = [
              "global-settings.gpu_settings.*",
              "global-settings.package_config.*",
              "cluster-manager.host_modules.*",
              "identity-provider.cognito.enable_native_user_login"
            ]
          }
        }
      },
      {
        Sid    = "RESS3Access"
        Effect = "Allow"
        Action = "s3:GetObject"
        Resource = [
          "arn:${data.aws_partition.current.partition}:s3:::${var.res_blue_environment}-cluster-${data.aws_region.current.id}-${data.aws_caller_identity.current.account_id}/idea/vdc/res-ready-install-script-packages/*",
          "arn:${data.aws_partition.current.partition}:s3:::${var.res_green_environment}-cluster-${data.aws_region.current.id}-${data.aws_caller_identity.current.account_id}/idea/vdc/res-ready-install-script-packages/*",
          "arn:${data.aws_partition.current.partition}:s3:::research-engineering-studio-${data.aws_region.current.id}/host_modules/*"
        ]
      },
      {
        Sid    = "GPUDriverAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::dcv-license.us-east-1/*",
          "arn:aws:s3:::ec2-linux-nvidia-drivers/*",
          "arn:aws:s3:::ec2-linux-nvidia-drivers",
          "arn:aws:s3:::nvidia-gaming/*",
          "arn:aws:s3:::nvidia-gaming-drivers",
          "arn:aws:s3:::nvidia-gaming-drivers/*",
          "arn:aws:s3:::ec2-amd-linux-drivers/*",
          "arn:aws:s3:::ec2-amd-linux-drivers"
        ]
      }
    ]
  })
}

# EC2 Instance Profile
resource "aws_iam_instance_profile" "image_builder" {
  name = "res-blue-green-EC2InstanceProfileForImageBuilder"
  role = aws_iam_role.ec2_instance_profile.name
}

# Image Builder Infrastructure Configuration
resource "aws_imagebuilder_infrastructure_configuration" "res" {
  name                  = "res-blue-green-InfrastructureConfig"
  instance_profile_name = aws_iam_instance_profile.image_builder.name

  instance_types = [
    "m5.large",
    "m5.xlarge",
    "m5.2xlarge"
  ]

  security_group_ids = [
    aws_security_group.infrastructure_config.id
  ]

  subnet_id = var.image_builder_infrastructure_subnet

  tags = {
    Name = "res-blue-green-InfrastructureConfig"
  }
}

# Data sources for AWS account information
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}
