locals {
  shield_topic_name = "${local.environment}-DiAGRAM-shield-notifications"
}

resource "aws_shield_protection" "shield_protection" {
  for_each     = toset([aws_s3_bucket.website.arn, aws_iam_role.cloudwatch.arn])
  name         = "DIAGRAMShieldProtection"
  resource_arn = each.value
}

module "shield_response_team_role" {
  source             = "git::https://github.com/nationalarchives/da-terraform-modules//iam_role"
  assume_role_policy = templatefile("${path.module}/templates/iam_role/shield_response_assume_role.json.tpl", {})
  name               = "DR2ShieldResponseTeamRole${title(local.environment)}"
  policy_attachments = {
    access_policy = "arn:aws:iam::aws:policy/service-role/AWSShieldDRTAccessPolicy"
  }
  tags = {}
}

module "shield_response_s3_bucket" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//s3"
  common_tags = local.common_tags
  bucket_name = aws_s3_bucket.website.bucket
}

module "encryption_key" {
  source     = "git::https://github.com/nationalarchives/da-terraform-modules//kms"
  key_name   = "${local.environment}-kms-DiAGRAM"
  key_policy = "message_system_access"
}

module "notifications_topic" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//sns"
  topic_name  = local.shield_topic_name
  sns_policy  = "notifications"
  kms_key_arn = module.encryption_key.kms_key_arn
  tags        = {}
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
  notification_topic  = module.notifications_topic.sns_arn
  dimensions          = { "ResourceArn" = each.value }
  statistic           = "Sum"
  namespace           = "AWS/DDoSProtection"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  datapoints_to_alarm = 1
  evaluation_period   = 20
}