output "grafana_amp_role_arn" {
  description = "IAM Role ARN for Grafana AMP query"
  value       = aws_iam_role.grafana_amp_query.arn
}
