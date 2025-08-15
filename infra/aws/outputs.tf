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

output "autoscaler_role_arn" {
  description = "EKS Cluster Autoscaler 使用的 IAM 角色 ARN"
  value       = var.create_eks ? module.irsa[0].autoscaler_role_arn : null
}
