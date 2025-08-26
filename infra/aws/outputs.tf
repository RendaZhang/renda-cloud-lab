// 输出常用资源信息，便于后续模块或调试使用
output "alb_dns" {
  description = "ALB 的访问域名"
  value       = module.alb.alb_dns
}

output "vpc_id" {
  description = "network_base 模块创建的 VPC ID"
  value       = module.network_base.vpc_id
}

output "public_subnet_ids" {
  description = "所有公有子网的 ID 列表"
  value       = module.network_base.public_subnet_ids
}

output "private_subnet_ids" {
  description = "所有私有子网的 ID 列表"
  value       = module.network_base.private_subnet_ids
}

output "s3_gateway_endpoint_id" {
  description = "S3 网关端点 ID"
  value       = module.network_base.s3_gateway_endpoint_id
}

output "autoscaler_role_arn" {
  description = "EKS Cluster Autoscaler 使用的 IAM 角色 ARN"
  value       = var.create_eks ? module.irsa[0].autoscaler_role_arn : null
}

output "albc_role_arn" {
  description = "AWS Load Balancer Controller 使用的 IAM 角色 ARN"
  value       = var.create_eks ? module.irsa_albc[0].albc_role_arn : null
}

output "task_api_irsa_role_arn" {
  description = "task-api 应用使用的 IRSA Role ARN"
  value       = var.create_eks ? module.task_api.irsa_role_arn : null
}

output "task_api_bucket_name" {
  description = "task-api 应用的 S3 桶名称"
  value       = module.task_api.bucket_name
}

output "task_api_bucket_arn" {
  description = "task-api 应用的 S3 桶 ARN"
  value       = module.task_api.bucket_arn
}

output "task_api_s3_prefix" {
  description = "task-api 应用使用的 S3 前缀"
  value       = module.task_api.s3_prefix
}

output "task_api_bucket_url" {
  description = "task-api 应用的 S3 URL"
  value       = module.task_api.bucket_url
}

output "task_api_bucket_policy_id" {
  description = "task-api 桶策略资源 ID"
  value       = module.task_api.bucket_policy_id
}

output "task_api_bucket_lifecycle_rules" {
  description = "task-api 桶生命周期规则及状态"
  value       = module.task_api.bucket_lifecycle_rules
}
