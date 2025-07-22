resource "aws_shield_protection" "shield_protection" {
  for_each     = [aws_s3_bucket.website.arn, aws_iam_role.cloudwatch.arn]
  name         = "${upper(var.project)}ShieldProtection"
  resource_arn = each.value
}

module "shield_response_team_role" {
  source             = "git::https://github.com/nationalarchives/da-terraform-modules//iam_role"
  assume_role_policy = templatefile("${path.module}/templates/iam_role/shield_response_assume_role.json.tpl", {})
  common_tags        = local.common_tags
  name               = "DR2ShieldResponseTeamRole${title(local.environment)}"
  policy_attachments = {
    access_policy = "arn:aws:iam::aws:policy/service-role/AWSShieldDRTAccessPolicy"
  }
}

module "shield_response_s3_bucket" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//s3"
  common_tags = local.common_tags
  function    = "shield-team-information"
  project     = var.project
}

module "encryption_key" {
  source                      = "git::https://github.com/nationalarchives/da-terraform-modules//kms"
  project                     = var.project
  function                    = "encryption"
  key_policy                  = "message_system_access"
  environment                 = local.environment
  common_tags                 = local.common_tags
  aws_backup_service_role_arn = local.aws_back_up_service_role
  aws_backup_local_role_arn   = local.aws_back_up_local_role
}

module "notifications_topic" {
  source      = "git::https://github.com/nationalarchives/da-terraform-modules//sns"
  common_tags = local.common_tags
  function    = "notifications"
  project     = var.project
  sns_policy  = "notifications"
  kms_key_arn = module.encryption_key.kms_key_arn
}

module "shield_cloudwatch_rules" {
  for_each = {
    s3_bucket    = aws_s3_bucket.website.arn,
    cloudfront   = aws_iam_role.cloudwatch.arn,
  }
  source              = "git::https://github.com/nationalarchives/da-terraform-modules//cloudwatch_alarms"
  environment         = local.environment
  function            = "shield-metric-${each.key}"
  metric_name         = "DDoSDetected"
  project             = var.project
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