variable "region" {
  description = "AWS Region for the cluster and all supporting resources."
  type        = string
}

variable "vpc_id" {
  description = "Existing VPC that holds subnet_id."
  type        = string
}

variable "subnet_id" {
  description = "Existing subnet for the PCS cluster endpoints, the bootstrap Lambda, and the compute nodes. It must route to the PCS and Secrets Manager APIs (NAT gateway or interface endpoints)."
  type        = string
}

variable "name" {
  description = "Name for the cluster and a prefix for the supporting resources."
  type        = string
  default     = "pcs-accounting-example"
}

variable "scheduler_version" {
  description = "AWS PCS Slurm version: 25.11 or 26.05."
  type        = string
  default     = "26.05"

  validation {
    condition     = contains(["25.11", "26.05"], var.scheduler_version)
    error_message = "scheduler_version must be 25.11 or 26.05."
  }
}

variable "compute_instance_type" {
  description = "Instance type for the compute node group. Must match the x86_64 sample AMI."
  type        = string
  default     = "c6i.xlarge"
}

variable "compute_max_instances" {
  description = "Maximum instance count for the compute node group. Minimum is 0, so nothing runs until a job is submitted."
  type        = number
  default     = 2
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
