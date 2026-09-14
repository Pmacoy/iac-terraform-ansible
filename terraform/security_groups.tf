resource "aws_security_group" "fleet" {
  # checkov:skip=CKV2_AWS_5: not attached to anything in *this* Terraform
  # config on purpose -- this repo's Terraform scope stops at the landing
  # zone (see README's "Why LocalStack" section); the fleet it's meant for
  # is the Docker containers Ansible configures, not an aws_instance this
  # config provisions. In a real deployment the fleet's EC2 instances (or
  # their launch template) would reference this security group's id.
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
  #tfsec:ignore:aws-vpc-no-public-ingress-sgr
  ingress {
    description = "HTTP from anywhere (this is a public web tier)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # checkov:skip=CKV_AWS_382: unrestricted egress is a deliberate demo
  # simplification (see the rule's own description below); a real
  # deployment would scope this to the specific destinations the fleet
  # actually needs (package mirrors, internal services, etc).
  #tfsec:ignore:aws-vpc-no-public-egress-sgr
  egress {
    description = "Unrestricted egress -- fine for a demo, would be scoped down for real workloads"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name}-fleet-sg" })
}
