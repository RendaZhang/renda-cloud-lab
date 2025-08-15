variable "create" {
  description = "是否创建 ALB 相关资源"
  type        = bool
}

variable "public_subnet_ids" {
  description = "ALB 部署的公有子网 ID 列表"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ALB 使用的安全组 ID"
  type        = string
}

variable "vpc_id" {
  description = "ALB 所属的 VPC ID"
  type        = string
}
