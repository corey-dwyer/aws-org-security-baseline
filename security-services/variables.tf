variable "aws_profile" {
  description = "AWS CLI profile for the account this configuration applies to."
  type        = string
}

variable "guardduty_regions" {
  description = "Regions where GuardDuty is enabled. Must match the Region list in the log-archive configuration, which creates a destination folder for each."
  type        = set(string)
  default = [
    "ap-northeast-1",
    "ap-northeast-2",
    "ap-northeast-3",
    "ap-south-1",
    "ap-southeast-1",
    "ap-southeast-2",
    "ca-central-1",
    "eu-central-1",
    "eu-north-1",
    "eu-west-1",
    "eu-west-2",
    "eu-west-3",
    "sa-east-1",
    "us-east-1",
    "us-east-2",
    "us-west-1",
    "us-west-2",
  ]

  validation {
    condition     = alltrue([for r in var.guardduty_regions : can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", r))])
    error_message = "Each entry must look like a Region name, for example ap-northeast-1."
  }
}