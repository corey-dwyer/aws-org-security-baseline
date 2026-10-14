variable "aws_profile" {
  description = "AWS CLI profile for the account this configuration applies to."
  type        = string
}

variable "log_bucket_name" {
  description = "Name of the organization log archive bucket. The organization trail delivers to it, and its own objects are excluded from the trail's S3 data events to avoid a logging feedback loop."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.log_bucket_name)) && endswith(var.log_bucket_name, "-an")
    error_message = "The bucket name must be a valid S3 bucket name ending in -an (the account regional namespace suffix)."
  }
}

variable "trail_name" {
  description = "Name of the organization trail. Must match the trail_name in the log-archive configuration, because that bucket policy trusts this trail's ARN."
  type        = string
  default     = "organization-trail"
}