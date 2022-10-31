variable "secrets" {
  description = "This is a list of secret values to pull in, stuff like tenant ID, access key, secret key etc. These are defined in a file called 'secrets.auto.tfvars', so that they get autopulled into TF when it runs."
  sensitive   = true
}

variable "region" {
  description = "Region to create infrastructure in."
  type        = string
  default     = "eu-west-2"
}

variable "website_index_document" {
  description = "Amazon S3 returns this index document when requests are made to the root domain or any of the subfolders. Defaults to index.html"
  type        = string
  default     = "index.html"
}

variable "client_id" {
  description = "id of the client"
  type        = string
  default     = "nata"
}

variable "project_id" {
  description = "JR project part ID"
  type        = string
  default     = "dia3"
}

variable "service" {
  description = "Properties that vary between workspaces"
  default = {
    live = {
      suffix  = ""
      url     = "diagram.nationalarchives.gov.uk"
    }
    stage = {
      suffix  = "-staging"
      url     = "staging-diagram.nationalarchives.gov.uk"
    }
    dev = {
      suffix  = "-dev"
      url     = "dev-diagram.nationalarchives.gov.uk"
    }
  }
}

locals {
  project_ns = "${var.client_id}-${var.project_id}-${terraform.workspace}"
  workspace  = terraform.workspace
}

