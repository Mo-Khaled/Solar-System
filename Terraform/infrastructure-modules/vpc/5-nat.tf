resource "aws_eip" "eip" {
  domain = "vpc"
  tags = {
    Name = "${var.project}-${var.environment}_nat_eip"
  }

}

resource "aws_nat_gateway" "nat" {

  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public-subnet[0].id

  tags = {
    Name = "${var.project}-${var.environment}_nat"
  }

  depends_on = [aws_internet_gateway.igw]
}
