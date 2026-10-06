# Complete example: PCS cluster, Slurm accounting bootstrap, compute node
# group, and a queue whose DenyQos setting references a QOS the module creates.
#
# Everything is created in an existing VPC subnet. The subnet must give the
# Lambda a path to the PCS and Secrets Manager APIs (NAT gateway or interface
# VPC endpoints); see the module README, "Networking".

locals {
  tags = merge(var.tags, {
    Project = var.name
  })
}

# One self-referencing security group shared by the PCS cluster endpoints, the
# bootstrap Lambda, and the compute nodes. Self-ingress on all ports covers
# slurmrestd (6820) and Slurm's own node-to-controller traffic.
resource "aws_security_group" "pcs" {
  name        = var.name
  description = "AWS PCS cluster endpoints, bootstrap Lambda, and compute nodes"
  vpc_id      = var.vpc_id

  ingress {
    description = "Members of this security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "Outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = var.name })
}

resource "awscc_pcs_cluster" "this" {
  name = var.name
  size = "SMALL"

  scheduler = {
    type    = "SLURM"
    version = var.scheduler_version
  }

  networking = {
    subnet_ids         = [var.subnet_id]
    security_group_ids = [aws_security_group.pcs.id]
  }

  # Both are required by the bootstrap module.
  slurm_configuration = {
    accounting = {
      mode = "STANDARD"
    }
    slurm_rest = {
      mode = "STANDARD"
    }
  }

  tags = local.tags
}

module "slurm_accounting" {
  source = "../.."

  cluster_arn = awscc_pcs_cluster.this.arn

  qos = {
    normal = {
      description = "Normal work"
      priority    = 100

      limits = {
        max = {
          active_jobs = {
            count = 100 # GrpJobs
          }
          jobs = {
            active_jobs = {
              per = {
                user = 10 # MaxJobsPerUser
              }
            }
          }
          tres = {
            per = {
              job = [
                { type = "cpu", count = 64 }, # MaxTRESPerJob=cpu=64
              ]
            }
          }
        }
      }
    }

    # Referenced by the queue's DenyQos setting below. Jobs submitted with
    # --qos=preempt are rejected by that queue.
    preempt = {
      description = "Denied from the batch queue"
    }
  }

  accounts = {
    research = {
      description  = "Research workloads"
      organization = "Example"
      coordinators = ["alice"]
    }
    simulation = {
      description  = "Simulation group, child of research"
      organization = "Example"
    }
  }

  users = {
    alice = {
      administrator_level = ["None"]
      default = {
        account = "research"
      }
    }
    bob = {
      administrator_level = ["None"]
      default = {
        account = "simulation"
      }
    }
  }

  associations = [
    # Account associations. parent_account defaults to root.
    {
      account    = "research"
      default    = { qos = "normal" }
      qos        = ["normal"]
      shares_raw = 100
    },
    {
      account        = "simulation"
      parent_account = "research"
      shares_raw     = 40
    },

    # User associations.
    {
      account    = "research"
      user       = "alice"
      default    = { qos = "normal" }
      qos        = ["normal"]
      shares_raw = 10
    },
    {
      account    = "simulation"
      user       = "bob"
      default    = { qos = "normal" }
      qos        = ["normal"]
      shares_raw = 10
      max = {
        jobs = {
          active = 5 # MaxJobs
        }
      }
    },
  ]

  tags = local.tags
}

# --- Compute node group -----------------------------------------------------

# Starting with Slurm 26.05, a single PCS sample AMI (no Slurm version in its
# name) supports every Slurm version that is not EOL. The regex excludes the
# older per-version images (...-slurm-25.11-...) that the name filter also
# matches.
data "aws_ami" "pcs" {
  most_recent = true
  owners      = ["amazon"]
  name_regex  = "^aws-pcs-sample_ami-al2023-x86_64-[0-9]{4}-"

  filter {
    name   = "name"
    values = ["aws-pcs-sample_ami-al2023-x86_64-*"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

data "aws_service_principal" "ec2" {
  service_name = "ec2"
}

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = [data.aws_service_principal.ec2.name]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-node"
  path               = "/aws-pcs/"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
  tags               = local.tags
}

data "aws_iam_policy_document" "node_registration" {
  statement {
    sid       = "RegisterComputeNodeGroupInstance"
    effect    = "Allow"
    actions   = ["pcs:RegisterComputeNodeGroupInstance"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "node_registration" {
  name   = "PCSRegisterComputeNodeGroupInstance"
  role   = aws_iam_role.node.id
  policy = data.aws_iam_policy_document.node_registration.json
}

resource "aws_iam_instance_profile" "node" {
  name = "${var.name}-node"
  path = "/aws-pcs/"
  role = aws_iam_role.node.name
  tags = local.tags
}

resource "aws_launch_template" "node" {
  name        = "${var.name}-node"
  description = "AWS PCS compute nodes"

  vpc_security_group_ids = [aws_security_group.pcs.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, { Name = "${var.name}-node" })
  }

  tags = local.tags
}

resource "awscc_pcs_compute_node_group" "compute" {
  name            = "compute"
  cluster_id      = awscc_pcs_cluster.this.cluster_id
  ami_id          = data.aws_ami.pcs.id
  subnet_ids      = [var.subnet_id]
  purchase_option = "ONDEMAND"

  custom_launch_template = {
    template_id = aws_launch_template.node.id
    version     = tostring(aws_launch_template.node.latest_version)
  }

  iam_instance_profile_arn = aws_iam_instance_profile.node.arn

  instance_configs = [
    {
      instance_type = var.compute_instance_type
    }
  ]

  scaling_configuration = {
    min_instance_count = 0
    max_instance_count = var.compute_max_instances
  }

  tags = local.tags

  # Not strictly required for the node group itself, but keeps nodes from
  # registering before the accounting records exist.
  depends_on = [
    module.slurm_accounting,
    aws_iam_role_policy.node_registration,
  ]
}

# --- Queue ------------------------------------------------------------------

resource "awscc_pcs_queue" "batch" {
  name       = "batch"
  cluster_id = awscc_pcs_cluster.this.cluster_id

  compute_node_group_configurations = [
    {
      compute_node_group_id = awscc_pcs_compute_node_group.compute.compute_node_group_id
    }
  ]

  # DenyQos refers to a QOS record in slurmdbd. It must exist before the queue
  # is created, hence the depends_on below.
  slurm_configuration = {
    slurm_custom_settings = [
      {
        parameter_name  = "DenyQos"
        parameter_value = "preempt"
      }
    ]
  }

  tags = local.tags

  depends_on = [module.slurm_accounting]
}
