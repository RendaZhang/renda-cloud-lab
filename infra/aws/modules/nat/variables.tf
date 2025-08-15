variable "create" {
  description = "是否创建 NAT 网关"
  type        = bool
}

variable "public_subnet" {
  description = "NAT 网关所在的公有子网 ID"
  type        = string
}

variable "private_rtb_ids" {
  description = "需要指向 NAT 的私有路由表 ID 列表"
  type        = list(string)
}
