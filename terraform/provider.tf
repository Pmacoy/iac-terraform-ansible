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
      source = "hashicorp/aws"
      # Pinned <= 5.69.0 on purpose, not just "~> 5.0": newer 5.x releases
      # added a post-apply convergence check on
      # aws_s3_bucket_lifecycle_configuration that compares the
      # transition_default_minimum_object_size the provider expects
      # ("all_storage_classes_128K") against what the endpoint reports back.
      # Real AWS sends that via the x-amz-transition-default-minimum-object-
      # size response header; LocalStack (and every other S3-compatible
      # endpoint) doesn't send it, so the provider reads back an empty value
      # and the comparison never matches -- terraform apply just hangs for
      # 3 minutes on every lifecycle-configuration resource and then times
      # out, even though the rules were written correctly. See
      # https://github.com/hashicorp/terraform-provider-aws/issues/49019 and
      # https://github.com/localstack/localstack/issues/12246. 5.69.0 is the
      # last release before that check was introduced.
      version = ">= 5.0, <= 6.63.0"
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
