output "nat_gateway_id" {
  value = try(aws_nat_gateway.this[0].id, null)
}
