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
    "Name"                                        = "eksctl-dev-cluster/ControlPlane"
    "alpha.eksctl.io/cluster-name"                = "dev"
    "alpha.eksctl.io/cluster-oidc-enabled"        = "true"
    "alpha.eksctl.io/eksctl-version"              = "0.210.0"
    "eksctl.cluster.k8s.io/v1alpha1/cluster-name" = "dev"
  }
}

# 添加节点安全组
resource "aws_security_group" "node" {
  count       = var.create ? 1 : 0
  name_prefix = "eks-node-${var.cluster_name}-"
  vpc_id      = var.vpc_id # 需要新增 vpc_id 变量

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
    time_sleep.wait_for_cluster,
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
    aws_security_group.node,
    time_sleep.wait_for_cluster,
    aws_eks_cluster.this[0]
  ]
}

# 允许控制平面与节点通信
resource "aws_security_group_rule" "cluster_to_node" {
  count       = var.create ? 1 : 0
  description = "Allow control plane to communicate with node"

  security_group_id        = aws_security_group.node[0].id
  source_security_group_id = aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id

  type      = "ingress"
  from_port = 1025
  to_port   = 65535
  protocol  = "tcp"

  depends_on = [
    aws_security_group.node,
    time_sleep.wait_for_cluster,
    aws_eks_cluster.this[0]
  ]
}

# 允许控制平面对节点端口 443 的访问
resource "aws_security_group_rule" "cluster_to_node_https" {
  count       = var.create ? 1 : 0
  description = "Allow control plane to access node on HTTPS port"

  security_group_id        = aws_security_group.node[0].id
  source_security_group_id = aws_eks_cluster.this[0].vpc_config[0].cluster_security_group_id

  type      = "ingress"
  from_port = 443
  to_port   = 443
  protocol  = "tcp"

  depends_on = [
    aws_security_group.node,
    time_sleep.wait_for_cluster,
    aws_eks_cluster.this[0]
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

# 创建启动模板
resource "aws_launch_template" "eks_node" {
  count       = var.create ? 1 : 0
  name_prefix = "eks-${var.cluster_name}-node-"

  # 使用最新的 EKS 优化 AMI
  image_id = data.aws_ami.eks_optimized[0].id

  # 注入引导脚本
  user_data = data.template_cloudinit_config.node_bootstrap[0].rendered

  # 关联节点安全组
  vpc_security_group_ids = [aws_security_group.node[0].id]

  # 添加实例类型标签
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name                                        = "eks-node-${var.cluster_name}"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  }

  # 添加卷大小配置
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  depends_on = [
    aws_security_group.node,
    aws_eks_cluster.this[0],
    data.aws_ami.eks_optimized[0],
    data.template_cloudinit_config.node_bootstrap[0]
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_eks_node_group" "ng" {
  count           = var.create ? 1 : 0
  node_role_arn   = var.node_role_arn
  cluster_name    = var.cluster_name
  node_group_name = var.nodegroup_name
  subnet_ids      = var.private_subnet_ids
  capacity_type   = "SPOT"
  instance_types  = var.instance_types

  launch_template {
    id      = aws_launch_template.eks_node[0].id
    version = aws_launch_template.eks_node[0].latest_version
  }

  update_config {
    max_unavailable = 1
  }

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

  depends_on = [
    aws_eks_cluster.this[0],
    time_sleep.wait_for_cluster,
    aws_security_group_rule.node_to_cluster_api,
    aws_security_group_rule.cluster_to_node,
    aws_launch_template.eks_node[0]
  ]
}

# 添加集群就绪等待
resource "time_sleep" "wait_for_cluster" {
  count = var.create ? 1 : 0

  # create_duration = "2m"
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
    time_sleep.wait_for_cluster,
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

# 用户数据
data "template_cloudinit_config" "node_bootstrap" {
  count = var.create ? 1 : 0

  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = <<-EOT
      #!/bin/bash
      set -e

      # 验证必要文件存在
      if [ ! -f /etc/eks/bootstrap.sh ]; then
        echo "FATAL: bootstrap.sh missing!" >&2
        exit 1
      fi

      # 使用环境变量避免命令注入
      CLUSTER_NAME="${var.cluster_name}"

      # 执行引导并捕获日志
      /etc/eks/bootstrap.sh "$CLUSTER_NAME" \
        --kubelet-extra-args '--node-labels=role=worker' \
        2>&1 | tee /var/log/eks-bootstrap.log

      # 添加成功标记
      touch /var/run/eks-bootstrap.success
    EOT
  }

  depends_on = [aws_eks_cluster.this[0]]
}

# 获取最新 EKS 优化 AMI
data "aws_ami" "eks_optimized" {
  count       = var.create ? 1 : 0
  owners      = ["amazon"]
  most_recent = true

  filter {
    name   = "name"
    values = ["amazon-eks-node-*-${aws_eks_cluster.this[0].version}-*"]
  }

  depends_on = [aws_eks_cluster.this[0]]
}
