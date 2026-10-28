output "frontend_url" {
  description = "URL HTTPS del frontend servido por CloudFront."
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "api_url" {
  description = "URL base de API Gateway, incluido el stage dev."
  value       = aws_api_gateway_stage.dev.invoke_url
}

output "database_endpoint" {
  description = "Endpoint tecnico de PostgreSQL (host:puerto), accesible desde la VPC."
  value       = aws_db_instance.postgres.endpoint
}

output "frontend_bucket" {
  description = "Nombre del bucket S3 privado del frontend."
  value       = aws_s3_bucket.frontend.bucket
}

output "aws_region" {
  description = "Region AWS configurada para el despliegue."
  value       = var.aws_region
}

output "environment" {
  description = "Workspace actual de Terraform."
  value       = terraform.workspace
}
