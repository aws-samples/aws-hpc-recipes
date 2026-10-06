output "cluster" {
  description = "The PCS cluster."
  value = {
    arn    = awscc_pcs_cluster.this.arn
    id     = awscc_pcs_cluster.this.cluster_id
    name   = awscc_pcs_cluster.this.name
    status = awscc_pcs_cluster.this.status
  }
}

output "bootstrap_result" {
  description = "Summary returned by the bootstrap Lambda."
  value       = module.slurm_accounting.bootstrap_result
}

output "bootstrap_lambda" {
  description = "Name of the bootstrap Lambda; its log group is /aws/lambda/<name>."
  value       = module.slurm_accounting.lambda_function_name
}

output "queue" {
  description = "The queue whose DenyQos references the module-created QOS."
  value = {
    id     = awscc_pcs_queue.batch.queue_id
    name   = awscc_pcs_queue.batch.name
    status = awscc_pcs_queue.batch.status
  }
}
