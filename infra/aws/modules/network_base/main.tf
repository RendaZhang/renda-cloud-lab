// ---------------------------
// 网络基础模块：创建 VPC、子网、路由表及 ALB 安全组等资源
// ---------------------------

data "aws_availability_zones" "available" {} # 查询可用区

resource "aws_vpc" "this" {
  cidr_block           = "10.0.0.0/16" # VPC 网段
  enable_dns_hostnames = true          # 启用 DNS 主机名
  tags = {
    Name = "dev-vpc"
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
    Name = "dev-public-${count.index}"
  }
}

# 2 个 private 子网
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(aws_vpc.this.cidr_block, 4, count.index + 8) # 10.0.128.0/20, 10.0.144.0/20
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "dev-private-${count.index}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "dev-igw"
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

# 安全组专供 ALB
resource "aws_security_group" "alb" {
  name   = "alb-demo-sg"
  vpc_id = aws_vpc.this.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_route53_zone" "lab" {
  name = "lab.rendazhang.com" # TODO: 根据实际域名修改
}
