# ============================================================
# SECURITY GROUP - LAMBDAS DEL MVP
# ============================================================

resource "aws_security_group" "lambda" {
  name        = "${local.name_prefix}-lambda-sg"
  description = "Security Group para las funciones Lambda del MVP"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-lambda-sg"
  }
}

# Las Lambdas pueden iniciar conexiones hacia otros recursos.
resource "aws_vpc_security_group_egress_rule" "lambda_all" {
  security_group_id = aws_security_group.lambda.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# ============================================================
# SECURITY GROUP - POSTGRESQL
# ============================================================

resource "aws_security_group" "rds" {
  name        = "${local.name_prefix}-rds-sg"
  description = "Security Group para PostgreSQL del MVP"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-rds-sg"
  }
}

# PostgreSQL solamente acepta conexiones desde las Lambdas.
resource "aws_vpc_security_group_ingress_rule" "rds_from_lambda" {
  security_group_id = aws_security_group.rds.id

  referenced_security_group_id = aws_security_group.lambda.id

  from_port   = 5432
  to_port     = 5432
  ip_protocol = "tcp"
}

# ============================================================
# SECURITY GROUP - VPC ENDPOINT SECRETS MANAGER
# ============================================================

resource "aws_security_group" "secrets_endpoint" {
  name        = "${local.name_prefix}-secrets-endpoint-sg"
  description = "Security Group para el VPC Endpoint de Secrets Manager"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-secrets-endpoint-sg"
  }
}

# El endpoint acepta HTTPS solamente desde las Lambdas.
resource "aws_vpc_security_group_ingress_rule" "secrets_from_lambda" {
  security_group_id = aws_security_group.secrets_endpoint.id

  referenced_security_group_id = aws_security_group.lambda.id

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}