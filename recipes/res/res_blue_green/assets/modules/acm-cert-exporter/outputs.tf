# Lambda Function Outputs
output "lambda_function_arn" {
  description = "ARN of the ACM certificate exporter Lambda function"
  value       = aws_lambda_function.cert_exporter.arn
}

output "lambda_function_name" {
  description = "Name of the ACM certificate exporter Lambda function"
  value       = aws_lambda_function.cert_exporter.function_name
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the ACM certificate exporter Lambda function"
  value       = aws_lambda_function.cert_exporter.invoke_arn
}

output "lambda_function_version" {
  description = "Latest published version of the Lambda function"
  value       = aws_lambda_function.cert_exporter.version
}

# IAM Role Outputs
output "lambda_role_arn" {
  description = "ARN of the IAM role used by the Lambda function"
  value       = aws_iam_role.cert_exporter.arn
}

output "lambda_role_name" {
  description = "Name of the IAM role used by the Lambda function"
  value       = aws_iam_role.cert_exporter.name
}

output "lambda_role_id" {
  description = "ID of the IAM role used by the Lambda function"
  value       = aws_iam_role.cert_exporter.id
}

# Secrets Manager Outputs
output "certificate_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the certificate and chain"
  value       = aws_secretsmanager_secret.certificate.arn
}

output "certificate_secret_id" {
  description = "ID of the Secrets Manager secret containing the certificate and chain"
  value       = aws_secretsmanager_secret.certificate.id
}

output "certificate_secret_name" {
  description = "Name of the Secrets Manager secret containing the certificate and chain"
  value       = aws_secretsmanager_secret.certificate.name
}

output "private_key_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the private key"
  value       = aws_secretsmanager_secret.private_key.arn
}

output "private_key_secret_id" {
  description = "ID of the Secrets Manager secret containing the private key"
  value       = aws_secretsmanager_secret.private_key.id
}

output "private_key_secret_name" {
  description = "Name of the Secrets Manager secret containing the private key"
  value       = aws_secretsmanager_secret.private_key.name
}

# Passphrase Secret Outputs
output "passphrase_secret_arn" {
  description = "ARN of the Secrets Manager secret storing the certificate export passphrase"
  value       = aws_secretsmanager_secret.cert_passphrase.arn
}

output "passphrase_secret_id" {
  description = "ID of the Secrets Manager secret storing the certificate export passphrase"
  value       = aws_secretsmanager_secret.cert_passphrase.id
}

output "passphrase_secret_name" {
  description = "Name of the Secrets Manager secret storing the certificate export passphrase"
  value       = aws_secretsmanager_secret.cert_passphrase.name
}

# EventBridge Outputs
output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule for ACM certificate events"
  value       = aws_cloudwatch_event_rule.acm_cert_events.arn
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule for ACM certificate events"
  value       = aws_cloudwatch_event_rule.acm_cert_events.name
}

# Convenience Outputs
output "secrets" {
  description = "Map of all secrets created by this module"
  value = {
    certificate = {
      arn  = aws_secretsmanager_secret.certificate.arn
      id   = aws_secretsmanager_secret.certificate.id
      name = aws_secretsmanager_secret.certificate.name
    }
    private_key = {
      arn  = aws_secretsmanager_secret.private_key.arn
      id   = aws_secretsmanager_secret.private_key.id
      name = aws_secretsmanager_secret.private_key.name
    }
    passphrase = {
      arn  = aws_secretsmanager_secret.cert_passphrase.arn
      id   = aws_secretsmanager_secret.cert_passphrase.id
      name = aws_secretsmanager_secret.cert_passphrase.name
    }
  }
}
