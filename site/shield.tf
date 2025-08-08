locals {
  general_notifications_channel_id = local.environment == "live" ? "C06E20AR65V" : "C068RLCPZFE"
}

resource "aws_shield_protection" "shield_protection" {
  for_each     = toset(["arn:aws:route53:::hostedzone/${var.hosted_zone_id}", aws_cloudfront_distribution.diagram.arn])
  name         = "DIAGRAMShieldProtection"
  resource_arn = each.value
}

module "shield_response_team_role" {
  source             = "git::https://github.com/nationalarchives/da-terraform-modules//iam_role"
  assume_role_policy = templatefile("${path.module}/templates/iam_role/shield_response_assume_role.json.tpl", {})
  name               = "${local.environment}-shield-team-response-role"
  policy_attachments = {
    access_policy = "arn:aws:iam::aws:policy/service-role/AWSShieldDRTAccessPolicy"
  }
  tags = {}
}

module "shield_response_s3_bucket" {
  source            = "git::https://github.com/nationalarchives/da-terraform-modules//s3"
  common_tags       = local.common_tags
  bucket_name       = "${local.environment}-diagram-shield-response"
  create_log_bucket = false

}

module "cloudwatch_event_alarm_event_bridge_rule_alarm_only" {
  source = "git::https://github.com/nationalarchives/da-terraform-modules//eventbridge_api_destination_rule"
  event_pattern = templatefile("${path.module}/templates/eventbridge/cloudwatch_alarm_event_pattern.json.tpl", {
    cloudwatch_alarms = jsonencode([module.shield_cloudwatch_rules["s3_bucket"].cloudwatch_alarm_arn, module.shield_cloudwatch_rules["cloudfront"].cloudwatch_alarm_arn]),
    state_value       = "ALARM"
  })
  name                = "${local.environment}-dr2-eventbridge-alarm-state-change-alarm-only"
  api_destination_arn = var.api_destination_arn
  api_destination_input_transformer = {
    input_paths = {
      "alarmName"    = "$.detail.alarmName",
      "currentValue" = "$.detail.state.value"
    }
    input_template = templatefile("${path.module}/templates/eventbridge/slack_message_input_template.json.tpl", {
      channel_id   = local.general_notifications_channel_id
      slackMessage = ":warning: Cloudwatch alarm <alarmName> has entered state <currentValue>"
    })
  }
}

module "shield_cloudwatch_rules" {
  for_each = {
    s3_bucket  = aws_s3_bucket.website.arn,
    cloudfront = aws_iam_role.cloudwatch.arn,
  }
  source              = "git::https://github.com/nationalarchives/da-terraform-modules//cloudwatch_alarms"
  name                = "shield-metric-${each.key}"
  metric_name         = "DDoSDetected"
  threshold           = 1
  dimensions          = { "ResourceArn" = each.value }
  statistic           = "Sum"
  namespace           = "AWS/DDoSProtection"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  datapoints_to_alarm = 1
  evaluation_period   = 20
}