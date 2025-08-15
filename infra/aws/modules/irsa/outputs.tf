// 输出 Cluster Autoscaler 所使用的 IAM 角色 ARN
output "autoscaler_role_arn" {
  description = "IAM Role ARN for the Cluster Autoscaler"
  value       = aws_iam_role.eks_cluster_autoscaler.arn
}
