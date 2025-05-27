# modules/compute/main.tf

# Permissive cluster security group
module "cluster_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"

  name        = "cluster-${var.project_name}"
  description = "Supports communications between AWS PCS controller, compute nodes, and client nodes"
  vpc_id      = var.vpc_id

  ingress_with_self = [
    {
      rule        = "all-all"
      description = "Allow all internal cluster communication"
    }
  ]

  egress_rules = ["all-all"]
  egress_with_self = [
    {
      rule        = "all-all"
      description = "Allow all internal cluster communication"
    }
  ]

  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = merge(var.tags, {
    Name = "${var.project_name}-cluster"
  })
}

# SSH ingress security group
module "ssh_security_group" {
  source  = "terraform-aws-modules/security-group/aws//modules/ssh"
  version = "5.3.0"

  name        = "inbound-ssh-${var.project_name}"
  description = "Allows inbound SSH access"
  vpc_id      = var.vpc_id

  ingress_cidr_blocks = [var.ssh_cidr_block]

  tags = merge(var.tags, {
    Name = "${var.project_name}-ssh"
  })
}

# Login Launch Template
resource "aws_launch_template" "login" {
  name = "login-${var.project_name}"

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name       = "${var.project_name}-login"
      HPCRecipes = "true"
    })
  }

  key_name = var.ssh_key_name

  vpc_security_group_ids = [
    module.cluster_security_group.security_group_id,
    module.ssh_security_group.security_group_id
  ]

  user_data = base64encode(templatefile("${path.module}/templates/login_userdata.tpl", {
    efs_filesystem_id = var.efs_filesystem_id
    fsx_filesystem_id = var.fsx_filesystem_id
    fsx_dns_name      = var.fsx_dns_name
    fsx_mount_name    = var.fsx_mount_name
    aws_region        = var.aws_region
  }))

  iam_instance_profile {
    arn = var.instance_profile_arn
  }
}

# Compute Launch Template
resource "aws_launch_template" "compute" {
  name = "compute-${var.project_name}"

  metadata_options {
    http_endpoint               = "enabled"
    http_put_response_hop_limit = 2
    http_tokens                 = "required"
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name       = "${var.project_name}-compute"
      HPCRecipes = "true"
    })
  }

  key_name = var.ssh_key_name

  vpc_security_group_ids = [
    module.cluster_security_group.security_group_id
  ]

  user_data = base64encode(templatefile("${path.module}/templates/compute_userdata.tpl", {
    efs_filesystem_id = var.efs_filesystem_id
    fsx_filesystem_id = var.fsx_filesystem_id
    fsx_dns_name      = var.fsx_dns_name
    fsx_mount_name    = var.fsx_mount_name
    aws_region        = var.aws_region
  }))

  iam_instance_profile {
    arn = var.instance_profile_arn
  }
}

# PCS Cluster
resource "awscc_pcs_cluster" "main" {
  name = "${var.project_name}-${var.pcs_cluster_name}"
  size = var.pcs_cluster_size

  scheduler = {
    type    = "SLURM"
    version = var.pcs_cluster_slurm_version
  }

  networking = {
    security_group_ids = [module.cluster_security_group.security_group_id]
    subnet_ids         = [var.management_subnet_id]
  }

  slurm_configuration = {
    accounting = {
      mode = "STANDARD"
      default_purge_time_in_days = 30
    }
    slurm_custom_settings = [ {
      parameter_name = "AccountingStorageEnforce"
      parameter_value = "associations,limits,qos"
    } ]
  }

  tags = merge(var.tags, {
    Project = var.project_name
  })
}

# Login
resource "awscc_pcs_compute_node_group" "login" {
  name = "login"

  cluster_id = awscc_pcs_cluster.main.cluster_id
  custom_launch_template = {
    template_id      = aws_launch_template.login.id
    version = 1
  }
  iam_instance_profile_arn = var.instance_profile_arn
  instance_configs = [{
    instance_type = var.pcs_cng_login_instance_type
  }]
  scaling_configuration = {
    min_instance_count = 1
    max_instance_count  = 1
  }
  subnet_ids = [var.access_subnet_id]
  ami_id    = var.pcs_cng_ami_id

  tags = merge(var.tags, {
    Project = var.project_name
  })
}

# Compute
resource "awscc_pcs_compute_node_group" "compute" {
  name = "compute"

  cluster_id = awscc_pcs_cluster.main.cluster_id
  custom_launch_template = {
    template_id      = aws_launch_template.compute.id
    version = 1
  }
  iam_instance_profile_arn = var.instance_profile_arn
  instance_configs = [{
    instance_type = var.pcs_cng_compute_instance_type
  }]
  scaling_configuration = {
    min_instance_count = 0
    max_instance_count  = 4
  }
  subnet_ids = [var.compute_subnet_id]
  ami_id    = var.pcs_cng_ami_id

  tags = merge(var.tags, {
    Project = var.project_name
  })
}

# Demo queue
resource "awscc_pcs_queue" "demo" {
  name = "demo"
  cluster_id = awscc_pcs_cluster.main.cluster_id
  compute_node_group_configurations = [ {
    compute_node_group_id = awscc_pcs_compute_node_group.compute.compute_node_group_id
  } ]
  
  tags = merge(var.tags, {
    Project = var.project_name
  })
}
