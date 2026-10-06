data "awscc_pcs_cluster" "target" {
  id = var.cluster_arn
}

locals {
  cluster_id = data.awscc_pcs_cluster.target.cluster_id

  jwt_secret_arn = data.awscc_pcs_cluster.target.slurm_configuration.jwt_auth.jwt_key.secret_arn
  cluster_subnet_ids = tolist(
    data.awscc_pcs_cluster.target.networking.subnet_ids
  )
  cluster_security_group_ids = tolist(
    data.awscc_pcs_cluster.target.networking.security_group_ids
  )

  lambda_subnet_ids = (
    var.lambda_subnet_ids == null
    ? local.cluster_subnet_ids
    : var.lambda_subnet_ids
  )
  lambda_security_group_ids = (
    var.lambda_security_group_ids == null
    ? local.cluster_security_group_ids
    : var.lambda_security_group_ids
  )

  function_name = coalesce(
    var.function_name,
    "pcs-slurm-bootstrap-${local.cluster_id}",
  )
  iam_name = "${substr(local.function_name, 0, 46)}-${substr(sha256(var.cluster_arn), 0, 8)}"

  bootstrap_configuration = {
    accounts      = var.accounts
    qos           = var.qos
    users         = var.users
    associations  = var.associations
    sacctmgr_load = var.sacctmgr_load
  }
  bootstrap_payload = jsonencode(local.bootstrap_configuration)
  configuration_sha = sha256(local.bootstrap_payload)
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.root}/.terraform/pcs-slurm-bootstrap-${substr(sha256(var.cluster_arn), 0, 16)}.zip"
  excludes    = ["__pycache__/*"]
}

# Resolves to the correct service principal for the current partition
# (for example lambda.amazonaws.com.cn in the China Regions).
data "aws_service_principal" "lambda" {
  service_name = "lambda"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [data.aws_service_principal.lambda.name]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${local.iam_name}-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "lambda" {
  statement {
    sid = "WriteFunctionLogs"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.lambda.arn}:*"]
  }

  statement {
    sid = "ManageVpcNetworkInterfaces"
    actions = [
      "ec2:AssignPrivateIpAddresses",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSubnets",
      "ec2:UnassignPrivateIpAddresses",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ReadClusterConfiguration"
    actions   = ["pcs:GetCluster"]
    resources = [var.cluster_arn]
  }

  statement {
    sid       = "ReadJwtSigningKey"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [local.jwt_secret_arn]
  }
}

resource "aws_iam_role_policy" "lambda" {
  name   = "${local.iam_name}-access"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_lambda_function" "bootstrap" {
  function_name = local.function_name
  description   = "Upserts AWS PCS Slurm accounts, QOS records, users, and associations"
  role          = aws_iam_role.lambda.arn

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = "handler.lambda_handler"
  runtime          = "python3.13"
  architectures    = ["arm64"]
  memory_size      = 256
  timeout          = var.lambda_timeout_seconds

  environment {
    variables = {
      PCS_CLUSTER_IDENTIFIER  = local.cluster_id
      SLURM_REST_API_VERSION  = var.slurm_rest_api_version
      JWT_TTL_SECONDS         = tostring(var.jwt_ttl_seconds)
      REQUEST_TIMEOUT_SECONDS = tostring(var.request_timeout_seconds)
      REQUEST_RETRIES         = tostring(var.request_retries)
    }
  }

  logging_config {
    log_format            = "JSON"
    application_log_level = "INFO"
    system_log_level      = "WARN"
  }

  vpc_config {
    subnet_ids         = local.lambda_subnet_ids
    security_group_ids = local.lambda_security_group_ids
  }

  tags = var.tags

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.lambda,
  ]

  lifecycle {
    precondition {
      condition     = data.awscc_pcs_cluster.target.status == "ACTIVE"
      error_message = "The PCS cluster must be ACTIVE before Slurm accounting is bootstrapped."
    }

    precondition {
      condition     = try(data.awscc_pcs_cluster.target.slurm_configuration.accounting.mode, "NONE") == "STANDARD"
      error_message = "The PCS cluster must have Slurm accounting enabled in STANDARD mode."
    }

    precondition {
      condition     = try(data.awscc_pcs_cluster.target.slurm_configuration.slurm_rest.mode, "NONE") == "STANDARD"
      error_message = "The PCS cluster must have the Slurm REST API enabled in STANDARD mode."
    }

    precondition {
      condition     = try(local.jwt_secret_arn, "") != ""
      error_message = "The PCS cluster does not expose a JWT signing key."
    }

    precondition {
      condition = length([
        for endpoint in data.awscc_pcs_cluster.target.endpoints : endpoint
        if endpoint.type == "SLURMRESTD"
      ]) == 1
      error_message = "The PCS cluster must expose exactly one SLURMRESTD endpoint."
    }
  }
}

# Synchronous invocation. The resource is created only when the Lambda returns
# successfully; a function error or timeout fails the apply and leaves nothing
# in state, so the next `terraform apply` invokes it again. A change to any
# trigger value (or to the input payload) replaces the resource, which runs the
# bootstrap again. Destroying it is a no-op: Slurm records are left in place.
resource "aws_lambda_invocation" "bootstrap" {
  function_name = aws_lambda_function.bootstrap.function_name
  input         = local.bootstrap_payload

  triggers = {
    cluster_arn               = var.cluster_arn
    configuration_sha         = local.configuration_sha
    force_run_token           = var.force_run_token
    jwt_ttl_seconds           = tostring(var.jwt_ttl_seconds)
    lambda_code_sha           = data.archive_file.lambda.output_base64sha256
    lambda_security_group_ids = join(",", local.lambda_security_group_ids)
    lambda_subnet_ids         = join(",", local.lambda_subnet_ids)
    request_retries           = tostring(var.request_retries)
    request_timeout_seconds   = tostring(var.request_timeout_seconds)
    slurm_rest_api_version    = var.slurm_rest_api_version
  }

  depends_on = [
    aws_lambda_function.bootstrap,
    aws_iam_role_policy.lambda,
  ]
}
