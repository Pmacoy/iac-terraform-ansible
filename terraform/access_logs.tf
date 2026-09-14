# tfsec (aws-s3-enable-bucket-logging) flags every bucket in this repo for
# having no server access logging. Real fix, not a skip: a dedicated
# target bucket that the artifacts and flow-logs buckets' own `logging`
# blocks point at (see the aws_s3_bucket_logging resources in s3.tf and
# flow_logs.tf). This bucket intentionally does NOT log to itself -- that
# would just recurse forever -- so its own copy of that same tfsec/Checkov
# finding is skipped below, the same way the log-delivery-service pattern
# is skipped on the flow-logs bucket.
resource "aws_s3_bucket" "access_logs" {
  # checkov:skip=CKV2_AWS_62: no event-driven pipeline exists in this demo
  # to notify -- same reasoning as the artifacts bucket (see s3.tf).
  # checkov:skip=CKV_AWS_144: cross-region replication is a DR concern for
  # production log data; this bucket only holds this demo's throwaway
  # access logs, and every CI run empties it via `terraform destroy`.
  # checkov:skip=CKV_AWS_145: default AES256 (enabled below) is sufficient
  # here; this repo's LocalStack container doesn't enable the KMS service.
  #tfsec:ignore:aws-s3-enable-bucket-logging -- this *is* the log target;
  # logging it to itself would recurse.
  bucket = "${local.name}-access-logs"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Access logs aren't kept forever -- 90 days is plenty for a demo (and for
# most real incident-response windows); noncurrent versions are cleared
# faster since they're pure churn once a newer log object lands.
resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "expire-old-access-logs"
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

# The modern (bucket-policy) way to authorize S3 server access logging --
# AWS's own logging.s3.amazonaws.com service principal writes here, not
# any IAM role in this account. See
# https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html
data "aws_iam_policy_document" "access_logs_bucket" {
  statement {
    sid       = "S3ServerAccessLogsPolicy"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.access_logs.arn}/*"]
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = data.aws_iam_policy_document.access_logs_bucket.json
}
