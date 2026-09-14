locals {
  name = "${var.project}-${var.environment}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${local.name}-igw" })
}

# tfsec flags the same thing Checkov's CKV_AWS_130 does below -- intentional,
# same reasoning: this is the public subnet (Tier = "public" below) and
# auto-assigning a public IP is the point of it.
#tfsec:ignore:aws-ec2-no-public-ip-subnet
resource "aws_subnet" "public" {
  # checkov:skip=CKV_AWS_130: intentional -- this is the public subnet
  # (Tier = "public" below); auto-assigning a public IP is the point of
  # it. The private subnet right below has no such setting.
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  tags                    = merge(local.common_tags, { Name = "${local.name}-public", Tier = "public" })
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidr
  tags       = merge(local.common_tags, { Name = "${local.name}-private", Tier = "private" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, { Name = "${local.name}-public-rt" })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# AWS creates this default security group with every VPC, and anything
# that doesn't specify a security group of its own falls back to it. Left
# alone it ships with an "allow all from itself" rule, which is exactly
# what Checkov (CKV2_AWS_12) flags. Declaring it here doesn't create a new
# SG -- it takes over management of the one AWS already made and, with no
# ingress/egress blocks, strips every rule from it. Anything that actually
# needs network access uses the purpose-built SG in security_groups.tf.
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${local.name}-default-sg-locked-down" })
}
