# # outputs.tf

output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.vpc.vpc_id
}

output "efs_id" {
  description = "ID of the EFS filesystem"
  value       = module.efs.id
}

output "efs_dns_name" {
  description = "DNS name of the EFS filesystem"
  value       = module.efs.dns_name
}

output "fsx_id" {
  description = "ID of the FSx Lustre filesystem"
  value       = module.fsx_lustre.file_system_id
}

output "fsx_mount_name" {
  description = "Mount name of the FSx Lustre filesystem"
  value       = module.fsx_lustre.file_system_mount_name
}

output "fsx_dns_name" {
  description = "DNS name of the FSx Lustre filesystem"
  value       = module.fsx_lustre.file_system_dns_name
}

output "iam_instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = module.iam.instance_profile_arn
}

output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = module.compute.cluster_security_group_id
}

output "ssh_security_group_id" {
  description = "ID of the SSH security group"
  value       = module.compute.ssh_security_group_id
}

output "pcs_cluster_id" {
  description = "ID of the Parallel Computing Service cluster"
  value       = module.compute.pcs_cluster_id
}

output "pcs_cluster_console_url" {
  description = "URL for the Parallel Computing Service console"
  value       = module.compute.pcs_cluster_console_url
}

output "pcs_ec2_console_url" {
  description = "URL for the EC2 console filtered to PCS login node instances"
  value       = module.compute.pcs_ec2_console_url
}
