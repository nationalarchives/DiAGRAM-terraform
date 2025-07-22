module "dr2_configuration" {
  source  = "git::https://github.com/nationalarchives/da-terraform-configurations"
  project = "dr2"
}

module "aws_backup_configuration" {
  source  = "git::https://github.com/nationalarchives/da-terraform-configurations"
  project = "aws-backup"
}