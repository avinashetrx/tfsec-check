# MarkLogic seems to ignore the bucket level KMS settings, so this isn't used
resource "aws_kms_key" "ml_backup_from_datamart_encryption" {
  enable_key_rotation = true
  description         = "ml-backup-datamart-encryption-staging"

  policy = data.aws_iam_policy_document.kms_ml_export_policy.json
}

resource "aws_kms_alias" "ml_backup_from_datamart_encryption" {
  name          = "alias/ml-backup-datamart-encryption-staging"
  target_key_id = aws_kms_key.ml_backup_from_datamart_encryption.key_id
}

module "datamart_ml_backups" {
  source = "../modules/s3_bucket"

  bucket_name                        = "datamart-ml-backups-staging"
  access_log_bucket_name             = "datamart-ml-backups-access-logs-staging"
  force_destroy                      = true
  restrict_public_buckets            = true
  access_s3_log_expiration_days      = local.s3_log_expiration_days
  noncurrent_version_expiration_days = 30
}

data "aws_caller_identity" "current" {}
data "aws_iam_policy_document" "kms_ml_export_policy" {
  statement {
    sid       = "Enable IAM User Permissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [data.aws_caller_identity.current.account_id]
    }
  }
}

output "datamart_ml_backup_bucket" {
  value = module.datamart_ml_backups.bucket_arn
}

resource "aws_iam_role_policy_attachment" "datamart_backups_read" {
  role       = module.marklogic.instance_iam_role
  policy_arn = aws_iam_policy.datamart_backups_read.arn
}

resource "aws_iam_policy" "datamart_backups_read" {
  name        = "ml-instance-datamart-export-s3-read-staging"
  description = "Allows MarkLogic instances to read the exported backups from datamart"

  policy = data.aws_iam_policy_document.datamart_backups_read.json
}

#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "datamart_backups_read" {
  statement {
    actions = ["s3:GetObject", "s3:GetBucketLocation", "s3:GetEncryptionConfiguration", "s3:ListBucket"]
    effect  = "Allow"
    resources = [
      module.datamart_ml_backups.bucket_arn,
      "${module.datamart_ml_backups.bucket_arn}/*",
    ]
  }
}
