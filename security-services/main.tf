terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    key          = "security-services/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}

# This configuration changes the shared security account, which is also the account
# that holds Terraform state, so the backend profile in backend.hcl and the provider
# profile in terraform.tfvars name the same account. Regional resources set their own
# region argument, so one provider block covers every Region in scope.
provider "aws" {
  region  = "ap-northeast-1"
  profile = var.aws_profile
}