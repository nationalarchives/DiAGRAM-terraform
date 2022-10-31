terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.29"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  region     = var.region
  access_key = var.secrets.tna_aws_access_key
  secret_key = var.secrets.tna_aws_secret_key

  assume_role {
    role_arn = "arn:aws:iam::${var.secrets.service[local.workspace].account}:role/IAM_Admin_Role"
  }

  default_tags {
    tags = {
      Project     = "${var.client_id}-${var.project_id}"
      Client      = "${var.client_id}"
      Environment = "${terraform.workspace}"
    }
  }
}
