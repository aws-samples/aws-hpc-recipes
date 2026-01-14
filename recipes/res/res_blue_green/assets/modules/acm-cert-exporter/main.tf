# IAM Role for Lambda
resource "aws_iam_role" "cert_exporter" {
  name = "acm-cert-exporter"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "cert_exporter" {
  name = "acm-cert-exporter-policy"
  role = aws_iam_role.cert_exporter.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "acm:ExportCertificate",
          "acm:DescribeCertificate"
        ]
        Resource = var.acm_certificate_arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:UpdateSecret",
          "secretsmanager:PutSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.certificate.arn,
          aws_secretsmanager_secret.private_key.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.cert_passphrase.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },

    ]
  })
}

resource "null_resource" "lambda_layer_build" {
  provisioner "local-exec" {
    command = <<-EOT
      rm -rf ${path.module}/layer
      mkdir -p "${path.module}/layer/python"
      docker run --rm \
        --platform linux/amd64 \
        --entrypoint "" \
         -v "${abspath(path.module)}/lambda/requirements.txt:/tmp/requirements.txt:ro" \
         -v "${abspath(path.module)}/layer/python:/output" \
        public.ecr.aws/lambda/python:3.13 \
        pip install -r /tmp/requirements.txt -t /output
    EOT
  }

  triggers = {
    code         = filemd5("${path.module}/lambda/acm_cert_exporter.py")
    requirements = filemd5("${path.module}/lambda/requirements.txt")
  }
}

# Create layer zip
data "archive_file" "lambda_layer" {
  type        = "zip"
  source_dir  = "${path.module}/layer"
  output_path = "${path.module}/lambda_layer.zip"
  depends_on  = [null_resource.lambda_layer_build]
}

# Create Lambda layer
resource "aws_lambda_layer_version" "cert_exporter_layer" {
  filename            = data.archive_file.lambda_layer.output_path
  layer_name          = "cert-exporter-dependencies"
  compatible_runtimes = ["python3.13"]
  source_code_hash    = data.archive_file.lambda_layer.output_base64sha256
}


data "archive_file" "cert_exporter" {
  type        = "zip"
  source_file = "${path.module}/lambda/acm_cert_exporter.py"
  output_path = "${path.module}/acm-cert-exporter.zip"
}

resource "aws_lambda_function" "cert_exporter" {
  filename         = data.archive_file.cert_exporter.output_path
  function_name    = "RES-blue-green-acm-cert-exporter"
  role             = aws_iam_role.cert_exporter.arn
  handler          = "acm_cert_exporter.handler"
  source_code_hash = data.archive_file.cert_exporter.output_base64sha256
  runtime          = "python3.13"
  timeout          = 180

  # Attach the dependencies layer
  layers = [aws_lambda_layer_version.cert_exporter_layer.arn]

  environment {
    variables = {
      CERT_SECRET_ID       = aws_secretsmanager_secret.certificate.id
      KEY_SECRET_ID        = aws_secretsmanager_secret.private_key.id
      PASSPHRASE_SECRET_ID = aws_secretsmanager_secret.cert_passphrase.id
    }
  }
}

resource "aws_lambda_invocation" "initial_export" {
  function_name = aws_lambda_function.cert_exporter.function_name

  input = jsonencode({
    source      = ["aws.acm"]
    detail-type = "ACM Certificate Available"
    resources   = [var.acm_certificate_arn]
  })

  # This ensures it runs after certificate validation completes
  depends_on = [
    aws_lambda_function.cert_exporter
  ]
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cert_exporter.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.acm_cert_events.arn
}

resource "aws_cloudwatch_event_rule" "acm_cert_events" {
  name        = "res-blue-green-acm-certificate-events"
  description = "Capture ACM certificate issuance and renewal events"

  event_pattern = jsonencode({
    source      = ["aws.acm"]
    detail-type = ["ACM Certificate Available"]
    resources   = [var.acm_certificate_arn]
    detail = {
      Action = ["RENEWAL"]
    }
  })
}

resource "aws_cloudwatch_event_target" "cert_exporter" {
  rule      = aws_cloudwatch_event_rule.acm_cert_events.name
  target_id = "CertExporterLambda"
  arn       = aws_lambda_function.cert_exporter.arn
}
