module "tna_zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "~> 2.0"

  zones = {
    "${var.service[local.workspace].url}" = {
      comment = "${var.service[local.workspace].url} (${terraform.workspace})"
    }
  }
}

# Create a record in route 53 for each tna zone
resource "aws_route53_record" "tna_records" {
  zone_id = module.tna_zones.route53_zone_zone_id[keys(module.tna_zones.route53_zone_zone_id)[0]]
  name    = keys(module.tna_zones.route53_zone_zone_id)[0]
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.diagram.domain_name
    zone_id                = aws_cloudfront_distribution.diagram.hosted_zone_id
    evaluate_target_health = false
  }

  depends_on = [module.tna_zones]
}
