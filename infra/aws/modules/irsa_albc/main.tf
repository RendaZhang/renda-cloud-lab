// ---------------------------
// IRSA 模块：为 Kubernetes ServiceAccount 绑定 IAM 角色
// 用于 AWS Load Balancer Controller 访问 AWS API
// ---------------------------

resource "aws_iam_role" "aws_load_balancer_controller" {
  name        = var.name                                                            # IAM 角色名称
  description = "IRSA role for AWS Load Balancer Controller in ${var.cluster_name}" # 角色描述
  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17"
      Statement = [
        {
          Action = "sts:AssumeRoleWithWebIdentity"
          Effect = "Allow"
          Principal = {
            Federated = var.oidc_provider_arn # EKS OIDC Provider ARN
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
    create_before_destroy = true # 先创建新角色再销毁旧角色
  }
}

# 创建 AWS Load Balancer Controller IAM 策略
resource "aws_iam_policy" "albc" {
  name        = "${var.cluster_name}-AWSLoadBalancerControllerPolicy"
  description = "Policy for AWS Load Balancer Controller"

  # 官方推荐的权限策略
  policy = file("${path.module}/policy.json")
}

resource "aws_iam_role_policy_attachment" "albc_attach" {
  role       = aws_iam_role.aws_load_balancer_controller.name # 关联的 IAM 角色
  policy_arn = aws_iam_policy.albc.arn                        # IAM 策略 ARN

  depends_on = [
    aws_iam_role.aws_load_balancer_controller,
    aws_iam_policy.albc
  ]

  lifecycle {
    create_before_destroy = true
  }
}
