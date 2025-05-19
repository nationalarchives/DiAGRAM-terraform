terraform {
  backend "s3" {
    bucket       = "mgmt-diagram-terraform-state"
    key          = "terraform.state"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}
provider "aws" {
  region = "eu-west-2"
  default_tags {
    tags = {
      Environment = terraform.workspace
      CreatedBy   = local.created_by
    }
  }
}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = terraform.workspace
      CreatedBy   = local.created_by
    }
  }
}
