# The bucket the fleet's IAM role (iam.tf) is scoped to read/write --
# deploy artifacts, config, whatever a real corporate app would ship
# through it. Versioning + a public access block + default encryption are
# the three things Checkov (security.yml) actually checks for on an S3
# bucket, and skipping any of them would be a real finding, not a
# stylistic one.
resource "aws_s3_bucket" "artifacts" {
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
