region = "us-east-1" # 部署区域

profile = "phase2-sso" # 本地 AWS CLI profile

cluster_name = "dev" # EKS 集群名称

nodegroup_capacity_type = "ON_DEMAND" # 节点组容量类型：ON_DEMAND 或 SPOT

nodegroup_name = "ng-mixed" # 节点组名称

irsa_role_name = "eks-cluster-autoscaler" # IRSA 角色名称

service_account_name = "cluster-autoscaler" # Kubernetes ServiceAccount 名称

kubernetes_default_namespace = "kube-system" # 默认命名空间

eksctl_version = "0.210.0" # eksctl 版本

# Enable control plane logs for API server and authenticator
cluster_log_types = ["api", "authenticator"]

# Instance types for EKS node group
instance_types = ["t3.small", "t3.medium"]

# ALBC IRSA 配置
albc_irsa_role_name       = "aws-load-balancer-controller" # ALBC IRSA 角色名称
albc_service_account_name = "aws-load-balancer-controller" # ALBC ServiceAccount 名称
albc_namespace            = "kube-system"                  # ALBC 所在命名空间

# --- Budget settings ---
create_budget              = true                # 是否创建预算
budget_limit_usd           = 90                  # 每月预算上限（美元）
budget_email               = "rendazhang@qq.com" # 接收预算提醒的邮箱
budget_alert_threshold_pct = 80                  # 超出预算百分比触发提醒
