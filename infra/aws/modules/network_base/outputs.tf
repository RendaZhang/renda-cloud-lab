// 输出网络相关资源信息，供其他模块使用
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "公有子网 ID 列表"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "私有子网 ID 列表"
  value       = aws_subnet.private[*].id
}

output "private_route_table_ids" {
  description = "私有路由表 ID 列表"
  value       = aws_route_table.private[*].id
}

output "s3_gateway_endpoint_id" {
  description = "S3 网关端点 ID"
  value       = aws_vpc_endpoint.s3.id
}
