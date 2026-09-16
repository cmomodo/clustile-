terraform {
  backend "s3" {
    bucket       = "my-27-state-bucket"
    key          = "gamehub/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
