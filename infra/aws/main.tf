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

resource "aws_route53_record" "lab_alias" {
  count   = var.create_alb ? 1 : 0
  zone_id = module.network_base.hosted_zone_id
  name    = "" # lab.rendazhang.com
  type    = "A"
  alias {
    name                   = module.alb.alb_dns     # 动态 ALB DNS
    zone_id                = module.alb.alb_zone_id # ALB 所属 Hosted-zone
    evaluate_target_health = false
  }
}