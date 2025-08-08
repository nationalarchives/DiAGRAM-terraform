locals {
  general_notifications_channel_id = local.environment == "live" ? "C06E20AR65V" : "C068RLCPZFE"
}

resource "aws_shield_protection" "shield_protection_route_53" {
  name         = "DIAGRAMShieldProtectionRoute53"
  resource_arn = "arn:aws:route53:::hostedzone/${var.hosted_zone_id}"
}

resource "aws_shield_protection" "shield_protection_route_cloudfront" {
  name         = "DIAGRAMShieldProtectionCloudfront"
  resource_arn = aws_cloudfront_distribution.diagram.arn
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
    cloudwatch_alarms = jsonencode([module.shield_cloudwatch_rules["route_53_zone"].cloudwatch_alarm_arn, module.shield_cloudwatch_rules["cloudfront"].cloudwatch_alarm_arn]),
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
    route_53_zone = "arn:aws:route53:::hostedzone/${var.hosted_zone_id}",
    cloudfront    = aws_cloudfront_distribution.diagram.arn,
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