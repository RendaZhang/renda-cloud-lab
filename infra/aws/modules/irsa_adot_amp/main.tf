// ---------------------------
// IRSA 模块：为 ADOT Collector 绑定 IAM 角色
// 权限：AmazonPrometheusRemoteWriteAccess（最小权限用于 AMP remote_write）
// ---------------------------

resource "aws_iam_role" "adot_amp_remote_write" {
  name        = var.name
  description = "IRSA role for ADOT Collector AMP remote_write in ${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sts:AssumeRoleWithWebIdentity",
        Principal = {
          Federated = var.oidc_provider_arn
        },
        Condition = {
          StringEquals = {
            "${var.oidc_provider_url_without_https}:aud" = "sts.amazonaws.com",
            "${var.oidc_provider_url_without_https}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
          }
        }
      }
    ]
  })

  lifecycle {
    create_before_destroy = true
  }
}

# 附加 AWS 托管策略：AmazonPrometheusRemoteWriteAccess
resource "aws_iam_role_policy_attachment" "remote_write" {
  role       = aws_iam_role.adot_amp_remote_write.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"

  lifecycle {
    create_before_destroy = true
  }
}
