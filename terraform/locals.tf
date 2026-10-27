locals {
  environment = terraform.workspace
  name_prefix = "${var.project_name}-${local.environment}"
}