# modules/iam/variables.tf

variable "project_name" {
  description = "Name of the project to be used in resource naming"
  type        = string
}

variable "iam_role_path" {
  description = "Path for IAM roles and instance profile"
  type        = string
  default     = "/"
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

variable "additional_policy_arns" {
  description = "List of additional IAM policy ARNs to attach to the instance role"
  type        = list(string)
  default     = []
}

variable "custom_policy_documents" {
  description = "Map of custom policy documents to attach to the instance role. The key is the policy name and the value is the policy document in JSON format"
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for doc in values(var.custom_policy_documents) : can(jsondecode(doc))])
    error_message = "All custom policy documents must be valid JSON."
  }
}
