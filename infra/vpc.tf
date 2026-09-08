
# Create a VPC
resource "aws_vpc" "gamehub" {
  cidr_block = "10.0.0.0/16"
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
