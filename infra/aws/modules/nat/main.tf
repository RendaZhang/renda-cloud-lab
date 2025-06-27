resource "aws_eip" "nat" {
  count  = var.create ? 1 : 0
  domain = "vpc"
  tags = {
    Name = "lab-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  count         = var.create ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = var.public_subnet
  tags = {
    Name = "lab-nat"
  }
}

resource "aws_route" "private_default" {
  count                  = var.create ? length(var.private_rtb_ids) : 0
  route_table_id         = element(var.private_rtb_ids, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}