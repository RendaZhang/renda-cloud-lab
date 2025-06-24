output "alb_dns" {
  value = try(aws_lb.demo[0].dns_name, null)
}

output "alb_zone_id" {
  value = try(aws_lb.demo[0].zone_id, null)
}