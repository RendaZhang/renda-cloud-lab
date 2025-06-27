output "autoscaler_role_arn" {
  value = aws_iam_role.eks_cluster_autoscaler.arn
}