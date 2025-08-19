resource "aws_subnet" "private-subnet" {
  count             = length(var.private-subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private-subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name                                      = "${var.project}-${var.environment}-private-subnet-${var.azs[count.index]}"
    "Kubernetes.io/role/internal-elb"       = "1"
    "Kubernetes.io/cluster/sprints-cluster" = "owned"
  }
}

resource "aws_subnet" "public-subnet" {
  count             = length(var.public-subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public-subnets[count.index]
  availability_zone = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                      = "${var.project}-${var.environment}-public-subnet-${var.azs[count.index]}"
    "Kubernetes.io/role/elb"                = "1"
   "Kubernetes.io/cluster/sprints-cluster" = "owned"
  }
}
