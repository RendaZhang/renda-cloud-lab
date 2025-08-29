// ---------------------------
// IRSA 模块：为 Grafana 绑定 IAM 角色
// 权限：AmazonPrometheusQueryAccess（最小只读权限，用于查询 AMP）
// ---------------------------

resource "aws_iam_role" "grafana_amp_query" {
  name        = var.name
  description = "IRSA role for Grafana AMP query in ${var.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = var.oidc_provider_arn
        }
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

# 附加 AWS 托管策略：AmazonPrometheusQueryAccess（只读）
resource "aws_iam_role_policy_attachment" "query_access" {
  role       = aws_iam_role.grafana_amp_query.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusQueryAccess"

  lifecycle {
    create_before_destroy = true
  }
}
