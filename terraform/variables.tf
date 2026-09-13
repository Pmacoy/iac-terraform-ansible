variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short project name, used as a prefix/tag on every resource"
  type        = string
  default     = "corp-iac-demo"
}

variable "environment" {
  description = "Environment name (dev/staging/prod) -- tagged onto every resource"
  type        = string
  default     = "ci"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.42.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet (load balancers / bastion)"
  type        = string
  default     = "10.42.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet (application fleet)"
  type        = string
  default     = "10.42.2.0/24"
}

variable "ssh_ingress_cidr" {
  description = <<-EOT
    CIDR allowed to reach port 22 on the fleet security group. Defaults to
    the VPC itself (bastion-only access), not 0.0.0.0/0 -- a corporate
    landing zone shouldn't expose SSH to the whole internet, and Checkov
    (security.yml) checks exactly this.
  EOT
  type        = string
  default     = "10.42.0.0/16"
}
