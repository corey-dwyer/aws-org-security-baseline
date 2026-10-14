resource "aws_cloudtrail" "organization" {
  name           = var.trail_name
  s3_bucket_name = var.log_bucket_name

  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true

  # Management events: every control-plane API call, reads and writes.
  advanced_event_selector {
    name = "Management events"

    field_selector {
      field  = "eventCategory"
      equals = ["Management"]
    }
  }

  # S3 data events for every bucket in every account, except the log archive bucket.
  # The trailing slash restricts the exclusion to that bucket's objects. Without it,
  # any other bucket whose name starts with the same text would be excluded too.
  # Excluding the archive also avoids a feedback loop: reading logs would otherwise
  # generate new log events in the same bucket.
  advanced_event_selector {
    name = "S3 data events, excluding the log archive bucket"

    field_selector {
      field  = "eventCategory"
      equals = ["Data"]
    }

    field_selector {
      field  = "resources.type"
      equals = ["AWS::S3::Object"]
    }

    field_selector {
      field           = "resources.ARN"
      not_starts_with = ["arn:aws:s3:::${var.log_bucket_name}/"]
    }
  }
}