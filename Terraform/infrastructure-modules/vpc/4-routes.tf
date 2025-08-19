resource "aws_route_table" "sprints_rt_public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project}-${var.environment}_rt_public"
  }
}

resource "aws_route_table" "sprints_rt_private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.project}-${var.environment}_rt_private"
  }
}

resource "aws_route_table_association" "public_subnet_ta" {
  count          = length(var.public-subnets)
  subnet_id      = aws_subnet.public-subnet[count.index].id
  route_table_id = aws_route_table.sprints_rt_public.id
}


resource "aws_route_table_association" "private_subnet_ta" {
  count          = length(var.private-subnets)
  subnet_id      = aws_subnet.private-subnet[count.index].id
  route_table_id = aws_route_table.sprints_rt_private.id
}
