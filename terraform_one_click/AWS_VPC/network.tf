data "aws_availability_zones" "available" {}

# Creating VPC

resource "aws_vpc" "vpc" {
  cidr_block           = "172.20.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "${var.env}-vpc-${var.project}"
  }
}

# Creating Public Subnets
resource "aws_subnet" "public_subnet" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "172.20.${1 + count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.env}-Public-Subnet-${1 + count.index}-${var.project}"
  }
}

#Creating private Subnets
resource "aws_subnet" "private_subnet" {
  count                   = length(data.aws_availability_zones.available.names)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "172.20.${11 + count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.env}-Private-Subnet-${1 + count.index}-${var.project}"
  }
}

# Creater IGW 
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.env}-IGW-${var.project}"
  }
}

# Creater Public route Table
resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }


  tags = {
    Name = "${var.env}-Public-Route_Table-${var.project}"
  }
}

# Create Nat gateway EIP
resource "aws_eip" "nat-ip" {
  vpc = true
 
 tags = {
    Name = "${var.env}-NAT-EIP-${var.project}"
  }
}



# Create Nat gateway

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat-ip.id
  subnet_id     = aws_subnet.public_subnet[0].id

  tags = {
    Name = "${var.env}-NAT-Gateway-${var.project}"
  }
  depends_on = [aws_internet_gateway.igw]
}

# Create private Route
resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }


  tags = {
    Name = "${var.env}-Private-Route_Table-${var.project}"
  }
}

resource "aws_route_table_association" "a" {
  count          = length(data.aws_availability_zones.available)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "b" {
  count          = length(data.aws_availability_zones.available)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private-rt.id
}
