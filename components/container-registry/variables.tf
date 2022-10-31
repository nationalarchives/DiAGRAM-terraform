variable "secrets" {
  description = "This is a list of secret values to pull in, stuff like tenant ID, access key, secret key etc. These are defined in a file called 'secrets.auto.tfvars', so that they get autopulled into TF when it runs."
  sensitive   = true
}

variable "client_id" {
  description = "ID of the client"
  type        = string
  default     = "nata"
}

variable "project_id" {
  description = "JR project part ID"
  type        = string
  default     = "dia3"
}

variable "region" {
  description = "Region to create infrastructure in."
  type        = string
  default     = "eu-west-2"
}

variable "ecr_repo_name" {
  description = "Name of the elastic container registry repository."
  type        = string
  default     = "diagram-backend-lambda-runtimes"
}

variable "ecr_image_tag_mutability" {
  description = "The tag mutability setting for the repository. Must be one of: `MUTABLE` or `IMMUTABLE`."
  type        = string
  default     = "MUTABLE"
}

locals {
  workspace = terraform.workspace
}
