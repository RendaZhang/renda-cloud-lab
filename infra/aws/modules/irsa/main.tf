resource "aws_iam_role" "eks_cluster_autoscaler" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.cluster_autoscaler_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_attach" {
  role       = var.name
  policy_arn = "arn:aws:iam::563149051155:policy/EKSClusterAutoscalerPolicy"
}

data "aws_iam_policy_document" "cluster_autoscaler_assume" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url_without_https}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
  }
}
