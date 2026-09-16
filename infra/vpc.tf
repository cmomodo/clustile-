
# Create a VPC
resource "aws_vpc" "gamehub" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_subnet" "public" {
  for_each = {
    a = { az = "us-east-1a", cidr = "10.0.0.0/24" }
    b = { az = "us-east-1b", cidr = "10.0.1.0/24" }
    c = { az = "us-east-1c", cidr = "10.0.2.0/24" }
  }

  vpc_id                  = aws_vpc.gamehub.id
  availability_zone       = each.value.az
  cidr_block              = each.value.cidr
  map_public_ip_on_launch = true


  tags = {
    Name                     = "gamehub-public-${each.key}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_subnet" "private" {
  for_each = {
    a = { az = "us-east-1a", cidr = "10.0.16.0/20" }
    b = { az = "us-east-1b", cidr = "10.0.32.0/20" }
    c = { az = "us-east-1c", cidr = "10.0.48.0/20" }
  }

  vpc_id            = aws_vpc.gamehub.id
  availability_zone = each.value.az
  cidr_block        = each.value.cidr

  tags = {
    Name                              = "gamehub-private-${each.key}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

# Internet Gateway for public subnets
resource "aws_internet_gateway" "gamehub" {
  vpc_id = aws_vpc.gamehub.id

  tags = {
    Name = "gamehub-igw"
  }
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "gamehub-eip"
  }

  depends_on = [aws_internet_gateway.gamehub]
}

# Single NAT Gateway in public subnet (us-east-1a)
resource "aws_nat_gateway" "gamehub" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["a"].id

  tags = {
    Name = "gamehub-nat"
  }

  depends_on = [aws_internet_gateway.gamehub]
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.gamehub.id

  route {
    cidr_block      = "0.0.0.0/0"
    gateway_id      = aws_internet_gateway.gamehub.id
  }

  tags = {
    Name = "gamehub-public-rt"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.gamehub.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gamehub.id
  }

  tags = {
    Name = "gamehub-private-rt"
  }
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# Security group for EKS nodes
resource "aws_security_group" "node" {
  name   = "gamehub-node-sg"
  vpc_id = aws_vpc.gamehub.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow HTTP from VPC"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Allow HTTPS from VPC"
  }

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
    description = "Allow all TCP from nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "gamehub-node-sg"
  }
}
