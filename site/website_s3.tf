# Define the S3 bucket to hold the static site frontend in
resource "aws_s3_bucket" "website" {
  bucket = "${local.project_ns}-site"
}

# Attach GetObject action to S3 bucket.
resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PublicReadGetObject"
        Effect = "Allow"
        Principal = {
          "Service" : "cloudfront.amazonaws.com"
        },
        Action = "s3:GetObject"
        Resource = [
          aws_s3_bucket.website.arn,
          "${aws_s3_bucket.website.arn}/*",
        ]
        Condition = {
          "StringEquals" : {
            "AWS:SourceArn" : aws_cloudfront_distribution.diagram.arn
          }
        }
      }
    ]
  })
}

//Block public access
resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
