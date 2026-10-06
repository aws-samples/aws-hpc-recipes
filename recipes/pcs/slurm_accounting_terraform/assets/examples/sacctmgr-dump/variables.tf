variable "region" {
  description = "AWS Region for the cluster and all supporting resources."
  type        = string
}

variable "vpc_id" {
  description = "Existing VPC that holds subnet_id."
  type        = string
}

variable "subnet_id" {
  description = "Existing subnet for the PCS cluster endpoints and the bootstrap Lambda. It must route to the PCS and Secrets Manager APIs (NAT gateway or interface endpoints)."
  type        = string
}

variable "name" {
  description = "Name for the cluster and a prefix for the supporting resources."
  type        = string
  default     = "pcs-accounting-dump-example"
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

variable "dump_file" {
  description = "Path, relative to this directory, of the sacctmgr dump file to load."
  type        = string
  default     = "accounting.dump"
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
