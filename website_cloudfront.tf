# TNA provided this certificate upon our request, importing it into the three
# development environments on our behalf.
# Note that SSL certificates for use with CloudFront _must_ be imported into
# the US East (N. Virginia) Region (us-east-1).
data "aws_acm_certificate" "wildcard" {
  domain   = local.service[terraform.workspace].url
  statuses = ["ISSUED"]
  types    = ["AMAZON_ISSUED"]
  provider = aws.us-east-1
}

resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "website"
  description                       = "S3 Website"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# HTTP security headers
resource "aws_cloudfront_response_headers_policy" "diagram" {
  name = "security-headers"

  custom_headers_config {
    items {
      header   = "X-Permitted-Cross-Domain-Policies"
      override = true
      value    = "none"
    }

    items {
      header   = "Cache-Control"
      override = true
      value    = "no-cache"
    }
  }

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      override     = true
      frame_option = "SAMEORIGIN"
    }

    strict_transport_security {
      override                   = true
      access_control_max_age_sec = 31536000
    }

    content_security_policy {
      content_security_policy = "default-src 'self' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; style-src 'self' https://fonts.googleapis.com 'unsafe-hashes' 'sha256-kFAIUwypIt04FgLyVU63Lcmp2AQimPh/TdYjy04Flxs=' 'sha256-2AMfKUIQeL5s2LTyEqbLB08wir4HW4qmUF8KGwRrHpU=' 'sha256-D/q/6FIu6/KApfXCg8WR5j4bB61MmNj2trZtp744lJs='; img-src 'self' blob:;"
      override                = true
    }
  }

}

# Create CloudFront distribution
resource "aws_cloudfront_distribution" "diagram" {
  aliases             = ["${local.service[terraform.workspace].url}"]
  enabled             = true
  default_root_object = "index.html"

  # Backend origin (API Gateway)
  origin {
    domain_name = trimsuffix(trimprefix(aws_apigatewayv2_stage.lambda.invoke_url, "https://"), "/")
    origin_id   = "${local.project_ns}-api_gw"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols = [
        "TLSv1.2",
      ]
    }
  }

  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.website.id
    viewer_protocol_policy = "redirect-to-https"
    # Allow all standard verbs
    allowed_methods = [
      "HEAD",
      "DELETE",
      "POST",
      "GET",
      "OPTIONS",
      "PUT",
      "PATCH"
    ]
    # Cache the trivial verbs
    cached_methods = [
      "HEAD",
      "GET"
    ]
    # Forward full request and any cookies
    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
    response_headers_policy_id = aws_cloudfront_response_headers_policy.diagram.id
  }

  # Forward requsts of /api/ to API Gateway
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "${local.project_ns}-api_gw"
    viewer_protocol_policy = "allow-all"
    # Allow all standard verbs
    allowed_methods = [
      "HEAD",
      "DELETE",
      "POST",
      "GET",
      "OPTIONS",
      "PUT",
      "PATCH"
    ]
    # Cache the trivial verbs
    cached_methods = [
      "HEAD",
      "GET"
    ]
    # Forward full request and any cookies
    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }
    response_headers_policy_id = aws_cloudfront_response_headers_policy.diagram.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
    origin_id                = aws_s3_bucket.website.id
  }

  # Attach SSL cerification
  viewer_certificate {
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
    acm_certificate_arn      = data.aws_acm_certificate.wildcard.arn
  }
}

locals {
  zone_prefix = terraform.workspace == "live" ? "" : "${terraform.workspace}-"
  zone_name   = "${local.zone_prefix}diagram.nationalarchives.gov.uk"
}

data "aws_route53_zone" "hosted_zone" {
  name = local.zone_name
}

# Create a record in route 53 for each tna zone
resource "aws_route53_record" "tna_records" {
  zone_id = data.aws_route53_zone.hosted_zone.id
  name    = local.zone_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.diagram.domain_name
    zone_id                = aws_cloudfront_distribution.diagram.hosted_zone_id
    evaluate_target_health = false
  }
}
