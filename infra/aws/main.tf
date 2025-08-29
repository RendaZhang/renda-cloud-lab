// ---------------------------
// 主模块：组合各子模块形成完整的实验环境
// 包含网络基础设施、NAT 网关、应用负载均衡、EKS 集群以及 IRSA 角色等
// ---------------------------

module "network_base" {
  source       = "./modules/network_base" # VPC、子网、路由表等基础网络资源
  cluster_name = var.cluster_name
}

module "nat" {
  source          = "./modules/nat"                             # NAT 网关模块
  create          = var.create_nat                              # 是否创建 NAT 资源
  public_subnet   = module.network_base.public_subnet_ids[0]    # NAT 网关所在的公有子网
  private_rtb_ids = module.network_base.private_route_table_ids # 需要关联的私有路由表
  depends_on      = [module.network_base]                       # 依赖网络基础模块
}

module "alb" {
  source            = "./modules/alb"                       # ALB 模块
  create            = var.create_alb                        # 是否创建 ALB
  public_subnet_ids = module.network_base.public_subnet_ids # ALB 使用的公有子网
  alb_sg_id         = module.network_base.alb_sg_id         # ALB 专用安全组
  vpc_id            = module.network_base.vpc_id            # 所属 VPC
  depends_on        = [module.network_base]                 # 依赖网络基础模块
}

module "eks" {
  source                  = "./modules/eks"                        # EKS 集群模块
  create                  = var.create_eks                         # 是否创建 EKS
  cluster_name            = var.cluster_name                       # 集群名称
  vpc_id                  = module.network_base.vpc_id             # 集群所在 VPC
  nodegroup_capacity_type = var.nodegroup_capacity_type            # 节点组容量类型
  cluster_log_types       = var.cluster_log_types                  # 控制平面日志类型
  public_subnet_ids       = module.network_base.public_subnet_ids  # 公有子网
  private_subnet_ids      = module.network_base.private_subnet_ids # 私有子网
  nodegroup_name          = var.nodegroup_name                     # 节点组名称
  instance_types          = var.instance_types                     # 节点实例类型
  ssh_cidrs               = var.ssh_cidrs                          # 允许 SSH 的 CIDR
  nodeport_cidrs          = var.nodeport_cidrs                     # NodePort 访问 CIDR
  eksctl_version          = var.eksctl_version                     # eksctl 版本
  depends_on              = [module.network_base]                  # 依赖网络基础模块
}

module "irsa" {
  source                          = "./modules/irsa"                           # IRSA 模块，创建服务账户角色
  count                           = var.create_eks ? 1 : 0                     # 仅在创建 EKS 时启用
  name                            = var.irsa_role_name                         # IAM 角色名称
  namespace                       = var.kubernetes_default_namespace           # Kubernetes 命名空间
  cluster_name                    = var.cluster_name                           # 集群名称
  service_account_name            = var.service_account_name                   # ServiceAccount 名称
  oidc_provider_arn               = module.eks.oidc_provider_arn               # OIDC Provider ARN
  oidc_provider_url_without_https = module.eks.oidc_provider_url_without_https # OIDC URL（无 https）
  depends_on                      = [module.eks]                               # 依赖 EKS 模块
}

module "irsa_albc" {
  source                          = "./modules/irsa_albc"                      # IRSA 模块，为 ALBC 创建角色
  count                           = var.create_eks ? 1 : 0                     # 仅在创建 EKS 时启用
  name                            = var.albc_irsa_role_name                    # ALBC IAM 角色名称
  namespace                       = var.albc_namespace                         # ALBC 所在命名空间
  cluster_name                    = var.cluster_name                           # 集群名称
  service_account_name            = var.albc_service_account_name              # ALBC ServiceAccount 名称
  oidc_provider_arn               = module.eks.oidc_provider_arn               # OIDC Provider ARN
  oidc_provider_url_without_https = module.eks.oidc_provider_url_without_https # OIDC URL（无 https）
  depends_on                      = [module.eks]                               # 依赖 EKS 模块
}

module "irsa_adot_amp" {
  source                          = "./modules/irsa_adot_amp"                  # IRSA 模块，为 ADOT Collector 提供 AMP remote_write 权限
  count                           = var.create_eks ? 1 : 0                     # 仅在创建 EKS 时启用
  name                            = var.adot_irsa_role_name                    # IAM 角色名称
  namespace                       = var.adot_namespace                         # ADOT Collector 所在命名空间
  cluster_name                    = var.cluster_name                           # 集群名称
  service_account_name            = var.adot_service_account_name              # ADOT Collector 的 ServiceAccount 名称
  oidc_provider_arn               = module.eks.oidc_provider_arn               # OIDC Provider ARN
  oidc_provider_url_without_https = module.eks.oidc_provider_url_without_https # OIDC URL（无 https）
  depends_on                      = [module.eks]                               # 依赖 EKS 模块
}

module "irsa_grafana_amp" {
  source                          = "./modules/irsa_grafana_amp"               # IRSA 模块，为 Grafana 提供 AMP 查询权限
  count                           = var.create_eks ? 1 : 0                     # 仅在创建 EKS 时启用
  name                            = var.grafana_irsa_role_name                 # IAM 角色名称
  namespace                       = var.grafana_namespace                      # Grafana 所在命名空间
  cluster_name                    = var.cluster_name                           # 集群名称
  service_account_name            = var.grafana_service_account_name           # Grafana 的 ServiceAccount 名称
  oidc_provider_arn               = module.eks.oidc_provider_arn               # OIDC Provider ARN
  oidc_provider_url_without_https = module.eks.oidc_provider_url_without_https # OIDC URL（无 https）
  depends_on                      = [module.eks]                               # 依赖 EKS 模块
}

module "task_api" {
  source            = "./modules/app_irsa_s3"                    # 应用级 S3 桶 + IRSA 权限模块
  create_irsa       = var.create_eks                             # 仅在创建 EKS 时生成 IRSA 角色（s3 桶不受影响）
  cluster_name      = var.cluster_name                           # 集群名称
  region            = var.region                                 # 部署区域
  namespace         = var.task_api_namespace                     # 应用所在命名空间
  sa_name           = var.task_api_sa_name                       # 目标 ServiceAccount 名称
  app_name          = var.task_api_app_name                      # 应用名称
  s3_bucket_name    = var.task_api_s3_bucket_name                # 可选指定 S3 桶名称
  s3_prefix         = var.task_api_s3_prefix                     # S3 前缀
  oidc_provider_arn = module.eks.oidc_provider_arn               # OIDC Provider ARN
  oidc_provider_url = module.eks.oidc_provider_url_without_https # OIDC Provider URL（无 https）
  vpc_id            = module.network_base.vpc_id                 # 桶策略限制访问的 VPC
  depends_on        = [module.eks]                               # 依赖 EKS 模块
}

resource "aws_route53_record" "lab_alias" {
  count   = var.create_alb ? 1 : 0             # 仅在创建 ALB 时创建记录
  zone_id = module.network_base.hosted_zone_id # DNS Hosted Zone ID
  name    = ""                                 # TODO: 设置所需的子域名
  type    = "A"                                # A 记录
  alias {
    name                   = module.alb.alb_dns     # 指向 ALB 的 DNS
    zone_id                = module.alb.alb_zone_id # ALB 所属的 Hosted Zone
    evaluate_target_health = false                  # 不检查目标健康状况
  }
  depends_on = [module.alb] # 等待 ALB 创建完成
}
