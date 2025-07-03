resource "aws_eks_cluster" "this" {
  count                         = var.create ? 1 : 0
  name                          = var.cluster_name
  bootstrap_self_managed_addons = false
  role_arn                      = var.cluster_role_arn

  enabled_cluster_log_types = var.cluster_log_types

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  kubernetes_network_config {
    ip_family         = "ipv4"
    service_ipv4_cidr = "172.20.0.0/16"
    elastic_load_balancing {
      enabled = false
    }
  }

  upgrade_policy {
    support_type = "EXTENDED"
  }

  vpc_config {
    security_group_ids = var.cluster_security_group_id != "" ? [var.cluster_security_group_id] : []
    subnet_ids         = concat(var.private_subnet_ids, var.public_subnet_ids)
  }

  tags = {
    "Name"                                        = "eksctl-dev-cluster/ControlPlane"
    "alpha.eksctl.io/cluster-name"                = "dev"
    "alpha.eksctl.io/cluster-oidc-enabled"        = "true"
    "alpha.eksctl.io/eksctl-version"              = "0.210.0"
    "eksctl.cluster.k8s.io/v1alpha1/cluster-name" = "dev"
  }
}

resource "aws_eks_node_group" "ng" {
  count           = var.create ? 1 : 0
  node_role_arn   = var.node_role_arn
  cluster_name    = var.cluster_name
  node_group_name = var.nodegroup_name
  subnet_ids      = var.private_subnet_ids
  capacity_type   = "SPOT"
  instance_types = [
    "t3.small",
    "t3.medium"
  ]

  labels = {
    "alpha.eksctl.io/cluster-name"   = "dev"
    "alpha.eksctl.io/nodegroup-name" = "ng-mixed"
    "role"                           = "worker"
  }

  scaling_config {
    desired_size = 1
    max_size     = 6
    min_size     = 0
  }

  tags = {
    "alpha.eksctl.io/cluster-name"                = "dev"
    "alpha.eksctl.io/eksctl-version"              = "0.210.0"
    "alpha.eksctl.io/nodegroup-name"              = "ng-mixed"
    "alpha.eksctl.io/nodegroup-type"              = "managed"
    "eksctl.cluster.k8s.io/v1alpha1/cluster-name" = "dev"
  }

  depends_on = [aws_eks_cluster.this[0]]
}

# 添加集群就绪等待
resource "time_sleep" "wait_for_cluster" {
  count = var.create ? 1 : 0

  create_duration = "2m"
  triggers = {
    cluster_arn = aws_eks_cluster.this[0].arn
  }

  depends_on = [aws_eks_cluster.this[0]]
}

resource "aws_iam_openid_connect_provider" "oidc" {
  count = var.create ? 1 : 0

  url = try(aws_eks_cluster.this[0].identity[0].oidc[0].issuer, "")

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]

  tags = {
    "alpha.eksctl.io/cluster-name"   = var.cluster_name
    "alpha.eksctl.io/eksctl-version" = "0.210.0"
  }

  depends_on = [
    aws_eks_cluster.this[0],
    time_sleep.wait_for_cluster
  ]

  lifecycle {
    # 允许销毁重建
    create_before_destroy = true

    # 忽略指纹变化（证书可能更新）
    ignore_changes = [thumbprint_list]

    # 重建时保留旧资源直到新资源就绪
    replace_triggered_by = [
      aws_eks_cluster.this[0].identity[0].oidc[0].issuer # 当集群URL变化时替换
    ]
  }
}

# 添加证书数据源
data "tls_certificate" "cluster" {
  count = var.create ? 1 : 0
  url   = try(aws_eks_cluster.this[0].identity[0].oidc[0].issuer, "")
}
