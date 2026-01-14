terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.4"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = merge(
      {
        managed-by = "terraform"
        project    = "res-blue-green"
      },
      var.additional_tags
    )
  }
}
