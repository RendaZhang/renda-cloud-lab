// 输出 ALB 的关键信息
output "alb_dns" {
  description = "ALB 的 DNS 名称"
  value       = try(aws_lb.demo[0].dns_name, null)
}

output "alb_zone_id" {
  description = "ALB 所在的 Hosted Zone ID"
  value       = try(aws_lb.demo[0].zone_id, null)
}
