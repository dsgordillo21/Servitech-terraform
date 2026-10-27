terraform {
  backend "s3" {
    bucket       = "servitech-tfstate-694188424284"
    key          = "servitech/terraform.tfstate"
    region       = "us-east-1"
    profile      = "servitech"
    encrypt      = true
    use_lockfile = true
  }
}