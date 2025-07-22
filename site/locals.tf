locals {
  service = {
    live = {
      suffix = ""
      url    = "diagram.nationalarchives.gov.uk"
    }
    dev = {
      suffix = "-dev"
      url    = "dev-diagram.nationalarchives.gov.uk"
    }
  }
  project_ns                     = "nata-dia3-${terraform.workspace}"
  lambda_iam_name                = "lambda-iam"
  lambda_function_name           = "diagram-backend"
  lambda_timeout                 = 60
  lambda_memsize                 = 5120
  lambda_package_type            = "Image"
  gateway_name                   = "diagram-backend-gateway"
  gateway_protocol               = "HTTP"
  gateway_stage_name             = "$default"
  gateway_stage_detailed_metrics = true
  gateway_stage_burst_limit      = 5000
  gateway_stage_rate_limit       = 1000
  gateway_integration_type       = "AWS_PROXY"
  gateway_integration_method     = "POST"
  gateway_endpoints              = toset(["test/is_alive", "model/score", "chart/plot", "report/pdf", "report/csv", "validation/validate_json"])

  environment = terraform.workspace
  common_tags = tomap(
    {
      "Environment"     = local.environment,
      "Owner"           = "DR2",
      "Terraform"       = true,
      "TerraformSource" = "https://github.com/nationalarchives/DiAGRAM-terraform"
    }
  )

  aws_back_up_service_role   = local.environment == "live" ? module.aws_backup_configuration.terraform_config["aws_service_backup_role"] : ""
  aws_back_up_local_role     = local.environment == "live" ? "arn:aws:iam::${var.dr2_account_number}:role/${local.aws_backup_local_role_name}" : ""
  aws_backup_local_role_name = module.aws_backup_configuration.terraform_config["local_account_backup_role_name"]

}