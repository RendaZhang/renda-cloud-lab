output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "private_route_table_ids" {
  value = aws_route_table.private[*].id
}

output "alb_sg_id" {
  value = aws_security_group.alb.id
}

output "alb_zone_id" { # 占位，alb 模块运行后再输出真实 Zone
  value = aws_vpc.this.id
}

output "hosted_zone_id" {
  value = data.aws_route53_zone.lab.zone_id
}