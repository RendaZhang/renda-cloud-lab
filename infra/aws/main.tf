module "network_base" {
  source = "./modules/network_base"
  region = var.region
}

module "nat" {
  source          = "./modules/nat"
  create          = var.create_nat
  public_subnet   = module.network_base.public_subnet_ids[0]
  private_rtb_ids = module.network_base.private_route_table_ids
  depends_on      = [module.network_base]
}

module "alb" {
  source            = "./modules/alb"
  create            = var.create_alb
  public_subnet_ids = module.network_base.public_subnet_ids
  alb_sg_id         = module.network_base.alb_sg_id
  vpc_id            = module.network_base.vpc_id
  depends_on        = [module.network_base]
}