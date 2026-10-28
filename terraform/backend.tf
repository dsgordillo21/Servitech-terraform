terraform {
  backend "s3" {
    key          = "lab09/dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}