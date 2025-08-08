locals {
  zone_prefix = terraform.workspace == "live" ? "" : "${terraform.workspace}-"
  zone_name   = "${local.zone_prefix}diagram.nationalarchives.gov.uk"
}

resource "aws_route53_zone" "hosted_zone" {
  name = local.zone_name
}

data "aws_ssm_parameter" "slack_token" {
  name            = "/mgmt/slack/token"
  with_decryption = true
}

module "site" {
  source              = "./site"
  hosted_zone_id      = aws_route53_zone.hosted_zone.id
  hosted_zone_name    = local.zone_name
  created_by          = local.created_by
  api_destination_arn = module.eventbridge_alarm_notifications_destination.api_destination_arn
}

module "eventbridge_alarm_notifications_destination" {
  source                     = "git::https://github.com/nationalarchives/da-terraform-modules//eventbridge_api_destination"
  authorisation_header_value = "Bearer ${data.aws_ssm_parameter.slack_token.value}"
  name                       = "${terraform.workspace}-dr2-eventbridge-slack-destination"
}