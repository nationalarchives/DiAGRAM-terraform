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
  gateway_route_key              = "POST /api/{proxy+}"
}