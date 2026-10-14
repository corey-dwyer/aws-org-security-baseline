resource "aws_s3_object" "guardduty_prefix" {
  bucket = aws_s3_bucket.log_archive.id
  key    = "guardduty/"
}

resource "aws_s3_object" "guardduty_region_folder" {
  for_each = var.guardduty_regions

  bucket = aws_s3_bucket.log_archive.id
  key    = "guardduty/AWSLogs/${var.security_account_id}/GuardDuty/${each.key}/"

  depends_on = [aws_s3_object.guardduty_prefix]
}