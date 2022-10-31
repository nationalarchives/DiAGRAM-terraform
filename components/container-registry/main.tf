# Create a container repository to store the application backend's custom
# Lambda container image.
resource "aws_ecr_repository" "this" {
  name                 = var.ecr_repo_name
  image_tag_mutability = var.ecr_image_tag_mutability
}

# Attach a policy to the container repository, allowing basic actions to be
# performed upon it by Lambda.
resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    Version : "2008-10-17",
    Statement : [
      {
        Sid : "New Policy",
        Effect : "Allow",
        Principal : {
          Service : "lambda.amazonaws.com"
        },
        Action : [
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:DeleteRepositoryPolicy",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:SetRepositoryPolicy"
        ]
      }
    ]
  })
}

# This value is used by the lambda-api module later.
output "ecr_repo_url" {
  sensitive = true
  value     = aws_ecr_repository.this.repository_url
}
