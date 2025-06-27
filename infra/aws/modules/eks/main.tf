resource "aws_eks_cluster" "this" {
  count                         = var.create ? 1 : 0
  name                          = var.cluster_name
  bootstrap_self_managed_addons = false
  role_arn                      = var.cluster_role_arn
  enabled_cluster_log_types = [
    "api",
    "authenticator"
  ]
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
    security_group_ids = ["sg-0e93d691d659c1eda"]
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
  count                  = var.create ? 1 : 0
  node_role_arn          = "arn:aws:iam::563149051155:role/eksctl-dev-nodegroup-ng-mixed-NodeInstanceRole-6iVyvrDnxZQO"
  cluster_name           = var.cluster_name
  node_group_name        = var.nodegroup_name
  subnet_ids             = var.private_subnet_ids
  instance_types = [
    "t3.small",
    "t3.medium"
  ]

  labels = {
    "alpha.eksctl.io/cluster-name"   = "dev"
    "alpha.eksctl.io/nodegroup-name" = "ng-mixed"
    "role"                           = "worker"
  }

  launch_template {
    id      = "lt-0fcd1b589948c6a31"
    version = "1"
  }

  scaling_config {
    desired_size = 2
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
}

resource "aws_iam_openid_connect_provider" "oidc" {
  count           = var.create ? 1 : 0
  url             = aws_eks_cluster.this[0].identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
  tags = {
    "alpha.eksctl.io/cluster-name"   = var.cluster_name
    "alpha.eksctl.io/eksctl-version" = "0.210.0"
  }
}