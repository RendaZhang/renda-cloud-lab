output "oidc_provider_arn" {
  description = "OIDC provider ARN for the EKS cluster"
  value       = aws_iam_openid_connect_provider.oidc[0].arn
}

output "oidc_provider_url_without_https" {
  description = "OIDC provider URL for the EKS cluster"
  value       = replace(aws_eks_cluster.this[0].identity[0].oidc[0].issuer, "https://", "")
}