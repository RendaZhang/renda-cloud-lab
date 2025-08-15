// NAT 网关 ID，供其他模块引用
output "nat_gateway_id" {
  description = "ID of the created NAT Gateway"
  value       = try(aws_nat_gateway.this[0].id, null)
}
