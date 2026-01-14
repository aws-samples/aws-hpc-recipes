resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Secrets Manager - Export Passphrase
resource "aws_secretsmanager_secret" "cert_passphrase" {
  name_prefix = "PrivateKeyExportPassword-res-blue-green-"
  description = "Passphrase for ACM certificate export"

  tags = {
    Name = "acm-export-passphrase"
  }
}

resource "aws_secretsmanager_secret_version" "cert_passphrase" {
  secret_id     = aws_secretsmanager_secret.cert_passphrase.id
  secret_string = random_password.password.result
}

# Secrets Manager - Full Certificate Chain (cert + chain)
resource "aws_secretsmanager_secret" "certificate" {
  name_prefix = "Certificate-res-blue-green-"
  description = "Full certificate chain for ${var.domain_name}"

  tags = {
    name                  = "acm-certificate-chain"
    "res:EnvironmentName" = "res-blue"
    "res:ModuleName"      = "virtual-desktop-controller"
  }
}

# Secrets Manager - Decrypted Private Key
resource "aws_secretsmanager_secret" "private_key" {
  name_prefix = "PrivateKey-res-blue-green-"
  description = "Decrypted private key for ${var.domain_name}"

  tags = {
    name                  = "acm-private-key"
    "res:EnvironmentName" = "res-blue"
    "res:ModuleName"      = "virtual-desktop-controller"
  }
}
