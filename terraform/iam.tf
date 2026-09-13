data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fleet" {
  name               = "${local.name}-fleet-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = local.common_tags
}

# Scoped to exactly this bucket's ARN (and its objects), not "*" -- a
# blanket s3:* on Resource = "*" is the single most common finding Checkov
# and every other IaC scanner flags on a first pass at IAM policies, and
# it's a real risk, not a nitpick: it's what turns "this role reads its
# deploy bucket" into "this role can read every bucket in the account."
data "aws_iam_policy_document" "fleet_s3_access" {
  statement {
    sid     = "ReadWriteArtifactsBucket"
    actions = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = [
      aws_s3_bucket.artifacts.arn,
      "${aws_s3_bucket.artifacts.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "fleet_s3_access" {
  name   = "${local.name}-fleet-s3-access"
  role   = aws_iam_role.fleet.id
  policy = data.aws_iam_policy_document.fleet_s3_access.json
}

resource "aws_iam_instance_profile" "fleet" {
  name = "${local.name}-fleet-profile"
  role = aws_iam_role.fleet.name
}
