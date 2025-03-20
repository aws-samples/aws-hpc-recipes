output "cluster_security_group_id" {
  description = "ID of the cluster security group"
  value       = module.cluster_security_group.security_group_id
}

output "ssh_security_group_id" {
  description = "ID of the SSH security group"
  value       = module.ssh_security_group.security_group_id
}

output "login_launch_template_id" {
  description = "ID of the login node launch template"
  value       = aws_launch_template.login.id
}

output "login_launch_template_latest_version" {
  description = "Latest version of the login node launch template"
  value       = aws_launch_template.login.latest_version
}

output "compute_launch_template_id" {
  description = "ID of the compute node launch template"
  value       = aws_launch_template.compute.id
}

output "compute_launch_template_latest_version" {
  description = "Latest version of the compute node launch template"
  value       = aws_launch_template.compute.latest_version
}

output "pcs_cluster_id" {
  description = "ID of the AWS Parallel Computing Service cluster"
  value       = awscc_pcs_cluster.main.cluster_id
}

output "pcs_cluster_status" {
  description = "Status of the AWS Parallel Computing Service cluster"
  value       = awscc_pcs_cluster.main.status
}

output "pcs_cluster_console_url" {
  description = "URL for the AWS Parallel Computing Service console"
  value       = "https://console.aws.amazon.com/pcs/home?region=${var.aws_region}#/clusters/${awscc_pcs_cluster.main.cluster_id}"
}

output "pcs_ec2_console_url" {
  description = "URL for the EC2 console filtered to PCS login node instances"
  value       = "https://console.aws.amazon.com/ec2/home?region=${var.aws_region}#Instances:instanceState=running;tag:aws:pcs:compute-node-group-id=${awscc_pcs_compute_node_group.login.compute_node_group_id}"
}
