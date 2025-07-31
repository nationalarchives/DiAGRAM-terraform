terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.0.0"
    }
  }
}
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


# Create a record in route 53 for each tna zone
resource "aws_route53_record" "tna_records" {
  zone_id = var.hosted_zone_id
  name    = var.hosted_zone_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.diagram.domain_name
    zone_id                = aws_cloudfront_distribution.diagram.hosted_zone_id
    evaluate_target_health = false
  }
}

# S3 bucket for logging
resource "aws_s3_bucket" "cloudfront_logs" {
  bucket = "${terraform.workspace}-diagram-cloudfront-logs-bucket"
}

resource "aws_s3_bucket_policy" "cf_logs_policy" {
  bucket = aws_s3_bucket.cloudfront_logs.id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "cloudfront.amazonaws.com"
        },
        "Action": "s3:PutObject",
        "Resource":[
          aws_s3_bucket.cloudfront_logs.arn,
          "${aws_s3_bucket.cloudfront_logs.arn}/*",
        ]
        "Condition": {
          "StringEquals": {
            "AWS:SourceArn": aws_cloudfront_distribution.diagram.arn
          }
        }
      }
    ]
  })
}

resource "aws_athena_workgroup" "cloudfront" {
  name = "logs-workgroup"
  configuration {
    result_configuration {
      output_location = "s3://${var.athena_log_bucket_name}/"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_lifecycle" {
  bucket = var.athena_log_bucket_id
  rule {
    id     = "expire-old-results"
    status = "Enabled"

    expiration {
      days = 30 #delete anything older than 30 days
    }

    filter {
      prefix = "" #Apply filter to everything in the bucket
    }
  }
}

resource "aws_athena_database" "cloudfront_database" {
  bucket = var.athena_log_bucket_name
  name   = "cloudfront_logs_db"
}

resource "aws_athena_named_query" "create_table" {
  name        = "Create CloudFront Logs Table"
  description = "Create the Table using query"
  database    = aws_athena_database.cloudfront_database.name
  workgroup   = aws_athena_workgroup.cloudfront.name

  query = <<EOF
    CREATE EXTERNAL TABLE IF NOT EXISTS cloudfront_logs_db.cloudfront_logs (
      the_date DATE,
      time STRING,
      location STRING,
      bytes BIGINT,
      request_ip STRING,
      method STRING,
      host STRING,
      uri STRING,
      status INT,
      referrer STRING,
      user_agent STRING,
      query_string STRING,
      cookie STRING,
      result_type STRING,
      request_id STRING,
      host_header STRING,
      request_protocol STRING,
      request_bytes BIGINT,
      time_taken FLOAT,
      xforwarded_for STRING,
      ssl_protocol STRING,
      ssl_cipher STRING,
      response_result_type STRING,
      http_version STRING,
      fle_status STRING,
      fle_encrypted_fields INT,
      c_port INT,
      time_to_first_byte FLOAT,
      edge_detailed_result_type STRING,
      content_type STRING, content_len BIGINT,
      response_age STRING, request_host_header STRING,
      request_protocol_version STRING
      )
      ROW FORMAT SERDE 'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe'
      WITH SERDEPROPERTIES ('input.regex' = '([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)\\t([^ ]*)')
      STORED AS TEXTFILE
      LOCATION 's3://${aws_s3_bucket.cloudfront_logs.bucket}/'
      TBLPROPERTIES ('skip.header.line.count'='2');
  EOF
}

resource "null_resource" "execute_query" {
  provisioner "local-exec" {
    command = <<EOT
      aws athena start-query-execution --query-string "${replace(aws_athena_named_query.create_table.query, "\n", " ")}" --query-execution-context Database=${aws_athena_database.cloudfront_database.name} --work-group ${aws_athena_workgroup.cloudfront.name} --result-configuration OutputLocation=s3://${var.athena_log_bucket_name}/
    EOT
  }
  depends_on = [aws_athena_database.cloudfront_database, aws_athena_workgroup.cloudfront, aws_athena_named_query.create_table]
}
