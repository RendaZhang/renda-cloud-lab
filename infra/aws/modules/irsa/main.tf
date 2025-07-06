resource "aws_iam_role" "eks_cluster_autoscaler" {
  name        = var.name
  description = "IRSA role for Cluster Autoscaler in ${var.cluster_name}"
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Action = "sts:AssumeRoleWithWebIdentity"
          Effect = "Allow"
          Principal = {
            Federated = var.oidc_provider_arn
          }
          Condition = {
            StringEquals = {
              "${var.oidc_provider_url_without_https}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            }
          }
        }
      ]
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# 创建 Cluster Autoscaler IAM 策略
resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${var.cluster_name}-ClusterAutoscalerPolicy"
  description = "Policy for EKS Cluster Autoscaler"

  # 使用最佳实践策略（添加了缺失的权限）
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:DescribeInstanceTypes",
          "eks:DescribeNodegroup",
          "ec2:DescribeImages"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_attach" {
  role       = aws_iam_role.eks_cluster_autoscaler.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn

  depends_on = [
    aws_iam_role.eks_cluster_autoscaler,
    aws_iam_policy.cluster_autoscaler
  ]

  lifecycle {
    create_before_destroy = true
  }
}
