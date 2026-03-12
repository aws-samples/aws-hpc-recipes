# Security Practices

## Credentials
- Never commit AWS credentials or secrets to the repository
- Use AWS Secrets Manager or Systems Manager Parameter Store for sensitive data
- Run `gitleaks` locally before pushing (included in CI)

## IAM
- Follow the principle of least privilege for all IAM roles and policies
- Avoid `*` resource ARNs where possible — scope to specific resources
- Prefer AWS managed policies over inline policies when appropriate
- Use conditions to restrict access (e.g., `aws:SourceAccount`, `aws:SourceArn`)

## Networking
- Validate that security groups have appropriate ingress/egress restrictions
- Avoid `0.0.0.0/0` ingress rules unless explicitly required and documented
- Use VPC endpoints where possible to avoid public internet traffic

## Scanning Tools
- `gitleaks` — secret detection
- `cfn_nag` — CloudFormation security analysis
- `bandit` — Python security linting
- `shellcheck` — shell script analysis
- `hadolint` — Dockerfile linting
