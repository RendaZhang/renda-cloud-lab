// ---------------------------
// NAT 网关及相关路由配置
// 允许私有子网通过 NAT 访问公网
// ---------------------------

resource "aws_eip" "nat" {
  count  = var.create ? 1 : 0 # 是否创建 EIP
  domain = "vpc"              # 绑定到 VPC
  tags = {
    Name = "lab-nat-eip" # EIP 资源标签
  }
}

resource "aws_nat_gateway" "this" {
  count         = var.create ? 1 : 0 # 是否创建 NAT 网关
  allocation_id = aws_eip.nat[0].id  # 关联的 EIP
  subnet_id     = var.public_subnet  # NAT 所在公有子网
  tags = {
    Name = "lab-nat" # NAT 网关标签
  }
}

resource "aws_route" "private_default" {
  count                  = var.create ? length(var.private_rtb_ids) : 0 # 为每个私有路由表创建默认路由
  route_table_id         = element(var.private_rtb_ids, count.index)    # 当前路由表 ID
  destination_cidr_block = "0.0.0.0/0"                                  # 默认路由
  nat_gateway_id         = aws_nat_gateway.this[0].id                   # 指向 NAT 网关
}
