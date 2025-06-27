output "alb_dns" {
  value = module.alb.alb_dns
}

output "vpc_id" {
  description = "VPC ID created by network_base"
  value       = module.network_base.vpc_id
}

output "public_subnet_ids" {
  value = module.network_base.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.network_base.private_subnet_ids
}

output "autoscaler_role_arn" {
  description = "IAM Role ARN for the EKS Cluster Autoscaler"
  value       = module.irsa.autoscaler_role_arn
}