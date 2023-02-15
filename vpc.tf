data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_availability_zone" "az" {
  count = length(data.aws_availability_zones.available.names)
  name  = data.aws_availability_zones.available.names[count.index]
}

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    Name = "afet"
  }
}

resource "aws_service_discovery_private_dns_namespace" "sd" {
  name = "afet.local"
  vpc  = aws_vpc.vpc.id

  tags = {
    Name = "afet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "igw"
  }
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zone.az[count.index].name
  map_public_ip_on_launch = true
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)

  tags = {
    Name = "public-${data.aws_availability_zone.az[count.index].name_suffix}"
  }
}

resource "aws_subnet" "private" {
  count = 2

  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zone.az[count.index].name
  map_public_ip_on_launch = false
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index + 2)

  tags = {
    Name = "private-${data.aws_availability_zone.az[count.index].name_suffix}"
  }
}

resource "aws_eip" "nat" {
  count      = 2
  vpc        = true
  depends_on = [aws_internet_gateway.gw]

  tags = {
    Name = "nat-gw-${data.aws_availability_zone.az[count.index].name_suffix}"
  }
}

resource "aws_nat_gateway" "ngw" {
  count = 2

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "nat-gw-${data.aws_availability_zone.az[count.index].name_suffix}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "public"
  }
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "private-${data.aws_availability_zone.az[count.index].name_suffix}"
  }
}

resource "aws_route" "private" {
  count                  = 2
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.ngw[count.index].id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = aws_route_table.private[*].id
}
