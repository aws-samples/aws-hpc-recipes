terraform {
  # No Terraform actions or other recent language features are used, so any
  # 1.5+ release should work.
  required_version = ">= 1.5.0"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4.0"
    }
    # aws_lambda_function with runtime python3.13 and logging_config.
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.80.0"
    }
    # awscc_pcs_cluster must expose slurm_configuration.slurm_rest and
    # slurm_configuration.jwt_auth.
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.98.0"
    }
  }
}
