region = "us-east-1"

profile = "phase2-sso"

cluster_name = "dev"

nodegroup_capacity_type = "ON_DEMAND"

nodegroup_name = "ng-mixed"

irsa_role_name = "eks-cluster-autoscaler"

service_account_name = "cluster-autoscaler"

kubernetes_default_namespace = "kube-system"

eksctl_version = "0.210.0"

# Enable control plane logs for API server and authenticator
cluster_log_types = ["api", "authenticator"]

# Instance types for EKS node group
instance_types = ["t3.small", "t3.medium"]

# --- Budget settings ---
create_budget              = true
budget_limit_usd           = 90
budget_email               = "rendazhang@qq.com"
budget_alert_threshold_pct = 80
