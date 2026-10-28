resource "aws_cloudwatch_log_group" "registrar_servicio" {
  name              = "/aws/lambda/${aws_lambda_function.registrar_servicio.function_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "consultar_servicio" {
  name              = "/aws/lambda/${aws_lambda_function.consultar_servicio.function_name}"
  retention_in_days = 7
}
