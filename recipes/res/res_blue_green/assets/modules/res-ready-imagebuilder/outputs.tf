# EC2 Instance Profile outputs
output "ec2_instance_profile_arn" {
  description = "ARN of the RES EC2 Instance Profile for Image Builder"
  value       = aws_iam_instance_profile.image_builder.arn
}

output "ec2_instance_profile_name" {
  description = "Name of the RES EC2 Instance Profile for Image Builder"
  value       = aws_iam_instance_profile.image_builder.name
}

output "ec2_instance_profile_role_arn" {
  description = "ARN of the IAM role used by the EC2 Instance Profile"
  value       = aws_iam_role.ec2_instance_profile.arn
}

# Image Builder Infrastructure Configuration outputs
output "infrastructure_config_arn" {
  description = "ARN of the RES Image Builder Infrastructure Configuration"
  value       = aws_imagebuilder_infrastructure_configuration.res.arn
}

output "infrastructure_config_name" {
  description = "Name of the RES Image Builder Infrastructure Configuration"
  value       = aws_imagebuilder_infrastructure_configuration.res.name
}

# Security Group outputs
output "infrastructure_security_group_id" {
  description = "ID of the security group used by Image Builder infrastructure"
  value       = aws_security_group.infrastructure_config.id
}

output "infrastructure_security_group_arn" {
  description = "ARN of the security group used by Image Builder infrastructure"
  value       = aws_security_group.infrastructure_config.arn
}
