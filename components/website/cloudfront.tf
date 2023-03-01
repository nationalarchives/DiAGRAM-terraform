data "terraform_remote_state" "lambda-api" {
  backend   = "s3"
  workspace = local.workspace

  config = {
    endpoint             = "s3.amazonaws.com"
    key                  = "lambda-api.tfstate"
    workspace_key_prefix = "nata/dia3"
    bucket               = "jr-terraform-states"
    region               = "us-east-1"
    encrypt              = true
  }
}

# TNA provided this certificate upon our request, importing it into the three
# development environments on our behalf.
# Note that SSL certificates for use with CloudFront _must_ be imported into
# the US East (N. Virginia) Region (us-east-1).
data "aws_acm_certificate" "wildcard" {
  domain   = "*.nationalarchives.gov.uk"
  statuses = ["ISSUED"]
  types    = ["IMPORTED"]
  provider = aws.us-east-1
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
  aliases = ["${var.service[local.workspace].url}"]
  enabled = true
  # WAF only added to dev and staging for IP restrictions
  web_acl_id = local.has_waf ? aws_wafv2_web_acl.cloudfront[0].arn : null
  # Frontend origin (S3 bucket)
  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = "${local.project_ns}-site"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = [
        "TLSv1.2",
      ]
    }
  }

  # Backend origin (API Gateway)
  origin {
    domain_name = data.terraform_remote_state.lambda-api.outputs.api_gateway_invoke_url
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
    target_origin_id       = "${local.project_ns}-site"
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

  # Attach SSL cerification
  viewer_certificate {
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
    acm_certificate_arn      = data.aws_acm_certificate.wildcard.arn
  }
}

resource "aws_wafv2_ip_set" "allowed_ips" {
  # Only create for dev and staging (no WAF on live)
  count              = local.has_waf ? 1 : 0
  name               = "allowed_ips"
  description        = "IPs that can access the DiAGRAM frontend"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses = var.secrets.allowed_ips
  # WAF must use us-east-1 region when scope is CLOUDFRONT
  provider = aws.us-east-1
}

resource "aws_wafv2_web_acl" "cloudfront" {
  # Only create for dev and staging (no WAF on live)
  count = local.has_waf ? 1 : 0
  name  = "cloudfront_acl"
  scope = "CLOUDFRONT"

  custom_response_body {
    key = "access-denied"
    content = <<-EOT
    <html>
    <p>Sorry, you can&#39;t access this page!</p>

    <p>Did you mean to visit our production site, <a href='https://diagram.nationalarchives.gov.uk'>https://diagram.nationalarchives.gov.uk</a> ?</p>

    <p>If you&#39;re a DiAGRAM developer, you&#39;ll need to be connected to TNA&#39;s VPN to access the development and staging sites.</p>

    </html>
    EOT
    content_type = "TEXT_HTML"
  }

  # Block access by default
  default_action {
    block {
      custom_response {
        custom_response_body_key = "access-denied"
        response_code = "403"
      }
    }
  }

  # Allow IPs access in IP whitelist
  rule {
    name     = "allow_allowed_ips"
    priority = 1

    action {
      allow {}
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.allowed_ips[count.index].arn
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = false
      metric_name                = "friendly-rule-metric-name"
      sampled_requests_enabled   = false
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = false
    metric_name                = "friendly-rule-metric-name"
    sampled_requests_enabled   = false
  }

  # WAF must use us-east-1 region when scope is CLOUDFRONT
  provider = aws.us-east-1
}
