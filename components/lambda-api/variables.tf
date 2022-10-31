variable "secrets" {
  description = "This is a list of secret values to pull in, stuff like tenant ID, access key, secret key etc. These are defined in a file called 'secrets.auto.tfvars', so that they get autopulled into TF when it runs."
  sensitive   = true
}

variable "client_id" {
  description = "ID of the client"
  type        = string
  default     = "nata"
}

variable "project_id" {
  description = "JR project part ID"
  type        = string
  default     = "dia3"
}

variable "region" {
  description = "Region to create infrastructure in."
  type        = string
  default     = "eu-west-2"
}

variable "lambda_iam_name" {
  description = "Name to give IAM role applied to lambda."
  type        = string
  default     = "lambda-iam"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function."
  type        = string
  default     = "diagram-backend"
}

variable "lambda_timeout" {
  description = "The amount of time, in seconds, which the Lambda function is allowed to run."
  type        = number
  default     = 60
}

variable "lambda_memsize" {
  description = "Amount of memory, in Mb, which the Lambda function is allowed to use."
  type        = number
  default     = 5120
}

variable "lambda_package_type" {
  description = "Lambda deployment package type. Must be one of: `Zip` or `Image`."
  type        = string
  default     = "Image"
}

variable "gateway_name" {
  description = "Name to give the API Gateway."
  type        = string
  default     = "diagram-backend-gateway"
}

variable "gateway_protocol" {
  description = "Protocol used by API Gateway."
  type        = string
  default     = "HTTP"
}

variable "gateway_stage_name" {
  description = "Name of the 'gateway stage'. Must be between 1 and 128 characters in length."
  type        = string
  default     = "$default"
}

variable "gateway_stage_logging_level" {
  description = "The logging level for the default route. Affects the log entries pushed to Amazon CloudWatch Logs. Valid values: ERROR, INFO, OFF. Defaults to OFF. Supported only for WebSocket APIs. Terraform will only perform drift detection of its value when present in a configuration."
  type        = string
  default     = "INFO"
}

variable "gateway_stage_detailed_metrics" {
  description = "Whether detailed metrics are enabled for the default route."
  type        = bool
  default     = true
}

variable "gateway_stage_burst_limit" {
  description = "The throttling burst limit for the default route."
  type        = number
  default     = 5000
}

variable "gateway_stage_rate_limit" {
  description = "The throttling rate limit for the default route."
  type        = number
  default     = 1000
}

variable "gateway_integration_type" {
  description = "The integration type of an integration. Valid values: AWS (supported only for WebSocket APIs), AWS_PROXY, HTTP (supported only for WebSocket APIs), HTTP_PROXY, MOCK (supported only for WebSocket APIs). For an HTTP API private integration, use HTTP_PROXY."
  type        = string
  default     = "AWS_PROXY"
}

variable "gateway_integration_method" {
  description = "The integration's HTTP method. Must be specified if integration_type is not MOCK"
  type        = string
  default     = "POST"
}

variable "gateway_route_key" {
  description = "The route key for the route. For HTTP APIs, the route key can be either $default, or a combination of an HTTP method and resource path, for example, GET /pets."
  type        = string
  default     = "POST /api/{proxy+}"
}

locals {
  workspace = terraform.workspace
}
