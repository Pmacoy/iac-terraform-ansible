# iac-terraform-ansible

A corporate-style infrastructure demo split across the two tools that
usually divide this work in practice:

- **Terraform** provisions the "landing zone" -- VPC, subnets, a security
  group, an S3 bucket, a least-privilege IAM role -- against
  [LocalStack](https://localstack.cloud/), a local AWS-API-compatible mock.
  No real cloud account, bill, or credentials involved.
- **Ansible** configures a small fleet -- two plain Ubuntu containers
  standing in for what would be EC2 instances -- over real SSH: baseline
  packages, sshd hardening, and an nginx web server.

Both run for real, not just render correctly: `terraform apply` actually
creates resources in LocalStack and `ansible-playbook` actually connects
over SSH and changes the containers, in CI on every push.

## Why LocalStack, and why Docker containers instead of real EC2

LocalStack Community's EC2 support is API-mock-only -- it accepts
`aws_instance` requests but nothing actually boots, so nothing would be
there for Ansible to configure. Rather than build the Ansible side against
a fragile mock, this repo keeps the two tools' "real execution" honest by
giving each one a target it can actually act on for real:

- Terraform's job stops at the landing zone (network, storage, IAM) --
  resources LocalStack genuinely implements.
- Ansible's target fleet is a separate pair of Docker containers reachable
  over real SSH, configured the same way real EC2 instances would be.

In a real deployment, Terraform would also provision the EC2 fleet and
feed Ansible a dynamic inventory from its state (e.g. via the `aws_ec2`
plugin). The Terraform HCL itself is written as if it targeted real AWS --
only `terraform/provider.tf`'s `endpoints` block is LocalStack-specific.

## Layout

```
terraform/            landing zone: VPC, subnets, security group, S3, IAM
docker/corporate-server/   image for the fleet containers Ansible configures
ansible/
  inventory/           static inventory pointing at the two containers
  playbooks/site.yml    baseline -> ssh_hardening -> webserver
  roles/
    baseline/            packages, deploy user, MOTD
    ssh_hardening/        key-only SSH, no root login, tighter auth limits
    webserver/            nginx + a status page proving the config landed
scripts/               SSH keygen, SSH readiness wait, idempotence + functional checks
.github/workflows/     terraform.yml, ansible.yml, security.yml
```

## Running it locally

Requires Docker, Terraform (or OpenTofu), and Ansible.

```bash
# Terraform side
docker compose up -d localstack
make tf-init
make tf-apply      # real apply against LocalStack
make tf-destroy    # tear it back down

# Ansible side -- brings up the fleet, configures it, and proves it worked
make demo
```

`make demo` runs, in order: SSH keygen, container build + start, an SSH
readiness wait, the real playbook run, a second playbook run that must
report zero changes (idempotence), and a functional check that curls both
nginx nodes and confirms `ssh_hardening` actually disabled password
authentication. Tear down with `make down`.

## What each role actually proves

- **baseline** installs real packages and creates a `deploy` user --
  nothing here is faked, `apt-get` genuinely runs inside the containers.
- **ssh_hardening** writes a drop-in sshd config (key-only auth, no root
  login, `AllowUsers`) and reloads sshd *without* restarting it -- sshd is
  PID 1 in these containers, so a full restart would kill the container
  out from under the connection Ansible is using; `state: reloaded` sends
  SIGHUP instead, which sshd handles by re-executing itself in place.
  `scripts/verify-functional.sh` then proves this actually took effect by
  confirming password auth is refused.
- **webserver** installs nginx and renders a template containing the
  node's own hostname, so the functional check can tell the two nodes
  apart and confirm each one really got configured.

## CI

- **`terraform.yml`**: `fmt`, `validate`, `tflint`, `checkov`, then a real
  `plan` / `apply` / `destroy` cycle against a LocalStack service
  container, with a post-apply check that queries LocalStack directly to
  confirm the VPC and S3 bucket actually exist.
- **`ansible.yml`**: `ansible-lint`, then the real fleet build-and-configure
  cycle described above (apply, idempotence check, functional check).
- **`security.yml`**: gitleaks, hadolint, tfsec, `ansible-lint --profile
  security`, a Trivy filesystem scan, and (on pull requests) GitHub's
  Dependency review.

## Security posture

Written in from the start rather than discovered by a scanner after the
fact:

- S3: versioning enabled, AES256 default encryption, all four public
  access block flags on.
- IAM: the fleet role's policy is scoped to its own bucket's ARN, not `*`.
- Security group: SSH ingress is scoped to the VPC's own CIDR, not
  `0.0.0.0/0`.
- SSH: key-only auth, no root login, `AllowUsers` allow-list, tightened
  auth limits -- applied by `ssh_hardening` on top of a deliberately
  unhardened base image, so CI is proving the hardening works, not
  starting from an already-hardened box.

See [SECURITY.md](SECURITY.md) for the full scanning list.
