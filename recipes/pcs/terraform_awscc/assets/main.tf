module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.19.0"

  name = var.project_name
  cidr = var.vpc_cidr

  azs                  = [var.availability_zone]
  private_subnets      = [cidrsubnet(var.vpc_cidr, 4, 0), cidrsubnet(var.vpc_cidr, 4, 2), cidrsubnet(var.vpc_cidr, 4, 3)]
  private_subnet_names = ["management", "storage", "compute"]
  public_subnets       = [cidrsubnet(var.vpc_cidr, 4, 1)]
  public_subnet_names  = ["access"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  map_public_ip_on_launch = true

  tags = var.common_tags
}

module "efs" {
  source  = "terraform-aws-modules/efs/aws"
  version = "1.7.0"
  name    = var.project_name
  # Mount targets / security group
  mount_targets = {
    (var.availability_zone) = {
      # storage subnet
      subnet_id = module.vpc.private_subnets[1]
    }
  }
  # Security group
  create_security_group = true
  security_group_vpc_id = module.vpc.vpc_id
  security_group_rules = {
    vpc = {
      # relying on the defaults provided for EFS/NFS (2049/TCP + ingress)
      description = "Allows traffic to EFS filesystems"
      cidr_blocks = [module.vpc.public_subnets_cidr_blocks[0], module.vpc.private_subnets_cidr_blocks[1], module.vpc.private_subnets_cidr_blocks[2]]
    }
  }

  tags = var.common_tags
}

module "fsx_lustre" {
  source                = "terraform-aws-modules/fsx/aws//modules/lustre"
  version               = "1.2.0"
  name                  = var.project_name
  data_compression_type = "LZ4"
  deployment_type       = "SCRATCH_2"
  storage_capacity      = 1200
  storage_type          = "SSD"
  # Storage subnet
  subnet_ids = [module.vpc.private_subnets[1]]
  # Security group
  create_security_group = true
  security_group_ingress_rules = {
    in_a = {
      cidr_ipv4   = module.vpc.vpc_cidr_block
      description = "Allow inbound traffic from the VPC"
      from_port   = 988
      to_port     = 988
      protocol    = "tcp"
    }
    in_b = {
      cidr_ipv4   = module.vpc.vpc_cidr_block
      description = "Allow inbound traffic from the VPC"
      from_port   = 1018
      to_port     = 1023
      protocol    = "tcp"
    }
  }
  security_group_egress_rules = {
    out = {
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow all traffic"
      ip_protocol = "-1"
    }
  }

  tags = var.common_tags
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  tags         = var.common_tags
}

# PCS-specific resources - cluster, cng, queue, security groups, launch templates, AMIs, etc.
module "compute" {
  source = "./modules/compute"

  project_name              = var.project_name
  aws_region                = var.aws_region
  ssh_key_name              = var.ssh_key_name
  ssh_cidr_block            = var.ssh_cidr_block
  pcs_cluster_name          = var.pcs_cluster_name
  pcs_cluster_size          = var.pcs_cluster_size
  pcs_cluster_slurm_version = var.pcs_cluster_slurm_version
  pcs_cng_ami_id            = var.pcs_cng_ami_id

  vpc_id               = module.vpc.vpc_id
  management_subnet_id = module.vpc.private_subnets[0]
  compute_subnet_id = module.vpc.private_subnets[2]
  access_subnet_id = module.vpc.public_subnets[0]

  instance_profile_arn = module.iam.instance_profile_arn

  efs_filesystem_id = module.efs.id
  fsx_filesystem_id = module.fsx_lustre.file_system_id
  fsx_dns_name      = module.fsx_lustre.file_system_dns_name
  fsx_mount_name    = module.fsx_lustre.file_system_mount_name

  tags = var.common_tags
}
