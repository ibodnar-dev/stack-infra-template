# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    {
      "Name" = var.vpc_name
    },
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    }
  )
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    {
      "Name" = "${var.vpc_name}-igw"
    },
    var.tags
  )
}

# Public Subnets
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    {
      "Name" = "${var.vpc_name}-public-${var.availability_zones[count.index]}"
    },
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/elb"                    = "1"
    }
  )
}

# Private Subnets
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + length(var.availability_zones))
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    {
      "Name" = "${var.vpc_name}-private-${var.availability_zones[count.index]}"
    },
    var.tags,
    {
      "kubernetes.io/cluster/${var.cluster_name}" = "shared"
      "kubernetes.io/role/internal-elb"           = "1"
    }
  )
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count = var.create_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(
    {
      "Name" = "${var.vpc_name}-nat-eip"
    },
    var.tags
  )
}

# NAT Gateway
resource "aws_nat_gateway" "this" {
  count = var.create_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(
    {
      "Name" = "${var.vpc_name}-nat-gw"
    },
    var.tags
  )

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.this]
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    {
      "Name" = "${var.vpc_name}-public-rt"
    },
    var.tags
  )
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    {
      "Name" = "${var.vpc_name}-private-rt"
    },
    var.tags
  )
}

# Public Route
resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id

  timeouts {
    create = "5m"
  }
}

# Private Route to NAT Gateway (if enabled)
resource "aws_route" "private_nat_gateway" {
  count = var.create_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}

# Route Table Association - Public Subnets
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table Association - Private Subnets
resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security Group for VPC Endpoints (optional)
resource "aws_security_group" "vpc_endpoints" {
  count = var.create_vpc_endpoints ? 1 : 0

  name        = "${var.vpc_name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    {
      "Name" = "${var.vpc_name}-vpc-endpoints-sg"
    },
    var.tags
  )
}

# VPC Endpoints for EKS (if enabled)
resource "aws_vpc_endpoint" "s3" {
  count = var.create_vpc_endpoints ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id, aws_route_table.public.id]

  tags = merge(
    {
      "Name" = "${var.vpc_name}-s3-endpoint"
    },
    var.tags
  )
}

resource "aws_vpc_endpoint" "ecr_api" {
  count = var.create_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(
    {
      "Name" = "${var.vpc_name}-ecr-api-endpoint"
    },
    var.tags
  )
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  count = var.create_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(
    {
      "Name" = "${var.vpc_name}-ecr-dkr-endpoint"
    },
    var.tags
  )
}

resource "aws_vpc_endpoint" "logs" {
  count = var.create_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(
    {
      "Name" = "${var.vpc_name}-logs-endpoint"
    },
    var.tags
  )
}

resource "aws_vpc_endpoint" "sts" {
  count = var.create_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(
    {
      "Name" = "${var.vpc_name}-sts-endpoint"
    },
    var.tags
  )
}
