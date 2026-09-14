# Both tfsec (aws-ec2-require-vpc-flow-logs-for-all-vpcs) and Checkov flag
# a VPC with no flow logging -- fair: without it there's no record of what
# actually crossed the fleet's network boundary if anything ever needs
# investigating. Logs land in their own bucket, not the artifacts bucket,
# so app data and network logs stay separate.
resource "aws_s3_bucket" "flow_logs" {
  # checkov:skip=CKV2_AWS_62: no event-driven pipeline exists in this demo
  # to notify -- same reasoning as the artifacts bucket (see s3.tf).
  # checkov:skip=CKV_AWS_144: cross-region replication is a DR concern for
  # production log data; this bucket only holds this demo VPC's throwaway
  # flow logs, and every CI run empties it via `terraform destroy` anyway.
  # checkov:skip=CKV_AWS_145: default AES256 (enabled below) is sufficient
  # here for the same reason as the artifacts bucket -- this repo's
  # LocalStack container doesn't enable the KMS service.
  bucket = "${local.name}-vpc-flow-logs"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "flow_logs" {
  bucket        = aws_s3_bucket.flow_logs.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "flow-logs/"
}

# Flow logs are high-volume and low-value past a certain age -- 90 days
# covers a normal investigation window without keeping this bucket growing
# forever.
resource "aws_s3_bucket_lifecycle_configuration" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  rule {
    id     = "expire-old-flow-logs"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# VPC Flow Logs are delivered by the delivery.logs.amazonaws.com service
# principal, not by any IAM role in this account -- this bucket policy is
# what actually authorizes the delivery, the same way it would against
# real AWS.
data "aws_iam_policy_document" "flow_logs_bucket" {
  statement {
    sid       = "AWSLogDeliveryWrite"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.flow_logs.arn}/AWSLogs/*"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
  }

  statement {
    sid       = "AWSLogDeliveryAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.flow_logs.arn]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
  }
}

resource "aws_s3_bucket_policy" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs_bucket.json
}

resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = aws_s3_bucket.flow_logs.arn
  tags                 = local.common_tags
}
