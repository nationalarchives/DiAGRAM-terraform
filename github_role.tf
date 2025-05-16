data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "gha_policy" {
  name = "Policy_Diagram_GitHub_OICD"
  role = aws_iam_role.gha_role.id
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

resource "aws_iam_role" "gha_role" {
  name = "Role_Diagram_GitHub_OICD"

  assume_role_policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        "Action" : "sts:AssumeRole"
      },
      {
        "Effect" = "Allow",
        "Principal" = {
          "Federated" = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        },
        "Action" = "sts:AssumeRoleWithWebIdentity",
        "Condition" = {
          "StringEquals" = {
            "token.actions.githubusercontent.com:sub" = "repo:nationalarchives/DiAGRAM:environment:${terraform.workspace}",
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}
