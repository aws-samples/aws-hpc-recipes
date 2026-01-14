variable "region" {
  description = "AWS Deployment region.."
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Your RES Domain Name..."
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "The VPC id for RES-Ready AMI infrastructure"
  type        = string
}

variable "image_builder_infrastructure_subnet" {
  description = "The subnet ID for RES-Ready AMI infrastructure"
  type        = string
}
