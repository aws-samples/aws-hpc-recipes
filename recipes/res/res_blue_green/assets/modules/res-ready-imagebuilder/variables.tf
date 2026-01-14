variable "vpc_id" {
  description = "VPC where RES is deployed"
  type        = string
}

variable "res_blue_environment" {
  description = "Name of the RES Blue environment"
  type        = string
  default     = "res-blue"
}

variable "res_green_environment" {
  description = "Name of the RES Green environment"
  type        = string
  default     = "res-green"
}

variable "image_builder_infrastructure_subnet" {
  description = "Subnet for EC2 Image Builder Infrastructure"
  type        = string
}
