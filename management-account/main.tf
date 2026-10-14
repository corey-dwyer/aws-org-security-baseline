terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    key          = "management-account/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

# This configuration changes the management account, so the provider uses that
# account's profile. State is read and written through the shared security account's
# profile, set in backend.hcl (baseline ADR 0004). Applying it therefore needs two
# signed-in sessions: the operator session for state, and the separate management
# session for the changes.
provider "aws" {
  region  = "ap-northeast-1"
  profile = var.aws_profile
}