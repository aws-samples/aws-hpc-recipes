module "acm-cert-exporter" {
  source              = "./modules/acm-cert-exporter"
  domain_name         = var.domain_name
  acm_certificate_arn = module.acm-certificate.certificate_arn
}

module "acm-certificate" {
  source      = "./modules/acm-certificate"
  region      = var.region
  domain_name = var.domain_name
}

module "res-ready-imagebuilder" {
  source                              = "./modules/res-ready-imagebuilder"
  vpc_id                              = var.vpc_id
  image_builder_infrastructure_subnet = var.image_builder_infrastructure_subnet
}
