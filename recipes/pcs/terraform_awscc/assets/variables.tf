variable "project_name" {
  description = "Name of the project to be used in resource naming"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.project_name))
    error_message = "Project name must start with a letter and can only contain letters, numbers, and hyphens."
  }
}

variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-2"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zone" {
  description = "Availability zone for subnet placement"
  type        = string
  default     = "us-east-2a"

  validation {
    condition     = can(regex("${var.aws_region}[a-z]$", var.availability_zone))
    error_message = "Availability zone must be within the specified AWS region."
  }
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

variable "pcs_cluster_name" {
  description = "Name of the AWS Parallel Computing Service cluster"
  type        = string
  default     = "cluster"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.pcs_cluster_name))
    error_message = "Cluster name must start with a letter and can only contain letters, numbers, and hyphens."
  }
}

variable "pcs_cluster_size" {
  description = "Size of the AWS Parallel Computing Service cluster"
  type        = string
  default     = "SMALL"
}

variable "pcs_cluster_slurm_version" {
  description = "Version of Slurm to use in the cluster"
  type        = string
  default     = "24.11"
}

variable "pcs_cng_ami_id" {
  description = "value of the AMI ID to use for the cluster"
  type        = string
}

variable "pcs_cluster_scaledown_idletime" {
  description = "Delay in seconds before an idle dynamic node is terminated"
  type        = number
  default     = 300
}

variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
  default = {
    HPCRecipes = "true"
  }
}
