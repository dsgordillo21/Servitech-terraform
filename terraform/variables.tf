variable "aws_region" {
  description = "Region principal donde se desplegara ServiTech"
  type        = string
  default     = "us-east-2"
}

variable "aws_profile" {
  description = "Perfil AWS opcional; null permite usar AWS_PROFILE o credenciales temporales de OIDC"
  type        = string
  default     = null
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "servitech"
}
