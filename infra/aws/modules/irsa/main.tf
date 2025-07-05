resource "aws_iam_role" "eks_cluster_autoscaler" {
  name = var.name
  assume_role_policy = jsonencode(
    {
      Statement = [
        {
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "${var.oidc_provider_url_without_https}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            }
          }
          Effect = "Allow"
          Principal = {
            Federated = var.oidc_provider_arn
          }
        }
      ]
      Version = "2012-10-17"
    }
  )
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_attach" {
  role       = var.name
  policy_arn = "arn:aws:iam::563149051155:policy/EKSClusterAutoscalerPolicy"
  depends_on = [
    aws_iam_role.eks_cluster_autoscaler
  ]
}
