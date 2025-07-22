variable "hosted_zone_id" {}

variable "hosted_zone_name" {}

variable "created_by" {}

variable "project" {
  description = "abbreviation for the project, e.g. dr2, forms the first part of resource names"
  default     = "dr2"
}