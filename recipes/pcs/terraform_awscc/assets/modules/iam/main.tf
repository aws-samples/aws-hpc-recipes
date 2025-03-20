// Instance Role
resource "aws_iam_role" "instance_role" {
  name = "AWSPCS-${var.project_name}-instance-role"
  path = var.iam_role_path

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-instance-role"
  })
}

// PCS Compute Node Registration Policy
resource "aws_iam_role_policy" "compute_node_registration" {
  name   = "PCSComputeNodeRegistration"
  role   = aws_iam_role.instance_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "pcs:RegisterComputeNodeGroupInstance"
        ]
        Resource = "*"
        Effect = "Allow"
      }
    ]
  })
}

// AWS Managed Policy Attachments
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "s3_readonly" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

// Optional policy attachments based on variables
resource "aws_iam_role_policy_attachment" "additional_policies" {
  count = length(var.additional_policy_arns)

  role       = aws_iam_role.instance_role.name
  policy_arn = var.additional_policy_arns[count.index]
}

// Custom policies based on provided JSON
resource "aws_iam_role_policy" "custom_policies" {
  for_each = var.custom_policy_documents

  name   = each.key
  role   = aws_iam_role.instance_role.name
  policy = each.value
}

// Instance Profile
resource "aws_iam_instance_profile" "main" {
  name = "AWSPCS-${var.project_name}-instance-profile"
  path = var.iam_role_path
  role = aws_iam_role.instance_role.name

  tags = merge(var.tags, {
    Name = "${var.project_name}-instance-profile"
  })
}