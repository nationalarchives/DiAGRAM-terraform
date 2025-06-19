provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = terraform.workspace
      CreatedBy   = var.created_by
    }
  }
}