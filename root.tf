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
  athena_log_bucket_id = aws_s3_bucket.athena_results.id
  athena_log_bucket_name = aws_s3_bucket.athena_results.bucket
}

resource "aws_s3_bucket" "athena_results" {
  bucket        = "${terraform.workspace}-diagram-logs-athena-output-bucket"
}