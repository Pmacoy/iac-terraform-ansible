resource "aws_security_group" "fleet" {
  name        = "${local.name}-fleet"
  description = "Corporate fleet: SSH from the bastion CIDR only, HTTP from anywhere"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from the bastion/VPC CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_ingress_cidr]
  }

  # checkov:skip=CKV_AWS_260: intentionally open -- this rule fronts the
  # fleet's own nginx (ansible/roles/webserver), which is meant to be
  # reachable from the public internet. Scoping this down would defeat
  # the point of having a public web tier.
  ingress {
    description = "HTTP from anywhere (this is a public web tier)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Unrestricted egress -- fine for a demo, would be scoped down for real workloads"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name}-fleet-sg" })
}
