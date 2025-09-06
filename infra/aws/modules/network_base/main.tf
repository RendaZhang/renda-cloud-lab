// ---------------------------
// 网络基础模块：创建 VPC、子网、路由表等资源
// ---------------------------

data "aws_availability_zones" "available" {} # 查询可用区
data "aws_region" "current" {}               # 当前区域，用于 VPC Endpoint（使用 id 字段）

resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16" # VPC 网段
  enable_dns_hostnames = true          # 启用 DNS 主机名
  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

# 2 个 public 子网
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(aws_vpc.this.cidr_block, 4, count.index) # 10.0.0.0/20, 10.0.16.0/20
  map_public_ip_on_launch = true                                                # 实例启动分配公网 IP
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name                                        = "${var.cluster_name}-public-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

# 2 个 private 子网
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 4, count.index + 8) # 10.0.128.0/20, 10.0.144.0/20
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name                                        = "${var.cluster_name}-private-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0" # 指向公网
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "rtb-public"
  }
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "rtb-private-${count.index}"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# S3 Gateway Endpoint：私有子网直连 S3，绕过 NAT 以节省成本
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id # 仅关联私有路由表

  tags = {
    Name        = "${var.cluster_name}-s3-endpoint"
    ManagedBy   = "Terraform"
    Description = "Gateway endpoint for S3"
  }
}
