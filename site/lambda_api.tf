data "aws_ssm_parameter" "management_account" {
  name = "/mgmt/account_id"
}

# Create a role for lambda.amazonaws.com to assume when executing our Lambda
# function.
resource "aws_iam_role" "lambda" {
  name = local.lambda_iam_name

  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Action : "sts:AssumeRole",
        Principal : {
          Service : "lambda.amazonaws.com"
        },
        Effect : "Allow",
        Sid : ""
      }
    ]
  })
}

#Attach the AWSLambdaBasicExecutionRole to the role for Lambda execution
resource "aws_iam_role_policy_attachment" "iampol-lambdabasicexecution" {
  role       = aws_iam_role.lambda.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Create role for API Gateway to assume when accessing CloudWatch.
resource "aws_iam_role" "cloudwatch" {
  name = "api_gateway_cloudwatch_global"

  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Sid : "",
        Effect : "Allow",
        Principal : {
          Service : "apigateway.amazonaws.com"
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
}

# Attach role to policy, allowing API Gateway to create and steam logs in
# CloudWatch.
resource "aws_iam_role_policy" "cloudwatch" {
  name = "default"
  role = aws_iam_role.cloudwatch.id

  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ],
        Resource : "*"
      }
    ]
  })
}

# Create Lambda function from custom Lambda container image
resource "aws_lambda_function" "this" {
  function_name = local.lambda_function_name
  image_uri     = "${data.aws_ssm_parameter.management_account.value}.dkr.ecr.eu-west-2.amazonaws.com/diagram-backend-lambda-runtimes:${terraform.workspace}"
  memory_size   = local.lambda_memsize
  package_type  = local.lambda_package_type
  role          = aws_iam_role.lambda.arn
  timeout       = local.lambda_timeout
}

# Create API Gateway.
resource "aws_apigatewayv2_api" "lambda" {
  name          = local.gateway_name
  protocol_type = local.gateway_protocol
}

# Attach CloudWatch role to allow API GateWay to push logs there.
resource "aws_api_gateway_account" "lambda" {
  cloudwatch_role_arn = aws_iam_role.cloudwatch.arn
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/diagram-backend"
  retention_in_days = 7
}

# Create a log group in CloudWatch to store function execution logs in.
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "API-Gateway-Execution-Logs_${aws_apigatewayv2_api.lambda.id}/"
  retention_in_days = 7
}

# Attach stage to API Gateway
resource "aws_apigatewayv2_stage" "lambda" {
  depends_on  = [aws_cloudwatch_log_group.lambda]
  api_id      = aws_apigatewayv2_api.lambda.id
  name        = local.gateway_stage_name
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.lambda.arn
    # Set the format of the logs to record
    format = jsonencode({
      ip : "$context.identity.sourceIp",
      requestId : "$context.requestId",
      requestTime : "$context.requestTime",
      httpMethod : "$context.httpMethod",
      routeKey : "$context.routeKey",
      status : "$context.status",
      protocol : "$context.protocol",
      error : "$context.integrationErrorMessage"
    })
  }
  default_route_settings {
    detailed_metrics_enabled = local.gateway_stage_detailed_metrics
    throttling_burst_limit   = local.gateway_stage_burst_limit
    throttling_rate_limit    = local.gateway_stage_rate_limit
  }
}

# Add a Lambda integration to API Gateway.
resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.lambda.id
  integration_type   = local.gateway_integration_type
  integration_method = local.gateway_integration_method
  integration_uri    = aws_lambda_function.this.invoke_arn
}

# Route requests from API Gateway through to the Lambda Function.
resource "aws_apigatewayv2_route" "lambda-backend" {
  api_id    = aws_apigatewayv2_api.lambda.id
  route_key = local.gateway_route_key
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Allow Lambda to be executed from requests which come via API Gateway.
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}
