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
    subnet_ids = concat(var.private_subnet_ids, var.public_subnet_ids)
  }

  tags = {
    "Name"                                        = "eksctl-${var.cluster_name}-cluster/ControlPlane"
    "alpha.eksctl.io/cluster-name"                = var.cluster_name
    "alpha.eksctl.io/cluster-oidc-enabled"        = "true"
    "alpha.eksctl.io/eksctl-version"              = "0.210.0"
    "eksctl.cluster.k8s.io/v1alpha1/cluster-name" = var.cluster_name
  }
}

resource "aws_eks_node_group" "ng" {
  count           = var.create ? 1 : 0
  node_role_arn   = var.node_role_arn
  cluster_name    = var.cluster_name
  node_group_name = var.nodegroup_name
  subnet_ids      = var.private_subnet_ids
  capacity_type   = "ON_DEMAND"
  instance_types  = var.instance_types

  ami_type = "AL2023_x86_64_STANDARD"

  update_config {
    max_unavailable = 1
  }

  labels = {
    "alpha.eksctl.io/cluster-name"   = var.cluster_name
    "alpha.eksctl.io/nodegroup-name" = "ng-mixed"
    "role"                           = "worker"
  }

  scaling_config {
    desired_size = 1
    max_size     = 6
    min_size     = 0
  }

  tags = {
    "alpha.eksctl.io/cluster-name"                = var.cluster_name
    "alpha.eksctl.io/eksctl-version"              = "0.210.0"
    "alpha.eksctl.io/nodegroup-name"              = var.nodegroup_name
    "alpha.eksctl.io/nodegroup-type"              = "managed"
    "eksctl.cluster.k8s.io/v1alpha1/cluster-name" = var.cluster_name
  }

  depends_on = [
    aws_eks_cluster.this[0]
  ]
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
    data.tls_certificate.cluster[0]
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
