# This Terraform config provisions a small corporate "landing zone" -- VPC,
# subnets, a security group, an S3 bucket, and a least-privilege IAM role --
# against LocalStack instead of real AWS. That's a deliberate choice: it
# lets terraform.yml run `plan` -> `apply` -> `destroy` for real, on every
# push, with no AWS bill and no real credentials anywhere in this repo. The
# HCL itself is exactly what you'd point at real AWS; only the provider's
# `endpoints` block below is LocalStack-specific, and it's the only thing
# you'd delete to go live.
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # LocalStack doesn't check these against anything real, but the provider
  # still requires *some* value to be present.
  access_key = "test"
  secret_key = "test"

  # Skip the validation calls that assume a real AWS account -- LocalStack
  # doesn't implement all of them, and none of them are meaningful here.
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3  = "http://localhost:4566"
    iam = "http://localhost:4566"
    ec2 = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}
