terraform {
  backend "s3" {
    endpoint             = "s3.amazonaws.com"
    key                  = "container-registry.tfstate"
    workspace_key_prefix = "nata/dia3"
    bucket               = "jr-terraform-states"
    region               = "us-east-1"
    encrypt              = true
  }
}
