# ============================================================
# VPC PRINCIPAL - SERVITECH
# ============================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

# ============================================================
# SUBREDES PRIVADAS DE APLICACIÓN
# Las funciones Lambda regionales podrán conectarse a la VPC
# mediante estas subredes distribuidas en dos AZ.
# ============================================================

resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${local.name_prefix}-private-app-a"
    Type = "Private-App"
  }
}

resource "aws_subnet" "private_app_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${local.name_prefix}-private-app-b"
    Type = "Private-App"
  }
}

# ============================================================
# SUBREDES PRIVADAS DE DATOS
# PostgreSQL Multi-AZ utilizará subredes distribuidas
# entre dos zonas de disponibilidad.
# ============================================================

resource "aws_subnet" "private_data_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${local.name_prefix}-private-data-a"
    Type = "Private-Data"
  }
}

resource "aws_subnet" "private_data_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "${var.aws_region}b"

  tags = {
    Name = "${local.name_prefix}-private-data-b"
    Type = "Private-Data"
  }
}

# ============================================================
# TABLA DE RUTAS PRIVADA
# ============================================================

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private_app_a" {
  subnet_id      = aws_subnet.private_app_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_app_b" {
  subnet_id      = aws_subnet.private_app_b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_data_a" {
  subnet_id      = aws_subnet.private_data_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_data_b" {
  subnet_id      = aws_subnet.private_data_b.id
  route_table_id = aws_route_table.private.id
}

# ============================================================
# VPC ENDPOINT - AWS SECRETS MANAGER
# Permite que las Lambdas privadas accedan a Secrets Manager
# sin utilizar NAT Gateway ni salida a Internet.
# ============================================================

resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [
    aws_subnet.private_app_a.id,
    aws_subnet.private_app_b.id
  ]

  security_group_ids = [
    aws_security_group.secrets_endpoint.id
  ]

  tags = {
    Name = "${local.name_prefix}-secrets-manager-endpoint"
  }
}