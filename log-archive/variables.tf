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