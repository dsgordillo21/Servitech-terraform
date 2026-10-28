variable "aws_region" {
  description = "Region principal donde se desplegara ServiTech"
  type        = string
  default     = "us-east-2"
}

variable "aws_profile" {
  description = "Perfil local de AWS CLI utilizado para ServiTech"
  type        = string
  default     = "servitech"
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
  default     = "servitech"
}