resource "aws_iam_role" "lambda_exec" {
  name = "${local.name_prefix}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_secret_access" {
  name = "${local.name_prefix}-lambda-secret-access"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_db_instance.postgres.master_user_secret[0].secret_arn
    }]
  })
}

resource "aws_lambda_function" "registrar_servicio" {
  function_name = "${local.name_prefix}-registrar-servicio"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.12"
  architectures = ["x86_64"]
  handler       = "lambda_function.lambda_handler"
  memory_size   = 256
  timeout       = 15

  filename         = "${path.module}/../build/registrar_servicio.zip"
  source_code_hash = filebase64sha256("${path.module}/../build/registrar_servicio.zip")

  environment {
    variables = {
      DB_HOST       = aws_db_instance.postgres.address
      DB_PORT       = tostring(aws_db_instance.postgres.port)
      DB_NAME       = aws_db_instance.postgres.db_name
      DB_SECRET_ARN = aws_db_instance.postgres.master_user_secret[0].secret_arn
    }
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.private_app_a.id,
      aws_subnet.private_app_b.id
    ]

    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy.lambda_secret_access
  ]
}

resource "aws_lambda_function" "consultar_servicio" {
  function_name = "${local.name_prefix}-consultar-servicio"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = "python3.12"
  architectures = ["x86_64"]
  handler       = "lambda_function.lambda_handler"
  memory_size   = 256
  timeout       = 15

  filename         = "${path.module}/../build/consultar_servicio.zip"
  source_code_hash = filebase64sha256("${path.module}/../build/consultar_servicio.zip")

  environment {
    variables = {
      DB_HOST       = aws_db_instance.postgres.address
      DB_PORT       = tostring(aws_db_instance.postgres.port)
      DB_NAME       = aws_db_instance.postgres.db_name
      DB_SECRET_ARN = aws_db_instance.postgres.master_user_secret[0].secret_arn
    }
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.private_app_a.id,
      aws_subnet.private_app_b.id
    ]

    security_group_ids = [aws_security_group.lambda.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy.lambda_secret_access
  ]
}
