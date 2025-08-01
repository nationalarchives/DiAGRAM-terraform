locals {
  zone_prefix = terraform.workspace == "live" ? "" : "${terraform.workspace}-"
  zone_name   = "${local.zone_prefix}diagram.nationalarchives.gov.uk"
}

resource "aws_route53_zone" "hosted_zone" {
  name = local.zone_name
}

module "site" {
  source           = "./site"
  hosted_zone_id   = aws_route53_zone.hosted_zone.id
  hosted_zone_name = local.zone_name
  created_by       = local.created_by
}
