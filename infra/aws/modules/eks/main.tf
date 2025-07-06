resource "aws_eks_cluster" "this" {
  count                         = var.create ? 1 : 0
  name                          = var.cluster_name
  bootstrap_self_managed_addons = true
  role_arn                      = aws_iam_role.eks_cluster_role[0].arn

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
    "alpha.eksctl.io/eksctl-version"              = var.eksctl_version
    "eksctl.cluster.k8s.io/v1alpha1/cluster-name" = var.cluster_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy[0],
    aws_iam_role_policy_attachment.eks_vpc_resource_controller_policy[0],
    aws_iam_role_policy_attachment.s3_read_only_access_policy[0],
    aws_iam_role_policy_attachment.eks_service_policy[0],
  ]
}

# 创建集群 IAM 角色
resource "aws_iam_role" "eks_cluster_role" {
  count = var.create ? 1 : 0
  name  = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  count      = var.create ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role[0].name
  depends_on = [
    aws_iam_role.eks_cluster_role[0]
  ]
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller_policy" {
  count      = var.create ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role[0].name
  depends_on = [
    aws_iam_role.eks_cluster_role[0]
  ]
}

resource "aws_iam_role_policy_attachment" "s3_read_only_access_policy" {
  count      = var.create ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  role       = aws_iam_role.eks_cluster_role[0].name
  depends_on = [
    aws_iam_role.eks_cluster_role[0]
  ]
}

resource "aws_iam_role_policy_attachment" "eks_service_policy" {
  count      = var.create ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.eks_cluster_role[0].name
  depends_on = [
    aws_iam_role.eks_cluster_role[0]
  ]
}

# 创建 OIDC 提供者：这将允许 EKS 集群与 IAM 角色进行关联
# 以便节点可以使用 IAM 角色进行 API 调用和其他 AWS 服务访问
resource "aws_iam_openid_connect_provider" "oidc" {
  count = var.create ? 1 : 0

  # 需要确保集群已创建并且 OIDC 发行者 URL 可用，以及证书指纹正确
  # 使用 EKS 集群的 OIDC 发行者 URL 和证书的 SHA1 指纹
  url             = try(aws_eks_cluster.this[0].identity[0].oidc[0].issuer, "")
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]

  tags = {
    "alpha.eksctl.io/cluster-name"   = var.cluster_name
    "alpha.eksctl.io/eksctl-version" = var.eksctl_version
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

resource "aws_eks_node_group" "ng" {
  count           = var.create ? 1 : 0
  node_role_arn   = aws_iam_role.eks_node_role[0].arn
  cluster_name    = var.cluster_name
  node_group_name = var.nodegroup_name
  subnet_ids      = var.private_subnet_ids
  capacity_type   = var.nodegroup_capacity_type
  instance_types  = var.instance_types

  launch_template {
    id      = aws_launch_template.eks_node[0].id
    version = aws_launch_template.eks_node[0].latest_version
  }

  ami_type = "AL2023_x86_64_STANDARD"

  update_config {
    max_unavailable = 1
  }

  labels = {
    "alpha.eksctl.io/cluster-name"   = var.cluster_name
    "alpha.eksctl.io/nodegroup-name" = var.nodegroup_name
    "role"                           = "worker"
  }

  scaling_config {
    desired_size = 1
    max_size     = 6
    min_size     = 0
  }

  tags = {
    "alpha.eksctl.io/cluster-name"                = var.cluster_name
    "alpha.eksctl.io/eksctl-version"              = var.eksctl_version
    "alpha.eksctl.io/nodegroup-name"              = var.nodegroup_name
    "alpha.eksctl.io/nodegroup-type"              = "managed"
    "eksctl.cluster.k8s.io/v1alpha1/cluster-name" = var.cluster_name
  }

  depends_on = [
    aws_eks_cluster.this[0],
    aws_security_group_rule.node_to_cluster_api[0],
    aws_security_group_rule.cluster_to_node[0],
    aws_security_group_rule.node_self_all[0],
    aws_security_group_rule.node_ssh[0],
    aws_security_group_rule.node_nodeport[0],
    aws_launch_template.eks_node[0],
    aws_iam_role_policy_attachment.eks_worker_policy[0],
    aws_iam_role_policy_attachment.eks_cni_policy[0],
    aws_iam_role_policy_attachment.ecr_read_policy[0],
  ]
}

# 添加随机后缀防止名称冲突
resource "random_id" "role_suffix" {
  count       = var.create ? 1 : 0
  byte_length = 4
}

# 创建节点 IAM 角色
resource "aws_iam_role" "eks_node_role" {
  count = var.create ? 1 : 0
  name  = "${var.cluster_name}-node-role-${random_id.role_suffix[0].hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  depends_on = [
    aws_eks_cluster.this[0],
    random_id.role_suffix[0]
  ]
}

resource "aws_iam_role_policy_attachment" "eks_worker_policy" {
  count      = var.create ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role[0].name
  depends_on = [
    aws_iam_role.eks_node_role[0]
  ]
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  count      = var.create ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role[0].name
  depends_on = [
    aws_iam_role.eks_node_role[0]
  ]
}

resource "aws_iam_role_policy_attachment" "ecr_read_policy" {
  count      = var.create ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role[0].name
  depends_on = [
    aws_iam_role.eks_node_role[0]
  ]
}

# 添加节点安全组
resource "aws_security_group" "node" {
  count       = var.create ? 1 : 0
  name_prefix = "eks-node-${var.cluster_name}-"
  vpc_id      = var.vpc_id # 需要新增 vpc_id 变量
  description = "EKS node communication"

  # 出站规则
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name"                                      = "eks-node-${var.cluster_name}"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }

  depends_on = [
    aws_eks_cluster.this[0]
  ]
}

# 允许节点访问集群 API
resource "aws_security_group_rule" "node_to_cluster_api" {
  count       = var.create ? 1 : 0
  description = "Allow node to communicate with control plane"

  security_group_id        = aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.node[0].id

  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  depends_on = [
    aws_security_group.node
  ]
}

# 允许节点安全组内所有流量（节点间通信）
resource "aws_security_group_rule" "node_self_all" {
  count       = var.create ? 1 : 0
  description = "Allow node-to-node communication"

  security_group_id = aws_security_group.node[0].id

  type      = "ingress"
  from_port = 0
  to_port   = 0
  protocol  = "-1"
  self      = true

  depends_on = [
    aws_security_group.node
  ]
}

# Optional SSH access to nodes
resource "aws_security_group_rule" "node_ssh" {
  count       = var.create ? 1 : 0
  description = "Allow SSH access to nodes"

  security_group_id = aws_security_group.node[0].id
  cidr_blocks       = var.ssh_cidrs

  type      = "ingress"
  from_port = 22
  to_port   = 22
  protocol  = "tcp"

  depends_on = [
    aws_security_group.node
  ]
}

# Allow NodePort services
resource "aws_security_group_rule" "node_nodeport" {
  count       = var.create ? 1 : 0
  description = "Allow NodePort service access"

  security_group_id = aws_security_group.node[0].id
  cidr_blocks       = var.nodeport_cidrs

  type      = "ingress"
  from_port = 30000
  to_port   = 32767
  protocol  = "tcp"

  depends_on = [
    aws_security_group.node
  ]
}

# 允许控制平面与节点通信
resource "aws_security_group_rule" "cluster_to_node" {
  count       = var.create ? 1 : 0
  description = "Allow control plane to communicate with node"

  security_group_id        = aws_security_group.node[0].id
  source_security_group_id = aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id

  type      = "ingress"
  from_port = 0
  to_port   = 65535
  protocol  = "tcp"

  depends_on = [
    aws_security_group.node
  ]
}

# 创建节点组的启动模板
resource "aws_launch_template" "eks_node" {
  count       = var.create ? 1 : 0
  name_prefix = "eks-${var.cluster_name}-node-"

  # 关联节点安全组
  vpc_security_group_ids = [aws_security_group.node[0].id]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                                        = "eks-node-${var.cluster_name}"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  }

  depends_on = [
    aws_security_group.node,
    aws_eks_cluster.this[0]
  ]

  lifecycle {
    create_before_destroy = true
  }
}
