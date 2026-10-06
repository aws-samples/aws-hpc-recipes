# Example: bootstrap Slurm accounting from a `sacctmgr dump` file.
#
# Use this when you already have a Slurm accounting configuration (for example
# from an on-premises cluster) and want it loaded into a new PCS cluster.
# Produce the file on the source cluster with:
#
#   sacctmgr dump <cluster-name> file=accounting.dump
#
# The cluster name inside the file does not need to match the PCS cluster; all
# associations are retargeted to the cluster selected by cluster_arn.

locals {
  tags = merge(var.tags, {
    Project = var.name
  })
}

resource "aws_security_group" "pcs" {
  name        = var.name
  description = "AWS PCS cluster endpoints and bootstrap Lambda"
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

  cluster_arn   = awscc_pcs_cluster.this.arn
  sacctmgr_load = file("${path.module}/${var.dump_file}")

  tags = local.tags
}
