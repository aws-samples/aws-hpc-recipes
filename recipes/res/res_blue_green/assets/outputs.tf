####################################
# ACM DNS Validation Module Outputs
####################################
output "ACMCertificateARNforWebApp" {
  description = "ARN of the ACM certificate"
  value       = module.acm-certificate.certificate_arn
}

####################################
# ACM Certificate Exporter Module Outputs
####################################
## Lambda Function
output "lambda_function_arn" {
  description = "ARN of the ACM certificate exporter Lambda function"
  value       = module.acm-cert-exporter.lambda_function_arn
}

## Secrets Manager
output "CertificateSecretARNforVDI" {
  description = "ARN of the Secrets Manager secret containing the certificate and chain"
  value       = module.acm-cert-exporter.certificate_secret_arn
}

output "PrivateKeySecretARNforVDI" {
  description = "ARN of the Secrets Manager secret containing the private key"
  value       = module.acm-cert-exporter.private_key_secret_arn
}


## Convenience Outputs
output "secrets_map" {
  description = "Map of all secrets created by the cert exporter module"
  value       = module.acm-cert-exporter.secrets
}

####################################
# Blue/Green RES-Ready ImageBuilder
####################################
output "infrastructure_config_arn" {
  description = "ARN of the RES Image Builder Infrastructure Configuration"
  value       = module.res-ready-imagebuilder.infrastructure_config_arn
}
