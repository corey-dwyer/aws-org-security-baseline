variable "aws_profile" {
  description = "AWS CLI profile for the account this configuration applies to."
  type        = string
}

variable "management_account_id" {
  description = "Account ID of the organization's management account, which owns the organization trail."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "The management account ID must be exactly 12 digits."
  }
}

variable "organization_id" {
  description = "ID of the AWS Organization (o-xxxxxxxxxx), used in the organization trail's delivery path."
  type        = string

  validation {
    condition     = can(regex("^o-[a-z0-9]{10,32}$", var.organization_id))
    error_message = "The organization ID must look like o- followed by 10 to 32 lowercase letters or digits."
  }
}

variable "trail_name" {
  description = "Name of the organization trail. Must match the trail created in the security-services configuration, because the bucket policy trusts that trail's ARN."
  type        = string
  default     = "organization-trail"
}

variable "security_account_id" {
  description = "Account ID of the shared security account, which administers the organization's GuardDuty. Used to restrict which detectors may export findings to this bucket and use the encryption key."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.security_account_id))
    error_message = "The security account ID must be exactly 12 digits."
  }
}

variable "guardduty_regions" {
  description = "Regions where GuardDuty exports findings to this bucket. A destination folder is created for each. Must match the Region list in the security-services configuration."
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