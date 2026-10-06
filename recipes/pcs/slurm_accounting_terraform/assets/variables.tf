variable "cluster_arn" {
  description = "ARN of the AWS PCS cluster whose Slurm accounting database will be configured."
  type        = string

  validation {
    condition     = can(regex("^arn:[^:]+:pcs:[^:]+:[0-9]{12}:cluster/pcs_[A-Za-z0-9]+$", var.cluster_arn))
    error_message = "cluster_arn must be an AWS PCS cluster ARN."
  }
}

variable "accounts" {
  description = "Accounts to upsert, keyed by account name. Values are Slurm REST account fields other than name."
  type        = any
  default     = {}
}

variable "qos" {
  description = "QOS records to upsert, keyed by QOS name. Values are Slurm REST QOS fields other than name."
  type        = any
  default     = {}
}

variable "users" {
  description = "Users to upsert, keyed by user name. Values are Slurm REST user fields other than name."
  type        = any
  default     = {}
}

variable "associations" {
  description = "Slurm REST association objects to upsert. The PCS cluster name is added when cluster is omitted."
  type        = any
  default     = []
}

variable "sacctmgr_load" {
  description = "Optional contents of a sacctmgr dump file. Mutually exclusive with accounts, qos, users, and associations."
  type        = string
  default     = null
}

variable "lambda_subnet_ids" {
  description = "Subnets for the Lambda. Null uses the PCS cluster endpoint subnets."
  type        = list(string)
  default     = null

  validation {
    condition     = var.lambda_subnet_ids == null || length(var.lambda_subnet_ids) > 0
    error_message = "lambda_subnet_ids must be null or contain at least one subnet ID."
  }
}

variable "lambda_security_group_ids" {
  description = "Security groups for the Lambda. Null uses the PCS cluster endpoint security groups."
  type        = list(string)
  default     = null

  validation {
    condition     = var.lambda_security_group_ids == null || length(var.lambda_security_group_ids) > 0
    error_message = "lambda_security_group_ids must be null or contain at least one security group ID."
  }
}

variable "function_name" {
  description = "Optional Lambda function name. Null derives a name from the PCS cluster ID."
  type        = string
  default     = null

  validation {
    condition = (
      var.function_name == null ||
      can(regex("^[A-Za-z0-9_-]{1,64}$", var.function_name))
    )
    error_message = "function_name must contain 1-64 letters, numbers, hyphens, or underscores."
  }
}

variable "slurm_rest_api_version" {
  description = "Preferred Slurm REST API version, or auto to discover a compatible version."
  type        = string
  default     = "auto"

  validation {
    condition = (
      var.slurm_rest_api_version == "auto" ||
      can(regex("^v0\\.0\\.[0-9]+$", var.slurm_rest_api_version))
    )
    error_message = "slurm_rest_api_version must be auto or have the form v0.0.N."
  }
}

variable "jwt_ttl_seconds" {
  description = "Lifetime of each generated Slurm root JWT."
  type        = number
  default     = 300

  validation {
    condition     = var.jwt_ttl_seconds >= 60 && var.jwt_ttl_seconds <= 900
    error_message = "jwt_ttl_seconds must be between 60 and 900 seconds."
  }
}

variable "request_timeout_seconds" {
  description = "Timeout for each HTTP request to slurmrestd."
  type        = number
  default     = 15

  validation {
    condition     = var.request_timeout_seconds >= 1 && var.request_timeout_seconds <= 60
    error_message = "request_timeout_seconds must be between 1 and 60 seconds."
  }
}

variable "request_retries" {
  description = "Retries for transient slurmrestd HTTP and network failures."
  type        = number
  default     = 3

  validation {
    condition     = var.request_retries >= 0 && var.request_retries <= 10 && floor(var.request_retries) == var.request_retries
    error_message = "request_retries must be an integer between 0 and 10."
  }
}

variable "lambda_timeout_seconds" {
  description = "Lambda invocation timeout."
  type        = number
  default     = 120

  validation {
    condition     = var.lambda_timeout_seconds >= 30 && var.lambda_timeout_seconds <= 900
    error_message = "lambda_timeout_seconds must be between 30 and 900 seconds."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the Lambda log group."
  type        = number
  default     = 14
}

variable "force_run_token" {
  description = "Changing this value forces the upsert Lambda to run again, even if no other inputs changed."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to supported resources."
  type        = map(string)
  default     = {}
}
