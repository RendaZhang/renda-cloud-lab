output "irsa_role_arn" {
  description = "IRSA role ARN"
  value       = try(aws_iam_role.this[0].arn, null)
}

output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.this.arn
}

output "s3_prefix" {
  description = "S3 prefix for objects"
  value       = var.s3_prefix
}

output "bucket_url" {
  description = "S3 URL with prefix"
  value       = "s3://${aws_s3_bucket.this.bucket}/${var.s3_prefix}"
}

output "bucket_policy_id" {
  description = "S3 bucket policy resource ID"
  value       = aws_s3_bucket_policy.this.id
}

output "bucket_lifecycle_rules" {
  description = "Lifecycle rule IDs and statuses"
  value       = [for r in aws_s3_bucket_lifecycle_configuration.this.rule : "${r.id}:${r.status}"]
}
