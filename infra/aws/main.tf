module "network_base" {
  source = "./modules/network_base"
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

module "eks" {
  source                  = "./modules/eks"
  create                  = var.create_eks
  cluster_name            = var.cluster_name
  vpc_id                  = module.network_base.vpc_id
  nodegroup_capacity_type = var.nodegroup_capacity_type
  cluster_log_types       = var.cluster_log_types
  public_subnet_ids       = module.network_base.public_subnet_ids
  private_subnet_ids      = module.network_base.private_subnet_ids
  nodegroup_name          = var.nodegroup_name
  instance_types          = var.instance_types
  ssh_cidrs               = var.ssh_cidrs
  nodeport_cidrs          = var.nodeport_cidrs
  eksctl_version          = var.eksctl_version
  depends_on              = [module.network_base]
}

module "irsa" {
  source                          = "./modules/irsa"
  count                           = var.create_eks ? 1 : 0
  name                            = var.irsa_role_name
  namespace                       = var.kubernetes_default_namespace
  cluster_name                    = var.cluster_name
  service_account_name            = var.service_account_name
  oidc_provider_arn               = module.eks.oidc_provider_arn
  oidc_provider_url_without_https = module.eks.oidc_provider_url_without_https
  depends_on                      = [module.eks]
}

resource "aws_route53_record" "lab_alias" {
  count   = var.create_alb ? 1 : 0
  zone_id = module.network_base.hosted_zone_id
  name    = "" # 保留空
  type    = "A"
  alias {
    name                   = module.alb.alb_dns     # 动态 ALB DNS
    zone_id                = module.alb.alb_zone_id # ALB 所属 Hosted-zone
    evaluate_target_health = false
  }
  depends_on = [module.alb]
}
