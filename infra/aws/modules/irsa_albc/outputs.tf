// 输出 AWS Load Balancer Controller 所使用的 IAM 角色 ARN
output "albc_role_arn" {
  description = "IAM Role ARN for the AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}
