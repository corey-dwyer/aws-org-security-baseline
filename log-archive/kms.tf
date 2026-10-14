resource "aws_kms_key" "guardduty_export" {
  description             = "Encrypts GuardDuty findings exported to the log archive bucket."
  enable_key_rotation     = true
  deletion_window_in_days = 30

  lifecycle {
    prevent_destroy = true
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnableIamPermissionsInThisAccount"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        Sid       = "AllowGuardDutyToEncryptExportedFindings"
        Effect    = "Allow"
        Principal = { Service = "guardduty.amazonaws.com" }
        Action    = "kms:GenerateDataKey"
        Resource  = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.security_account_id
          }
          StringLike = {
            "aws:SourceArn" = "arn:aws:guardduty:*:${var.security_account_id}:detector/*"
          }
        }
      },
    ]
  })
}

resource "aws_kms_alias" "guardduty_export" {
  name          = "alias/org-security-baseline-guardduty-export"
  target_key_id = aws_kms_key.guardduty_export.key_id
}