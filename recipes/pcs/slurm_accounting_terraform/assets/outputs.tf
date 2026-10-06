output "completion_id" {
  description = "Opaque hex identifier that changes whenever the bootstrap Lambda runs again. Safe to embed in scripts and templates. Downstream resources can also depend on the module directly."
  value       = sha256("${aws_lambda_invocation.bootstrap.id}|${jsonencode(aws_lambda_invocation.bootstrap.triggers)}")
}

output "bootstrap_result" {
  description = "Summary returned by the bootstrap Lambda: status, cluster, negotiated Slurm REST API version, and upserted record counts."
  value       = jsondecode(aws_lambda_invocation.bootstrap.result)
}

output "configuration_sha256" {
  description = "SHA-256 of the desired upsert configuration."
  value       = local.configuration_sha
}

output "lambda_function_name" {
  description = "Name of the deployed bootstrap Lambda."
  value       = aws_lambda_function.bootstrap.function_name
}

output "lambda_function_arn" {
  description = "ARN of the deployed bootstrap Lambda."
  value       = aws_lambda_function.bootstrap.arn
}

output "lambda_networking" {
  description = "Effective Lambda VPC networking after applying defaults and overrides."
  value = {
    subnet_ids         = local.lambda_subnet_ids
    security_group_ids = local.lambda_security_group_ids
  }
}

output "pcs_cluster" {
  description = "The PCS cluster selected by cluster_arn."
  value = {
    arn  = var.cluster_arn
    id   = local.cluster_id
    name = data.awscc_pcs_cluster.target.name
  }
}
