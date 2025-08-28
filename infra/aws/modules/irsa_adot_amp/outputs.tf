output "adot_amp_role_arn" {
  description = "IAM Role ARN for ADOT Collector AMP remote_write"
  value       = aws_iam_role.adot_amp_remote_write.arn
}
