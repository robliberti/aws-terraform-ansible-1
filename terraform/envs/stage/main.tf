module "network" {
  source      = "../../../modules/network"
  name_prefix = var.name_prefix
}

module "compute" {
  source            = "../../../modules/compute"
  name_prefix       = var.name_prefix
  instance_type     = var.instance_type
  my_ip_cidr        = var.my_ip_cidr
  vpc_id            = module.network.vpc_id
  public_subnet_id  = module.network.public_subnet_id
  private_subnet_id = module.network.private_subnet_id
  app_port          = var.app_port
}
