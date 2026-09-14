# The bucket the fleet's IAM role (iam.tf) is scoped to read/write --
# deploy artifacts, config, whatever a real corporate app would ship
# through it. Versioning + a public access block + default encryption are
# the three things Checkov (security.yml) actually checks for on an S3
# bucket, and skipping any of them would be a real finding, not a
# stylistic one.
resource "aws_s3_bucket" "artifacts" {
  # checkov:skip=CKV2_AWS_62: no event-driven pipeline (Lambda/SQS/SNS)
  # exists in this demo to notify -- nothing would ever consume these
  # events.
  # checkov:skip=CKV_AWS_144: cross-region replication is a DR concern for
  # production data; this bucket only holds this demo's throwaway
  # LocalStack artifacts, and every CI run empties it via `terraform
  # destroy` anyway.
  # checkov:skip=CKV_AWS_145: the default AES256 encryption enabled below
  # is sufficient here; a customer-managed KMS key would add a key to
  # provision and manage for no real benefit, and this repo's LocalStack
  # container (docker-compose.yml) doesn't enable the KMS service.
  bucket = "${local.name}-artifacts"
  tags   = local.common_tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server access logging -- who read/wrote what, and when -- delivered to
# the dedicated log bucket in access_logs.tf.
resource "aws_s3_bucket_logging" "artifacts" {
  bucket        = aws_s3_bucket.artifacts.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "artifacts/"
}

# Nothing here keeps artifacts forever; old object versions are pure churn
# once a newer one lands, and an abandoned multipart upload just wastes
# storage.
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
