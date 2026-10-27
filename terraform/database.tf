resource "aws_db_subnet_group" "servitech" {
  name = "${local.name_prefix}-db-subnet-group"

  subnet_ids = [
    aws_subnet.private_data_a.id,
    aws_subnet.private_data_b.id
  ]

  tags = {
    Name = "${local.name_prefix}-db-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "${local.name_prefix}-postgres"

  # RDS selects the current default PostgreSQL version for this region.
  engine         = "postgres"
  instance_class = "db.t4g.micro"
  db_name        = "servitech"
  port           = 5432

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  username                    = "servitech_admin"
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.servitech.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period   = 7
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.name_prefix}-postgres-final"

  tags = {
    Name = "${local.name_prefix}-postgres"
  }
}
