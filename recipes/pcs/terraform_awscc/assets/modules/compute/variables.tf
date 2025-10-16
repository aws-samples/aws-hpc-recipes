variable "project_name" {
  description = "Name of the project to be used in resource naming"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where compute resources will be created"
  type        = string
}

variable "management_subnet_id" {
  description = "ID of the management subnet"
  type        = string
}

variable "compute_subnet_id" {
  description = "ID of the compute subnet"
  type        = string
}

variable "access_subnet_id" {
  description = "ID of the access subnet"
  type        = string
}

variable "ssh_key_name" {
  description = "Name of the SSH key pair to use for instances"
  type        = string
}

variable "ssh_cidr_block" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "instance_profile_arn" {
  description = "ARN of the instance profile to attach to instances"
  type        = string
}

variable "efs_filesystem_id" {
  description = "ID of the EFS filesystem"
  type        = string
}

variable "fsx_filesystem_id" {
  description = "ID of the FSx filesystem"
  type        = string
}

variable "fsx_dns_name" {
  description = "DNS name of the FSx filesystem"
  type        = string
}

variable "fsx_mount_name" {
  description = "Mount name of the FSx filesystem"
  type        = string
}

variable "aws_region" {
  description = "AWS region where resources are created"
  type        = string
}

variable "pcs_cluster_name" {
  description = "Name of the ParallelCluster Serverless cluster"
  type        = string
}

variable "pcs_cluster_size" {
  description = "Size of the ParallelCluster Serverless cluster"
  type        = string
  default     = "SMALL"
}

variable "pcs_cluster_slurm_version" {
  description = "Version of Slurm to use in the cluster"
  type        = string
  default     = "25.05"
}

variable "pcs_cluster_scaledown_idletime" {
  description = "Delay in seconds before an idle dynamic node is terminated"
  type        = number
  default     = 300
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

variable "cluster_security_group_rules" {
  description = "Rules for the cluster security group"
  type = list(object({
    type                     = string
    from_port                = number
    to_port                  = number
    protocol                 = string
    cidr_blocks              = list(string)
    source_security_group_id = string
    description              = string
  }))
  default = []
}

variable "pcs_cng_login_instance_type" {
  description = "Instance type or login node(s)"
  type        = string
  default     = "c6a.xlarge"
}

variable "pcs_cng_compute_instance_type" {
  description = "Instance type or login node(s)"
  type        = string
  default     = "c6a.2xlarge"
}

variable "pcs_cng_ami_id" {
  description = "Value of the AMI ID to use for the cluster"
  type        = string
}
