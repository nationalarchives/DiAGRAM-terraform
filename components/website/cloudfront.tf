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

# Create CloudFront distribution
resource "aws_cloudfront_distribution" "diagram" {
  aliases = ["${var.service[local.workspace].url}"]
  enabled = true

  # Frontend origin (S3 bucket)
  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = "${local.project_ns}-site"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy   = "http-only"
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
  }

  # Forward requsts of /api/ to API Gateway
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id   = "${local.project_ns}-api_gw"
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