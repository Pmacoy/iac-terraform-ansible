output "vpc_id" {
  description = "ID of the provisioned VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "fleet_security_group_id" {
  value = aws_security_group.fleet.id
}

output "artifacts_bucket" {
  description = "Name of the S3 bucket the fleet's IAM role can read/write"
  value       = aws_s3_bucket.artifacts.bucket
}

output "fleet_role_arn" {
  value = aws_iam_role.fleet.arn
}

output "fleet_instance_profile" {
  value = aws_iam_instance_profile.fleet.name
}
