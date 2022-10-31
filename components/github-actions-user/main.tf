# Create an IAM group to attach a policy to, and add a CI user to.
resource "aws_iam_group" "gha_group" {
  name = "gha_group"
  path = "/gha_group/"
}

# Attach a policy to the group which gives the minimum set of permissions
# required for the aws commands in the application repo's GitHub workflows.
resource "aws_iam_group_policy" "gha_policy" {
  name  = "gha_policy"
  group = aws_iam_group.gha_group.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "lambda:GetFunction",
          "lambda:UpdateFunctionCode",
          "lambda:GetFunctionConfiguration",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
      }
    ]
  })
}

# Create the GitHub Actions CI user.
resource "aws_iam_user" "gha_user" {
  name = "${local.project_ns}-gha_user"
  path = "/gha_user/"
}

# Add the GitHub Actions CI user to the GitHub Actions group.
resource "aws_iam_user_group_membership" "gha_group" {
  user = aws_iam_user.gha_user.name
  groups = [
    aws_iam_group.gha_group.name,
  ]
}

# Generate an access key ID and secret, to be inserted into the application
# repo's GitHub Environment secrets, for usage by its GitHub Actions workflows.
resource "aws_iam_access_key" "gha_user" {
  user = aws_iam_user.gha_user.name
}

# Store the access key ID to be retrieved later.
output "gha_access_key_id" {
  sensitive = true
  value     = aws_iam_access_key.gha_user.id
}

# Store the access key secret to be retrieved later.
output "gha_access_key_secret" {
  sensitive = true
  value     = aws_iam_access_key.gha_user.secret
}
