# modules/iam/outputs.tf

output "instance_role_name" {
  description = "Name of the IAM instance role"
  value       = aws_iam_role.instance_role.name
}

output "instance_role_arn" {
  description = "ARN of the IAM instance role"
  value       = aws_iam_role.instance_role.arn
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = aws_iam_instance_profile.main.name
}

output "instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = aws_iam_instance_profile.main.arn
}

output "instance_profile_id" {
  description = "ID of the IAM instance profile"
  value       = aws_iam_instance_profile.main.id
}
