# Recommend that the terraform backend is an s3 bucket: https://www.terraform.io/language/settings/backends/s3
# The s3 bucket and dynamo DB table will need to be created manually, or using Terraform in a separate repository (bootstrap)
terraform {
  backend "s3" {
    bucket         = "diagram-terraform-state" # this should be set to the s3 bucket to be used to store the Terraform state
    key            = "terraform.state"
    region         = "eu-west-2"
    encrypt        = true
    dynamodb_table = "diagram-terraform-state-lock" # this should be set to the dynamoDb table used to control the state lock
  }
}
